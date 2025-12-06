# music_manager.gd
# Global singleton for managing background music
# Features:
# - Random shuffle (play all songs before repeating)
# - 5 second gaps between songs
# - Continues playing across scenes
# - Does not stop on pause

extends Node

# Music player
var music_player: AudioStreamPlayer = null

# Available music tracks (excludes intro/main menu music)
var available_tracks: Array[String] = []
var current_playlist: Array[String] = []
var current_track_index: int = -1

# Gap timer between songs
var gap_timer: Timer = null
const GAP_DURATION: float = 5.0

# State
var is_playing: bool = false
var is_initialized: bool = false
var is_muted: bool = false
var saved_volume_db: float = 0.0

# Tracks to exclude (main menu/intro music)
const EXCLUDED_TRACKS: Array[String] = [
	"RimField-Intro.mp3"
]


func _ready() -> void:
	# Process even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.volume_db = 0.0
	add_child(music_player)
	
	# Connect finished signal to play next song
	music_player.finished.connect(_on_music_finished)
	
	# Create gap timer
	gap_timer = Timer.new()
	gap_timer.name = "MusicGapTimer"
	gap_timer.wait_time = GAP_DURATION
	gap_timer.one_shot = true
	gap_timer.timeout.connect(_on_gap_timer_timeout)
	add_child(gap_timer)
	
	# Scan for music files
	_scan_music_files()
	
	# Load saved mute state
	_load_mute_state()
	
	is_initialized = true
	print("[MusicManager] Initialized with %d tracks" % available_tracks.size())


func _scan_music_files() -> void:
	"""Scan assets/audio directory for .mp3 files"""
	var audio_dir = "res://assets/audio"
	var dir = DirAccess.open(audio_dir)
	
	if not dir:
		push_error("[MusicManager] Failed to open audio directory: %s" % audio_dir)
		return
	
	available_tracks.clear()
	
	# Scan directory for .mp3 files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".mp3") and not file_name.ends_with(".import"):
			# Check if track should be excluded
			var should_exclude = false
			for excluded in EXCLUDED_TRACKS:
				if file_name == excluded:
					should_exclude = true
					break
			
			if not should_exclude:
				var track_path = audio_dir + "/" + file_name
				available_tracks.append(track_path)
				print("[MusicManager] Found track: %s" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Shuffle available tracks for initial playlist
	_shuffle_playlist()


func _shuffle_playlist() -> void:
	"""Create a shuffled playlist from available tracks"""
	current_playlist = available_tracks.duplicate()
	
	# Fisher-Yates shuffle
	for i in range(current_playlist.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = current_playlist[i]
		current_playlist[i] = current_playlist[j]
		current_playlist[j] = temp
	
	current_track_index = 0
	print("[MusicManager] Created shuffled playlist with %d tracks" % current_playlist.size())


func start_music() -> void:
	"""Start playing background music (called on new game)"""
	if not is_initialized:
		push_error("[MusicManager] Cannot start music - not initialized")
		return
	
	if available_tracks.is_empty():
		push_error("[MusicManager] Cannot start music - no tracks available")
		return
	
	# Reset playlist if we've played all songs
	if current_track_index >= current_playlist.size():
		_shuffle_playlist()
	
	_play_next_track()


func stop_music() -> void:
	"""Stop background music"""
	if music_player:
		music_player.stop()
	if gap_timer:
		gap_timer.stop()
	is_playing = false
	print("[MusicManager] Music stopped")


func skip_track() -> void:
	"""Skip to the next track in the playlist"""
	if not is_initialized:
		push_error("[MusicManager] Cannot skip - not initialized")
		return
	
	if current_playlist.is_empty():
		push_error("[MusicManager] Cannot skip - playlist is empty")
		return
	
	# Stop current track
	if music_player:
		music_player.stop()
	
	# Stop gap timer if running
	if gap_timer:
		gap_timer.stop()
	
	# Move to next track
	current_track_index += 1
	
	# Reset playlist if we've played all songs
	if current_track_index >= current_playlist.size():
		_shuffle_playlist()
	
	# Play next track immediately (no gap when skipping)
	_play_next_track()
	print("[MusicManager] Track skipped")


func _play_next_track() -> void:
	"""Play the next track in the playlist"""
	if current_playlist.is_empty():
		push_error("[MusicManager] Cannot play - playlist is empty")
		return
	
	# Reset playlist if we've played all songs
	if current_track_index >= current_playlist.size():
		_shuffle_playlist()
	
	var track_path = current_playlist[current_track_index]
	
	# Load the track
	var audio_stream = load(track_path)
	if not audio_stream:
		push_error("[MusicManager] Failed to load track: %s" % track_path)
		# Skip to next track
		current_track_index += 1
		call_deferred("_play_next_track")
		return
	
	# Ensure stream doesn't loop
	if audio_stream is AudioStreamMP3:
		audio_stream.loop = false
	
	# Set stream and play
	music_player.stream = audio_stream
	
	# Apply mute state before playing
	if is_muted:
		music_player.volume_db = -80.0
	else:
		music_player.volume_db = saved_volume_db
	
	music_player.play()
	is_playing = true
	
	var track_name = track_path.get_file()
	print("[MusicManager] Playing: %s (%d/%d)" % [track_name, current_track_index + 1, current_playlist.size()])


func _on_music_finished() -> void:
	"""Called when current track finishes"""
	is_playing = false
	
	# Move to next track
	current_track_index += 1
	
	# Start gap timer before next song
	gap_timer.start()
	print("[MusicManager] Track finished, %d second gap before next track" % GAP_DURATION)


func _on_gap_timer_timeout() -> void:
	"""Called when gap timer expires - play next track"""
	_play_next_track()


func toggle_mute() -> void:
	"""Toggle music mute state"""
	is_muted = not is_muted
	
	if music_player:
		if is_muted:
			saved_volume_db = music_player.volume_db
			music_player.volume_db = -80.0
			print("[MusicManager] Music muted")
		else:
			music_player.volume_db = saved_volume_db
			print("[MusicManager] Music unmuted (volume: %.1f dB)" % saved_volume_db)
	
	# Save mute state to config
	_save_mute_state()


func set_muted(muted: bool) -> void:
	"""Set mute state explicitly"""
	if is_muted == muted:
		return
	
	is_muted = muted
	
	if music_player:
		if is_muted:
			saved_volume_db = music_player.volume_db
			music_player.volume_db = -80.0
			print("[MusicManager] Music muted")
		else:
			music_player.volume_db = saved_volume_db
			print("[MusicManager] Music unmuted (volume: %.1f dB)" % saved_volume_db)
	
	# Save mute state to config
	_save_mute_state()


func _save_mute_state() -> void:
	"""Save mute state to user config"""
	var config = ConfigFile.new()
	config.set_value("audio", "music_muted", is_muted)
	config.save("user://settings.cfg")


func _load_mute_state() -> void:
	"""Load mute state from user config"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		var muted = config.get_value("audio", "music_muted", false)
		if muted:
			set_muted(true)
