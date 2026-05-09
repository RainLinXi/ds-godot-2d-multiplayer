extends Control
## 主菜单 UI — 游戏入口界面
## 4 个按钮: 单人游戏 / 多人游戏 / 设置 / 退出

@onready var settings_panel: Panel = %SettingsPanel
@onready var settings_menu: SettingsMenuUI = %SettingsMenuUI


func _ready() -> void:
	settings_panel.hide()


func _on_single_player_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


func _on_multiplayer_pressed() -> void:
	print("[MainMenu] 多人游戏")
	if not LobbyMgr.is_steam_available():
		_show_steam_unavailable()
		return
	LobbyMgr.create_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_settings_pressed() -> void:
	settings_panel.show()


func _on_settings_close() -> void:
	settings_panel.hide()


func _show_steam_unavailable() -> void:
	# 弹出 Steam 不可用提示
	var dialog := AcceptDialog.new()
	dialog.title = "Steam 未运行"
	dialog.dialog_text = "Steam 客户端未运行或初始化失败。\n\n请先启动 Steam 客户端再使用多人模式。"
	dialog.add_theme_font_size_override("font_size", 14)
	add_child(dialog)
	dialog.popup_centered()


func _on_quit_pressed() -> void:
	get_tree().quit()
