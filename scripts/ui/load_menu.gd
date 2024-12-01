extends Control

@export var dropdown: OptionButton  # Reference to the dropdown UI for load slots
@export var confirmation_panel: Control  # Reference to a confirmation UI panel

# Dictionary to hold save metadata for quick access when selecting
var save_metadata: Dictionary = {}

func _ready() -> void:
	# Populate the dropdown with save files
	_populate_load_slots()
	confirmation_panel.visible = false  # Hide the confirmation panel initially

# Populates the dropdown with available save files
func _populate_load_slots() -> void:
	dropdown.clear()  # Clear any existing options
	save_metadata.clear()  # Clear previous metadata

	var save_dir = DirAccess.open("user://")
	if save_dir == null:
		print("Error: Could not open save directory.")
		return

	save_dir.list_dir_begin()  # Begin listing files in the user directory
	var file_name = save_dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
			# Load metadata for each save file
			var timestamp = _extract_timestamp_from_filename(file_name)
			var formatted_date = Time.get_datetime_string_from_unix_time(timestamp)
			var scene_name = _get_scene_name_from_save(file_name)
			var display_text = "%s - %s" % [formatted_date, scene_name]
			
			dropdown.add_item(display_text)  # Add save slot to dropdown
			save_metadata[dropdown.get_item_count() - 1] = file_name  # Save metadata by dropdown index
		file_name = save_dir.get_next()
	save_dir.list_dir_end()

# Extracts the timestamp from the save file name
func _extract_timestamp_from_filename(file_name: String) -> int:
	var components = file_name.split("_")
	if components.size() > 1:
		return components[-1].to_int()
	return 0

# Retrieves the scene name from the save file
func _get_scene_name_from_save(file_name: String) -> String:
	var file_path = "user://%s" % file_name
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if file_access:
		var json = JSON.new()
		var parse_status = json.parse(file_access.get_as_text())
		file_access.close()
		
		if parse_status == OK:
			var save_data = json.data
			return save_data.get("current_scene", "Unknown Scene")
	return "Unknown Scene"

# Called when a save slot is selected in the dropdown
func _on_save_dropdown_item_selected(index: int) -> void:
	if save_metadata.has(index):
		var file_name = save_metadata[index]
		var confirmation_text = "Load save from file: %s?" % file_name
		confirmation_panel.visible = true
		# Set confirmation text in the UI
		$CenterContainer/MainVBox/ConfirmationPanel/VBoxContainer/ConfirmationLabel.text = confirmation_text

# Called when the player confirms the load action
func _on_yes_button_pressed() -> void:
	var selected_index = dropdown.get_selected_id()
	if save_metadata.has(selected_index):
		GameState.load_game(save_metadata[selected_index])  # Load the selected save
		self.queue_free()  # Hide and remove the load menu from the scene tree to clean up
	confirmation_panel.visible = false  # Hide the confirmation panel
# Called when the player cancels the load action
func _on_no_button_pressed() -> void:
	confirmation_panel.visible = false  # Just hide the confirmation panel

# Called when the back button is pressed
func _on_back_button_pressed() -> void:
	self.visible = false  # Hide the load scene
