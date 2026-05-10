class_name GameHUD
extends Control
## 游戏 HUD — 显示本地玩家的命数/得分 + 游戏结束面板
## 多人模式: 显示自己的状态，不显示其他玩家的

var game_world: GameWorld
@onready var lives_label: Label = %LivesLabel
@onready var score_label: Label = %ScoreLabel
@onready var game_over_panel: Panel = %GameOverPanel
@onready var game_over_label: Label = %GameOverLabel
@onready var restart_btn: Button = %RestartBtn
@onready var menu_btn: Button = %MenuBtn

var score: int = 0


func _ready() -> void:
	game_over_panel.hide()


func setup(p_game_world: GameWorld) -> void:
	game_world = p_game_world


func _process(_delta: float) -> void:
	var player := _get_my_player()
	if not player:
		return

	lives_label.text = "命数: " + str(player.current_lives)
	score_label.text = "得分: " + str(score)


## 找到本地玩家
func _get_my_player() -> PlayerController:
	if not game_world or not is_instance_valid(game_world.local_player):
		return null
	return game_world.local_player


func add_score(amount: int) -> void:
	score += amount


func show_game_over() -> void:
	game_over_panel.show()
	game_over_label.text = "游戏结束!\n得分: " + str(score)

	# 多人模式: 只显示返回菜单（不允许个人重启）
	if multiplayer.multiplayer_peer:
		restart_btn.hide()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	# 多人模式: 离开前先清理网络状态
	if multiplayer.multiplayer_peer:
		LobbyMgr.leave_lobby()
		get_tree().multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
