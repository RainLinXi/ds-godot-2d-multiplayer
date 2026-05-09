extends Node
## 音频管理器 — 全局单例
## 职责：管理游戏音效和背景音乐的播放、音量控制

const SOUNDS_DIR := "res://assets/sounds/"

# 音效资源缓存
var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _volume_multiplier: float:
	get:
		return SettingsMgr.master_volume if SettingsMgr else 1.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_music_player)


## 播放音效
func play_sfx(sfx_path: String, volume_db: float = 0.0) -> void:
	# 计算实际音量
	var final_volume := volume_db + linear_to_db(_volume_multiplier * (SettingsMgr.sfx_volume if SettingsMgr else 1.0))

	# 使用缓存避免重复加载
	var stream: AudioStream
	if _sfx_cache.has(sfx_path):
		stream = _sfx_cache[sfx_path]
	else:
		stream = load(sfx_path)
		if stream:
			_sfx_cache[sfx_path] = stream
		else:
			return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = final_volume
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## 播放背景音乐
func play_music(music_path: String, fade_in: float = 1.0, volume_db: float = -10.0) -> void:
	var stream: AudioStream = load(music_path)
	if stream == null:
		return
	if _music_player.playing:
		_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = volume_db + linear_to_db(_volume_multiplier * (SettingsMgr.music_volume if SettingsMgr else 1.0))
	_music_player.play()


## 停止音乐
func stop_music(fade_out: float = 0.0) -> void:
	if fade_out > 0:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80, fade_out)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()


## 音量变更时调用此方法刷新
func refresh_volumes() -> void:
	if _music_player.playing:
		_music_player.volume_db = linear_to_db(_volume_multiplier * (SettingsMgr.music_volume if SettingsMgr else 1.0))
