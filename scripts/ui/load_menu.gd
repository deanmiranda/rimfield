extends Control

@export var dropdown: OptionButton  # Reference to the dropdown UI for load slots
@export var confirmation_panel: Control  # Reference to a confirmation UI panel
@export var load_button: Button  # Reference to the Load button

# Dictionary to hold save metadata for quick access when selecting
var save_metadata: Dictionary = {}

func _ready() -> void:
	# Populate the dropdown with save files
	_populate_load_slots()
	confirmation_panel.visible = false  # Hide the confirmation panel initially
	load_button.visible = dropdown.get_item_count() > 0  # Hide Load button if no saves

	# Connect the dropdown selection signal
	if dropdown and not dropdown.is_connected("item_selected", Callable(self, "_on_save_dropdown_item_selected")):
		dropdown.connect("item_selected", Callable(self, "_on_save_dropdown_item_selected"))
		print("Connected dropdown item_selected signal to _on_save_dropdown_item_selected")

	# Connect the Load button signal
	if load_button and not load_button.is_connected("pressed", Callable(self, "_on_load_button_pressed")):
		load_button.connect("pressed", Callable(self, "_on_load_button_pressed"))
		print("Connected load button pressed signal to _on_load_button_pressed")

# Populates the dropdown with available save files
func _populate_load_slots() -> void:
	dropdown.clear()  # Clear any existing options
	save_metadata.clear()  # Clear previous metadata
	print("Populating load slots...")

	dropdown.add_item("Select a Save Slot")  # Add a placeholder item to avoid preselection
	save_metadata[-1] = ""  # Add an invalid save metadata entry to the placeholder

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
			var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
			var formatted_date = "%s, %s %d, %d at %02d:%02d %s" % [
				_get_weekday(datetime.weekday),
				_get_month(datetime.month),
				datetime.day,
				datetime.year,
				(12 if datetime.hour % 12 == 0 else datetime.hour % 12),  # Corrected ternary syntax for hours
				datetime.minute,
				("PM" if datetime.hour >= 12 else "AM")  # Corrected ternary syntax for AM/PM
			]
			var scene_name = _get_scene_name_from_save(file_name)
			var display_text = "%s - %s" % [formatted_date, scene_name]

			print("Adding save file to dropdown:", display_text)
			dropdown.add_item(display_text)  # Add save slot to dropdown
			save_metadata[dropdown.get_item_count() - 1] = file_name  # Save metadata by dropdown index
		file_name = save_dir.get_next()
	save_dir.list_dir_end()

	load_button.visible = dropdown.get_item_count() > 1  # Update visibility of the Load button (ignore placeholder)
	print("Finished populating load slots. Load button visible:", load_button.visible)

# Helper functions for better date formatting
func _get_weekday(weekday: int) -> String:
	return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday]

func _get_month(month: int) -> String:
	return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][month - 1]

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
			print("Successfully retrieved scene name from save file:", save_data.get("current_scene", "Unknown Scene"))
			return save_data.get("current_scene", "Unknown Scene")
	return "Unknown Scene"

# Called when the Load button is pressed
func _on_load_button_pressed() -> void:
	var selected_index = dropdown.get_selected_id()
	print("Load button pressed. Selected index:", selected_index)

	if save_metadata.has(selected_index) and selected_index != 0:  # Ensure the placeholder item is not selected
		var file_name = save_metadata[selected_index]

		# Generate a pretty date and scene name for the confirmation panel
		var timestamp = _extract_timestamp_from_filename(file_name)
		var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
		var formatted_date = "%s, %s %d, %d at %02d:%02d %s" % [
			_get_weekday(datetime.weekday),
			_get_month(datetime.month),
			datetime.day,
			datetime.year,
			(12 if datetime.hour % 12 == 0 else datetime.hour % 12),  # Corrected ternary syntax for hours
			datetime.minute,
			("PM" if datetime.hour >= 12 else "AM")  # Corrected ternary syntax for AM/PM
		]
		var scene_name = _get_scene_name_from_save(file_name)
		var confirmation_text = "Load save from %s - %s?" % [formatted_date, scene_name]

		print("Setting confirmation panel text:", confirmation_text)

		# Call deferred to avoid any visual timing issues
		call_deferred("_set_confirmation_text", confirmation_text)
	else:
		print("Error: Invalid selection. Please select a valid save slot.")

func _set_confirmation_text(confirmation_text: String) -> void:
	var label_node = $CenterContainer/MainVBox/ConfirmationPanel/VBoxContainer/ConfirmationLabel
	if label_node:
		print("Setting deferred confirmation panel text:", confirmation_text)
		label_node.text = confirmation_text
		confirmation_panel.visible = true
	else:
		print("Error: ConfirmationLabel node not found.")
		
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
