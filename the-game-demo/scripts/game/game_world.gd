class_name GameWorld
extends Node2D
## 游戏世界总控 — 协调所有子系统
## 职责：初始化玩家/生成器/相机、处理死亡/复活、游戏结束判定

# 复活参数
@export var respawn_offset: Vector2 = Vector2(0, -150.0)

# 子系统引用
var camera_controller: CameraController
var platform_generator: PlatformGenerator
var local_player: PlayerController

# 游戏状态
var game_over: bool = false

# 预加载
const PLAYER_SCENE := preload("res://scenes/game/player.tscn")

@onready var platforms_parent: Node2D = %Platforms
@onready var enemies_parent: Node2D = %Enemies
@onready var hud: GameHUD = %GameHUD


func _ready() -> void:
	camera_controller = %CameraController as CameraController
	platform_generator = %PlatformGenerator as PlatformGenerator

	# 设置子系统引用
	camera_controller.setup(self)
	platform_generator.setup(platforms_parent, enemies_parent, camera_controller)
	hud.setup(self)

	# 创建本地玩家
	_spawn_local_player()

	game_over = false


## 创建本地玩家（单人模式）
func _spawn_local_player() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	# 在地面中央生成
	player.position = Vector2(get_viewport_rect().size.x / 2.0, -50.0)
	player.peer_id = 1
	$Players.add_child(player)
	local_player = player


## 玩家掉出相机 — 触发死亡
func on_player_fell(player: PlayerController) -> void:
	if not player.alive:
		return

	player.die()

	# 尝试在最高存活玩家上方复活
	_try_respawn_player(player)


## 尝试复活玩家
func _try_respawn_player(player: PlayerController) -> void:
	if game_over:
		return

	if player.current_lives > 0:
		var spawn_pos := _get_highest_player_position()
		spawn_pos.y -= 100.0  # 在最高玩家上方
		player.respawn(spawn_pos)
	else:
		# 检查是否所有玩家都死了
		_check_all_dead()


## 获取最高存活玩家的位置
func _get_highest_player_position() -> Vector2:
	var highest_y := 99999.0
	var highest_pos := Vector2(get_viewport_rect().size.x / 2.0, 0.0)
	for p in get_tree().get_nodes_in_group("player"):
		if p.alive and p.position.y < highest_y:
			highest_y = p.position.y
			highest_pos = p.position
	return highest_pos


## 检查是否所有玩家都无剩余命数
func _check_all_dead() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.current_lives > 0:
			return  # 还有玩家活着

	# 全部死亡 → 游戏结束
	trigger_game_over()


## 游戏结束
func trigger_game_over() -> void:
	if game_over:
		return
	game_over = true
	hud.show_game_over()


## 获取相机视图高度，用于 PlatformGenerator
func get_viewport_height() -> float:
	return get_viewport_rect().size.y
