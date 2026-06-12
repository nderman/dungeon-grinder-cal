# PostHog.md — Dungeon Grinder Cal (telemetry spec)

> **STATUS: IMPLEMENTED (2026-06-12)** — wired via the in-house **`addons/posthog/` SDK** (we dogfood
> our own Godot addon instead of raw HTTP). `Telemetry.gd` autoload listens to `SignalBus` and forwards
> to `PostHog.capture()`. Key/host from `POSTHOG_API_KEY`/`POSTHOG_HOST` env (never committed; no-op
> without a key). Opt-out: `MetaManager.analytics_enabled`. The boss-hp-tuning flag scales boss HP via
> `Telemetry.boss_hp_mult()`. Covered by `tests/test_telemetry.gd` (records locally, never hits the net).

Context + implementation spec for wiring PostHog game analytics into the Godot client.
Reads alongside `AGENTS.md` (operational ground truth) and `docs/GDD.md` (design ground
truth). **Respect the non-negotiables in AGENTS.md** — especially: all cross-system events
go through `SignalBus`, composition over inheritance, typed GDScript only, and Cal's snarky
voice in comments.

## Why PostHog here (the angle)
PostHog ships no official Godot SDK — so we hit the **capture HTTP API** directly. That's
the whole flex: you understand PostHog's event model (`distinct_id`, `event`, `properties`),
not just the SDK sugar. A roguelite is a textbook analytics subject:
- **Funnel** — the death curve: `run_started → floor_1_cleared → floor_2_cleared → … → boss_killed`.
- **Retention** — do contestants come back for another Episode?
- **Player behaviour** — class pick rates, which floor/boss does the killing, build choices.
- **Feature flags / experiments** — A/B a balance tweak (e.g. DR cap, mob damage) remotely.

This is **pure backend-style integration on a client** — no DOM, no `posthog-js`. We POST
JSON from `HTTPRequest`.

## Tools / products to use
| Product | Use | How |
|---|---|---|
| Product analytics | run/floor/death/build events | `POST /capture/` (or `/batch/` for queued events) |
| Funnels & retention | death curve, return rate | PostHog UI over the events below |
| Feature flags | remote balance toggles | `POST /flags/` (a.k.a. `/decide`) with `distinct_id` |
| Experiments | A/B a tuning value | flag variants + funnel comparison |

- **Host:** `https://us.i.posthog.com` (use `eu.` if the project is EU).
- **Capture endpoint:** `POST {host}/capture/` body `{ "api_key": "...", "event": "...",
  "distinct_id": "...", "properties": { ... } }`.
- **Batch:** `POST {host}/batch/` body `{ "api_key": "...", "batch": [ {event...}, ... ] }`.
- **Flags:** `POST {host}/flags/?v=2` body `{ "api_key": "...", "distinct_id": "..." }`.
- Project API key (`phc_...`) is publishable — safe to ship in the client.
- Docs: https://posthog.com/docs/api/capture and https://posthog.com/docs/feature-flags

## Architecture — a `Telemetry` autoload riding `SignalBus`
Do **not** sprinkle capture calls through gameplay code. Add one autoload that *listens*
to the existing signal bus and forwards — same way `FeedbackManager` / `AchievementManager`
already subscribe. Gameplay code stays unaware analytics exists.

1. **`scripts/autoloads/Telemetry.gd`** — new autoload, registered in `project.godot`
   after `GameManager` (it depends on the others existing).
   - On `_ready()`: load/generate a persistent anonymous `distinct_id` (a UUID stored in
     `user://telemetry.cfg` via `ConfigFile` — survives runs, no PII, no login).
   - Connect to `SignalBus` + `GameManager` signals (table below) and translate each into
     a `capture()` call.
   - `capture(event: String, props: Dictionary)` — builds the payload, fires a pooled
     `HTTPRequest`. **Fire-and-forget; never block a frame, never await in gameplay.**
   - Queue + flush in small batches via `/batch/` to avoid a request per kill (combat is
     spiky). Flush on a timer (~5s) and on `run` boundaries.
   - **Hard rule:** a telemetry/network failure must never affect the run. Swallow all
     HTTP errors. If `POSTHOG_KEY` is unset, no-op silently (keeps dev + CI clean —
     `tests/` must not make network calls).
