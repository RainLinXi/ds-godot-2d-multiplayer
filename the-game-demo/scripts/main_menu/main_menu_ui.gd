extends Control
## 主菜单 UI — 游戏入口界面
## 4 个按钮: 单人游戏 / 多人游戏 / 设置 / 退出

@onready var settings_panel: Panel = %SettingsPanel
@onready var settings_menu: SettingsMenuUI = %SettingsMenuUI


func _ready() -> void:
	settings_panel.hide()


func _on_single_player_pressed() -> void:
	print("[MainMenu] 单人游戏")
	# 阶段 2 实现 — 暂时打印日志
	# GameMgr.start_single_player()


func _on_multiplayer_pressed() -> void:
	print("[MainMenu] 多人游戏")
	# 阶段 3 实现 — 进入大厅
	# LobbyMgr.create_lobby()
	# get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_settings_pressed() -> void:
	settings_panel.show()


func _on_settings_close() -> void:
	settings_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
