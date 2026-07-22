extends TestCase
# Onboarding hints fire exactly once each: TutorialManager._fire shows a hint the first time and marks
# it seen (persisted), then never again — so a returning player is never nagged. Unknown keys no-op.
func _init() -> void: test_name = "tutorial"

func run() -> void:
	var toasts: Array = []
	var spy := func(msg: String, _pos): toasts.append(msg)
	SignalBus.toast.connect(spy)

	var key := "first_box"
	var had_key := MetaManager.tutorial_seen.has(key)
	var prev: Variant = MetaManager.tutorial_seen.get(key, null)
	MetaManager.tutorial_seen.erase(key)

	check(not MetaManager.has_seen_hint(key), "a fresh player hasn't seen the hint")
	TutorialManager._fire(key)
	eq(toasts.size(), 1, "a fresh hint fires once")
	check(MetaManager.has_seen_hint(key), "firing marks the hint seen")
	TutorialManager._fire(key)
	eq(toasts.size(), 1, "a seen hint never fires again")
	TutorialManager._fire("nope_not_a_real_hint")
	eq(toasts.size(), 1, "an unknown hint key is a no-op")

	SignalBus.toast.disconnect(spy)
	MetaManager.tutorial_seen.erase(key)
	if had_key:
		MetaManager.tutorial_seen[key] = prev
