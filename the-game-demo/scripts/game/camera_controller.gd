class_name CameraController
extends Node2D
## 相机控制器 — 持续垂直上升 + 跟踪玩家 + 掉落死亡检测
## 多人模式: 每个客户端只跟随自己的玩家

@export var base_rise_speed: float = 40.0
@export var rise_acceleration: float = 0.5
@export var death_margin: float = 100.0

var current_rise_speed: float
var elapsed_time: float = 0.0

var game_world: Node2D

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	current_rise_speed = base_rise_speed


func setup(p_game_world: Node2D) -> void:
	game_world = p_game_world


func _process(delta: float) -> void:
	elapsed_time += delta
	current_rise_speed = base_rise_speed + rise_acceleration * elapsed_time

	# 固定速度上升
	camera.position.y -= current_rise_speed * delta

	# 多人模式: 只跟踪本地玩家
	var my_player := _get_my_player()
	if my_player:
		# 相机水平跟随本地玩家
		camera.position.x = my_player.position.x

	# 获取存活玩家列表
	var alive_list: Array = []
	for p: PlayerController in get_tree().get_nodes_in_group("player"):
		if p.alive:
			alive_list.append(p)

	if alive_list.is_empty():
		return

	# 检测掉落: 玩家超出相机底部即扣命 (仅本地玩家的死亡由本地检测)
	var viewport_height := get_viewport_rect().size.y
	var camera_bottom := camera.position.y + viewport_height / 2.0

	for p: PlayerController in alive_list:
		# 只检查本地玩家或单机模式的所有玩家
		if _is_multiplayer() and p.peer_id != _get_my_steam_id():
			continue
		if p.position.y > camera_bottom + death_margin:
			game_world.on_player_fell(p)


func get_camera_top_y() -> float:
	var viewport_height := get_viewport_rect().size.y
	return camera.position.y - viewport_height / 2.0


func get_camera_bottom_y() -> float:
	var viewport_height := get_viewport_rect().size.y
	return camera.position.y + viewport_height / 2.0


## 获取本地玩家的节点
func _get_my_player() -> PlayerController:
	var my_steam_id := _get_my_steam_id()
	for p: PlayerController in get_tree().get_nodes_in_group("player"):
		if p.peer_id == my_steam_id:
			return p
	return null


func _get_my_steam_id() -> int:
	if not SteamMgr.steam_enabled:
		return 1
	return Steam.getSteamID()


func _is_multiplayer() -> bool:
	return multiplayer.multiplayer_peer != null
