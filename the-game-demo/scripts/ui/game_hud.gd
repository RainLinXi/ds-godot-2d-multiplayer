class_name GameHUD
extends Control
## 游戏 HUD — 显示命数/得分 + 游戏结束面板
## 职责：实时更新 UI、显示结算界面

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
	if not game_world or not is_instance_valid(game_world.local_player):
		return

	# 更新命数显示
	var player := game_world.local_player
	lives_label.text = "命数: " + str(player.current_lives)
	score_label.text = "得分: " + str(score)


## 加分
func add_score(amount: int) -> void:
	score += amount


## 显示游戏结束面板
func show_game_over() -> void:
	game_over_panel.show()
	game_over_label.text = "游戏结束!\n得分: " + str(score)


func _on_restart_pressed() -> void:
	# 重新加载当前场景
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
