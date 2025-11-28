extends Node

## DebugControls - Centralized Debug Input Handler
##
## Handles all debug key inputs (F5, F6, etc.) for testing game systems.
## Only active in debug builds to prevent debug keys in release builds.

var DEBUG_ENABLED: bool = false


func _ready() -> void:
	"""Initialize debug controls - only enable input processing in debug builds"""
	DEBUG_ENABLED = OS.is_debug_build() # Initialize here instead of as const
	if DEBUG_ENABLED:
		set_process_input(true)
		print("[DebugControls] Debug controls enabled (debug build)")
	else:
		set_process_input(false)
		print("[DebugControls] Debug controls disabled (release build)")


func _input(event: InputEvent) -> void:
	"""Handle debug input keys"""
	if not DEBUG_ENABLED:
		return
	
	# Only handle key events
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	
	# Skip debug keys in non-game scenes (main menu, etc.)
	if UiManager and UiManager.has_method("_is_not_game_scene"):
		if UiManager._is_not_game_scene():
			return
	
	# Handle debug keys
	match event.keycode:
		KEY_F5:
			# Drain 10 energy via PlayerStatsManager.consume_energy(10)
			if PlayerStatsManager:
				PlayerStatsManager.consume_energy(10)
				print("[Debug] F5 → drain 10 energy: %d/%d" % [
					PlayerStatsManager.energy,
					PlayerStatsManager.max_energy,
				])
				get_viewport().set_input_as_handled()
		
		KEY_F6:
			# Restore 10 energy (up to max), emit energy_changed
			if PlayerStatsManager:
				var old_energy: int = PlayerStatsManager.energy
				var new_energy: int = min(
					PlayerStatsManager.max_energy,
					PlayerStatsManager.energy + 10
				)
				if new_energy != PlayerStatsManager.energy:
					PlayerStatsManager.energy = new_energy
					PlayerStatsManager.energy_changed.emit(
						new_energy,
						PlayerStatsManager.max_energy
					)
				print("[Debug] F6 → restore 10 energy: %d → %d/%d" % [
					old_energy,
					PlayerStatsManager.energy,
					PlayerStatsManager.max_energy,
				])
				get_viewport().set_input_as_handled()
