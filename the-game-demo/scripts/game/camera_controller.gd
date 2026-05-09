class_name CameraController
extends Node2D
## 相机控制器 — 持续垂直上升 + 跟踪玩家 + 掉落死亡检测
## 职责：控制 Camera2D 上升速度、检测玩家是否掉出视野

@export var base_rise_speed: float = 40.0     # 基础上升速度（像素/秒）
@export var rise_acceleration: float = 0.5    # 每秒加速量
@export var death_margin: float = 100.0       # 超出相机底部多少像素判定死亡
@export var min_player_gap: float = 120.0     # 相机底部与最低玩家的最小间距

var current_rise_speed: float
var elapsed_time: float = 0.0

var game_world: Node2D  # GameWorld 引用，用于触发死亡/结束
var alive_players: Array = []

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	current_rise_speed = base_rise_speed


func setup(p_game_world: Node2D) -> void:
	game_world = p_game_world


func _process(delta: float) -> void:
	elapsed_time += delta
	current_rise_speed = base_rise_speed + rise_acceleration * elapsed_time

	# 收集存活玩家
	alive_players.clear()
	for p: PlayerController in get_tree().get_nodes_in_group("player"):
		if p.alive:
			alive_players.append(p)

	if alive_players.is_empty():
		return  # 由 GameWorld 处理游戏结束

	# 找最低的存活玩家
	var lowest_y: float = alive_players[0].position.y
	for p: PlayerController in alive_players:
		if p.position.y > lowest_y:
			lowest_y = p.position.y

	# 调整上升速度: 如果最低玩家接近相机底部，减速等待
	var viewport_height := get_viewport_rect().size.y
	var camera_bottom := camera.position.y + viewport_height / 2.0
	var speed_mult := 1.0

	if lowest_y > camera_bottom - min_player_gap:
		speed_mult = max(0.0, (camera_bottom - lowest_y) / min_player_gap)

	# 应用相机上升
	camera.position.y -= current_rise_speed * speed_mult * delta

	# 检测掉落: 玩家超出相机底部一定距离
	camera_bottom = camera.position.y + viewport_height / 2.0
	for p: PlayerController in alive_players:
		if p.position.y > camera_bottom + death_margin:
			game_world.on_player_fell(p)


## 获取相机视图顶部 Y 坐标（供 PlatformGenerator 使用）
func get_camera_top_y() -> float:
	var viewport_height := get_viewport_rect().size.y
	return camera.position.y - viewport_height / 2.0


## 获取相机视图底部 Y 坐标
func get_camera_bottom_y() -> float:
	var viewport_height := get_viewport_rect().size.y
	return camera.position.y + viewport_height / 2.0
