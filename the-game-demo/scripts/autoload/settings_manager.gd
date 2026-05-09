extends Node
## 设置管理器 — 全局单例
## 职责：持久化存储和读取游戏设置（音量、玩家名等）

const SETTINGS_PATH := "user://settings.cfg"

# 默认设置值
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var player_name: String = "Player"

var _config: ConfigFile


func _ready() -> void:
	_config = ConfigFile.new()
	_load_settings()


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		# 首次启动，写入默认值
		_save_settings()
		return

	master_volume = _config.get_value("audio", "master_volume", 1.0)
	sfx_volume = _config.get_value("audio", "sfx_volume", 1.0)
	music_volume = _config.get_value("audio", "music_volume", 1.0)
	player_name = _config.get_value("player", "name", "Player")


func save_settings() -> void:
	_save_settings()


func _save_settings() -> void:
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("player", "name", player_name)
	_config.save(SETTINGS_PATH)
