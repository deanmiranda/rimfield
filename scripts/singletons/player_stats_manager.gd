extends Node

## PlayerStatsManager - Single Source of Truth for Player Stats
##
## Manages Health, Energy, and Happiness stats with signals for UI updates.
## Lightweight, modular system that integrates with existing game systems.

# Stat variables
var max_health: int = 100
var health: int = 100
var max_energy: int = 100
var energy: int = 100
var max_happiness: int = 100
var happiness: int = 100

# Signals
signal health_changed(new_health: int, max_health: int)
signal energy_changed(new_energy: int, max_energy: int)
signal happiness_changed(new_happiness: int, max_happiness: int)


func _ready() -> void:
	"""Initialize stats to default values"""
	health = max_health
	energy = max_energy
	happiness = max_happiness
	
	# Emit initial signals so UI can sync
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)
	happiness_changed.emit(happiness, max_happiness)


func consume_energy(amount: int) -> bool:
	"""Consume energy. Returns false if insufficient energy."""
	if amount <= 0:
		return true # No cost, always succeeds
	
	if energy <= 0:
		print("[PlayerStats] Cannot consume energy: already at 0")
		return false
	
	if energy < amount:
		print("[PlayerStats] Cannot consume energy: need %d, have %d" % [amount, energy])
		return false
	
	energy -= amount
	energy = max(0, energy) # Clamp to 0
	print("[PlayerStats] Energy consumed: %d (remaining: %d/%d)" % [amount, energy, max_energy])
	energy_changed.emit(energy, max_energy)
	return true


func restore_energy_full() -> void:
	"""Fully restore energy to maximum"""
	var old_energy = energy
	energy = max_energy
	print("[PlayerStats] Energy fully restored: %d -> %d/%d" % [old_energy, energy, max_energy])
	energy_changed.emit(energy, max_energy)


func take_damage(amount: int) -> void:
	"""Take damage, reducing health"""
	if amount <= 0:
		return
	
	var old_health = health
	health -= amount
	health = max(0, health) # Clamp to 0
	print("[PlayerStats] Damage taken: %d (health: %d -> %d/%d)" % [amount, old_health, health, max_health])
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	"""Heal, increasing health"""
	if amount <= 0:
		return
	
	var old_health = health
	health += amount
	health = min(max_health, health) # Clamp to max
	print("[PlayerStats] Healed: %d (health: %d -> %d/%d)" % [amount, old_health, health, max_health])
	health_changed.emit(health, max_health)


func modify_happiness(amount: int) -> void:
	"""Modify happiness (can be positive or negative). Clamps to 0-max_happiness."""
	if amount == 0:
		return
	
	var old_happiness = happiness
	happiness += amount
	happiness = clamp(happiness, 0, max_happiness) # Clamp to 0-max
	print("[PlayerStats] Happiness modified: %d (happiness: %d -> %d/%d)" % [amount, old_happiness, happiness, max_happiness])
	happiness_changed.emit(happiness, max_happiness)


func get_energy_percent() -> float:
	"""Get energy as a percentage (0.0 to 1.0)"""
	if max_energy <= 0:
		return 0.0
	return float(energy) / float(max_energy)


func get_health_percent() -> float:
	"""Get health as a percentage (0.0 to 1.0)"""
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)


func get_happiness_percent() -> float:
	"""Get happiness as a percentage (0.0 to 1.0)"""
	if max_happiness <= 0:
		return 0.0
	return float(happiness) / float(max_happiness)
