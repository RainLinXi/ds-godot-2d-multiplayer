extends Panel
## 设置子面板 — 音量调节 + 玩家名输入
## 作为 MainMenu 的子节点，点击"游戏设置"时弹出

@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var name_input: LineEdit = %NameInput


func _ready() -> void:
	# 加载当前设置到 UI
	master_slider.value = SettingsMgr.master_volume * 100
	sfx_slider.value = SettingsMgr.sfx_volume * 100
	music_slider.value = SettingsMgr.music_volume * 100
	name_input.text = SettingsMgr.player_name


func _on_master_volume_changed(value: float) -> void:
	SettingsMgr.master_volume = value / 100.0
	SettingsMgr.save_settings()
	AudioMgr.refresh_volumes()


func _on_sfx_volume_changed(value: float) -> void:
	SettingsMgr.sfx_volume = value / 100.0
	SettingsMgr.save_settings()


func _on_music_volume_changed(value: float) -> void:
	SettingsMgr.music_volume = value / 100.0
	SettingsMgr.save_settings()
	AudioMgr.refresh_volumes()


func _on_name_text_changed(new_text: String) -> void:
	SettingsMgr.player_name = new_text
	SettingsMgr.save_settings()
