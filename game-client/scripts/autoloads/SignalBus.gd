# SignalBus.gd (Autoload)
# Cal's central nervous system. Decouples combat logic from VFX/SFX/UI so the
# "meat grinder" stays smooth. Components EMIT here; FeedbackManager + HUD LISTEN.
# Register in Project Settings > Autoload as "SignalBus".
extends Node

# --- COMBAT & DAMAGE ---
signal dr_triggered(location: Vector2)              # DR roll succeeded — the "Clink!"
signal player_damaged(hearts_remaining: int)        # Player actually lost a segment
signal enemy_cancelled(location: Vector2, ratings_earned: int)
signal ratings_spike(type: String)                  # SPEED_DEMON / NEAR_DEATH / CANCELLED / TELEGRAPH_START ...

# --- MOVEMENT & HAZARDS ---
signal player_dashed(location: Vector2)             # Ghost-trail + whoosh + i-frames
signal hazard_active(hazard_type: String, damage_per_tick: float)

# --- AUDIENCE & META ---
signal achievement_unlocked(title: String)          # Authorizes a loot box
signal sponsor_pod_incoming(target_location: Vector2)
signal hype_threshold_reached(tier_index: int)      # 50% / 75% / 90%

# --- NANO-MAGIC & EQUIPMENT ---
signal spell_cast(spell_name: String, location: Vector2)
signal mana_updated(current: float, max: float)
signal mana_depleted()

# --- SAFE ROOM & TERMINAL ---
signal box_opened(rarity: String)
signal item_acquired(item: Variant)
signal stat_injected(stat_name: String, new_value: int)

# --- NAVIGATION ---
signal phasedoor_discovered(location: Vector2)
signal toast(text: String, location: Vector2)   # transient on-screen notice (FeedbackManager)
