# EnvConfig.gd (Autoload)
# The green-room clipboard. Godot has no notion of a `.env`, so this reads one ourselves and feeds
# the secrets to PostHog before a single beat is captured. Resolution order (last wins):
#   1. repo-root `.env`   — dev convenience, gitignored, never shipped (only exists on a dev box)
#   2. real process env   — POSTHOG_API_KEY / POSTHOG_HOST, for terminal/CI launches
# No `.env`, no env var → nothing set → PostHog stays silent (CI, clones, exported builds send nothing).
# Register AFTER PostHog and BEFORE Telemetry in project.godot — PostHog reads api_key live on every
# capture/flush, so setting it here (a hair after PostHog._ready) takes effect for the whole session.
extends Node

func _ready() -> void:
	var vals := _read_dotenv()   # file first...
	if OS.has_environment("POSTHOG_API_KEY"):
		vals["POSTHOG_API_KEY"] = OS.get_environment("POSTHOG_API_KEY")   # ...real env wins
	if OS.has_environment("POSTHOG_HOST"):
		vals["POSTHOG_HOST"] = OS.get_environment("POSTHOG_HOST")

	if vals.has("POSTHOG_API_KEY") and not String(vals["POSTHOG_API_KEY"]).is_empty():
		PostHog.api_key = vals["POSTHOG_API_KEY"]
	if vals.has("POSTHOG_HOST") and not String(vals["POSTHOG_HOST"]).is_empty():
		PostHog.host = vals["POSTHOG_HOST"]

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
