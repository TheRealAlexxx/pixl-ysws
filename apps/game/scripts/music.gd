extends Node

const TRACK_PATHS := [
	"res://assets/songs/intro_looped.mp3",
	"res://assets/songs/pixl_theme_2.mp3",
]
const MAX_LINEAR := 0.5

var _player: AudioStreamPlayer
var _last_track := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_play_random_track)
	apply_settings()
	_play_random_track()

# Picks a different track than whatever just finished, so back-to-back plays
# don't repeat the same song unless there's only one to pick from.
func _play_random_track() -> void:
	var idx := randi() % TRACK_PATHS.size()
	if TRACK_PATHS.size() > 1:
		while idx == _last_track:
			idx = randi() % TRACK_PATHS.size()
	_last_track = idx
	var stream: AudioStream = load(TRACK_PATHS[idx])
	_player.stream = stream
	if Settings.music_enabled and Settings.music_volume > 0.0:
		_player.play()

func apply_settings() -> void:
	if _player == null:
		return
	if Settings.music_enabled and Settings.music_volume > 0.0:
		_player.volume_db = linear_to_db(Settings.music_volume * MAX_LINEAR)
		if not _player.playing:
			_player.play()
	else:
		_player.volume_db = -80.0