2. **Opt-out + dev guard.** Respect a `MetaManager` setting (e.g. `analytics_enabled`,
   default on but toggleable in options) and disable entirely when running the test suite
   (`tests/TestRunner.gd`) or in the editor unless `POSTHOG_DEBUG` is set.

## Event taxonomy
Most of these already exist as signals — we're just listening. Source signals in parens.

| Event | Source signal | Properties |
|---|---|---|
| `run_started` | `SignalBus.run_started` | `class`, `race`, `meta_level`, `syndication_points` |
| `floor_changed` | `GameManager.floor_changed` | `floor`, `run_elapsed_s` |
| `boss_killed` | (boss death / `stairs_opened` on boss floor) | `floor`, `boss`, `hearts_left`, `floor_time_s` |
| `player_died` | `SignalBus.player_damaged` → 0 hearts | `floor`, `cause`, `enemy`, `run_time_s`, `level`, `rating` |
| `run_completed` | run-end (death or victory) | `outcome` (`died`/`won`), `floor_reached`, `rating`, `gold`, `run_time_s` |
| `leveled_up` | `SignalBus.leveled_up` | `level`, `skill_points` |
| `item_acquired` | `SignalBus.item_acquired` | `item`, `rarity`, `floor` |
| `box_opened` | `SignalBus.box_opened` | `rarity`, `floor` |
| `achievement_unlocked` | `SignalBus.achievement_unlocked` | `title`, `floor`, `run_time_s` |
| `stat_injected` | `SignalBus.stat_injected` | `stat_name`, `new_value` |

This yields the death-curve **funnel** (`run_started → floor 2 → floor 3 → boss_killed`)
and **retention** (returning `distinct_id`s day over day) with no extra instrumentation.

Keep property values primitive (String/int/float/bool) — no `Vector2`, no node refs. Some
signals carry `location: Vector2`; **drop it**, it's noise for analytics.

## Feature flag / experiment (one, to prove it)
- `boss-hp-tuning` (multivariate: `control` / `test`) — `Telemetry` fetches it once at
  `run_started` via `boss_hp_mult()` (the `test` cohort gets +15% boss HP) and PUSHES the
  multiplier into `GameManager.boss_hp_mult`; the boss spawn reads that plain field. Then
  compare `boss_killed` rate per variant in PostHog Experiments.
- Fetch flags **once per run** and cache on the autoload — never per-frame, never per-enemy.

## Implementation steps
1. Add `POSTHOG_KEY` + `POSTHOG_HOST` (e.g. via an exported config resource or
   `ProjectSettings`/env). Publishable key, fine to commit a `.example`.
2. Write `scripts/autoloads/Telemetry.gd` (autoload), persistent `distinct_id`, batched
   `HTTPRequest`, no-op when unconfigured. Cal's voice in the comments.
3. Register it in `project.godot` `[autoload]` after `GameManager`.
4. Connect the signals in the table; map each to `capture()`.
5. Add the options toggle (`MetaManager.analytics_enabled`) + test-suite guard.
6. Add a values-style regression test in `tests/` (e.g. `test_telemetry.gd`): assert the
   autoload **builds correct payloads and makes no HTTP call when the key is empty** — keep
   the suite offline and green (`./tests/run_tests.sh`).
7. Wire the `boss-hp-tuning` flag read into boss spawn.
8. Verify: play a run with a real key, confirm `run_started`/`player_died`/`run_completed`
   land in PostHog Activity, then build the death-curve funnel + a retention insight.

## Don't
- Don't capture inside gameplay/component code — only `Telemetry.gd` listens to the bus.
- Don't block a frame or `await` a request mid-combat. Fire-and-forget, batch, swallow errors.
- Don't send `Vector2`/node refs/PII. Anonymous `distinct_id` + primitive props only.
- Don't let the test suite or CI hit the network — no key ⇒ no-op.
- Don't fetch flags per-frame; once per run, cached.

## Interview talking points this unlocks
- Instrumented a platform PostHog **doesn't officially support** via the raw capture API.
- Clean event-bus architecture: analytics as a pure listener, zero gameplay coupling.
- Game funnels (death curve) + retention — the metrics that actually matter for a roguelite.
- A remote-config balance experiment (feature-flag variant → funnel comparison).
- Privacy-by-default: anonymous ids, opt-out, no network in tests.
