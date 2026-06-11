# Regression tests

Headless GDScript regression suite for the game systems (loot, combat, status effects, level-gen,
the death-teardown crash). Replaces the throwaway one-off tests we used to write and delete.

## Run

```bash
# from game-client/
./tests/run_tests.sh
# or point at your Godot binary:
GODOT=/path/to/Godot ./tests/run_tests.sh
```

Exits **0** if every assertion passes (prints `SUITE: PASS`), non-zero otherwise — so `/shipit` and
CI can gate on it.

## How it works

- **One process.** `TestRunner.tscn` runs as a real scene so the autoloads (`GameManager`,
  `SignalBus`, `LootData`, …) load. It instantiates each test, `await`s its `run()`, and tallies
  failures. (Tests **must** be scene-driven — `godot -s` SceneTree scripts don't load autoloads, so
  anything touching an autoload won't even compile.)
- **`TestCase.gd`** is the base: set `test_name`, override `run()` (it may `await` frames/timers), and
  assert with `check()` / `eq()` / `approx()` / `truthy()`.
- **`Stubs.gd`** (`TestStubs`) holds shared fixtures — a `PlayerStub` (group + HealthComponent +
  `speed_mult` + `elemental_resist`) and `body()`/`player()` factories.

## Add a test

1. Write `tests/test_foo.gd`:
   ```gdscript
   extends TestCase
   func _init() -> void: test_name = "foo"
   func run() -> void:
       eq(2 + 2, 4, "arithmetic still works")
   ```
2. Add `preload("res://tests/test_foo.gd")` to the `TESTS` array in `TestRunner.gd`.

Keep tests self-contained — they share one process, so set any `GameManager` state you read, and
parent spawned nodes under `self` (the test) so they're freed between tests.
