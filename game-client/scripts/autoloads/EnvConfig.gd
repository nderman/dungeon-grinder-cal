# EnvConfig.gd (Autoload)
# The green-room clipboard. Godot has no notion of a `.env`, so this reads one ourselves and feeds
# the secrets to PostHog before a single beat is captured. Resolution order (highest priority first):
#   1. real process env   — POSTHOG_API_KEY / POSTHOG_HOST, for terminal/CI launches
#   2. repo-root `.env`   — dev convenience, gitignored, never shipped (only exists on a dev box)
#   3. bundled res://posthog.key — for EXPORTED/WEB builds, which can't read a host .env or process env.
#      The CI build step writes it from a secret so it's never in git, but it DOES ship in the .pck —
#      that's fine: a `phc_` key is a publishable, write-only client key, meant to live in client builds.
# None of the three -> nothing set -> PostHog stays silent (a clone with no key sends nothing).
# Register AFTER PostHog and BEFORE Telemetry in project.godot — PostHog reads api_key live on every
# capture/flush, so setting it here (a hair after PostHog._ready) takes effect for the whole session.
extends Node

func _ready() -> void:
	var vals := _read_dotenv()   # .env first...
	if OS.has_environment("POSTHOG_API_KEY"):
		vals["POSTHOG_API_KEY"] = OS.get_environment("POSTHOG_API_KEY")   # ...real env wins over .env
	if OS.has_environment("POSTHOG_HOST"):
		vals["POSTHOG_HOST"] = OS.get_environment("POSTHOG_HOST")
	# Fall back to a bundled key only if nothing else supplied one (the web/exported-build path).
	if not vals.has("POSTHOG_API_KEY") or String(vals["POSTHOG_API_KEY"]).is_empty():
		var bundled := _read_bundled_key()
		if not bundled.is_empty():
			vals["POSTHOG_API_KEY"] = bundled

	if vals.has("POSTHOG_API_KEY") and not String(vals["POSTHOG_API_KEY"]).is_empty():
		PostHog.api_key = vals["POSTHOG_API_KEY"]
	if vals.has("POSTHOG_HOST") and not String(vals["POSTHOG_HOST"]).is_empty():
		PostHog.host = vals["POSTHOG_HOST"]

# A single-line key file bundled into the .pck at build time (res:// IS readable in a web export, a
# host .env / process env are NOT). Gitignored; written by the deploy workflow from a CI secret.
func _read_bundled_key() -> String:
	if not FileAccess.file_exists("res://posthog.key"):
		return ""
	var f := FileAccess.open("res://posthog.key", FileAccess.READ)
	return f.get_as_text().strip_edges() if f != null else ""

# Parse the repo-root `.env` (one dir above res://). Editor/desktop only — in an exported build the
# file won't exist and we quietly return nothing. Format: KEY=VALUE, `#` comments and blanks skipped.
func _read_dotenv() -> Dictionary:
	var out := {}
	var path := ProjectSettings.globalize_path("res://").path_join("../.env")
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or not line.contains("="):
			continue
		var eq := line.find("=")
		var key := line.substr(0, eq).strip_edges()
		var val := line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		out[key] = val
	return out
