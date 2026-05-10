class_name GameWorld
extends Node2D
## 游戏世界总控 — 协调所有子系统
## 职责：初始化玩家/生成器/相机、处理死亡/复活、游戏结束判定
## 单人与多人模式自动适配

# 复活参数
@export var respawn_offset: Vector2 = Vector2(0, -150.0)

# 子系统引用
var camera_controller: CameraController
var platform_generator: PlatformGenerator
var local_player: PlayerController

# 游戏状态
var game_over: bool = false

# 多人模式玩家映射 (steam_id → PlayerController)
var _players: Dictionary = {}

# 预加载
const PLAYER_SCENE := preload("res://scenes/game/player.tscn")

@onready var platforms_parent: Node2D = %Platforms
@onready var enemies_parent: Node2D = %Enemies
@onready var hud: GameHUD = %GameHUD


func _ready() -> void:
	camera_controller = %CameraController as CameraController
	platform_generator = %PlatformGenerator as PlatformGenerator

	camera_controller.setup(self)
	hud.setup(self)

	game_over = false

	# 检测多人模式: multiplayer_peer 已设置且大厅有成员
	var has_peer := multiplayer.multiplayer_peer != null
	var has_members := LobbyMgr.members.size() > 0
	var is_multi := has_peer and has_members
	print("[GameWorld] _ready: has_peer=%s has_members=%s is_multi=%s members=%d" % [has_peer, has_members, is_multi, LobbyMgr.members.size()])

	# 多人模式使用共享种子 (lobby_id)，单人模式随机
	var seed_val: int = LobbyMgr.lobby_id if is_multi else 0
	platform_generator.setup(platforms_parent, enemies_parent, camera_controller, seed_val)

	if is_multi:
		_setup_multiplayer()
	else:
		_spawn_local_player()


# ════════════════════════════════════════════
# 多人模式
# ════════════════════════════════════════════

## 初始化多人游戏：双方各自本地生成所有玩家节点（不依赖 RPC 生成）
func _setup_multiplayer() -> void:
	print("[GameWorld] 多人模式 — 大厅成员数: %d" % LobbyMgr.members.size())
	_spawn_all_players()


## 为所有大厅成员生成玩家节点（主机和客户端都调用）
func _spawn_all_players() -> void:
	print("[GameWorld] 生成所有玩家节点...")
	var idx := 0
	for m in LobbyMgr.members:
		var sid: int = m.steam_id
		var spawn_x := get_viewport_rect().size.x / 2.0 + (idx - 1) * 120.0
		_create_player_node(sid, Vector2(spawn_x, 550.0))
		idx += 1


## 本地创建一个玩家节点
func _create_player_node(steam_id: int, spawn_pos: Vector2) -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.position = spawn_pos
	player.peer_id = steam_id
	player.name = "Player_%d" % steam_id
	$Players.add_child(player)
	_players[steam_id] = player

	# 标记本地玩家
	if steam_id == Steam.getSteamID():
		local_player = player

	print("[GameWorld] 生成玩家 — steam_id=%d, pos=%s, is_local=%s" % [steam_id, spawn_pos, steam_id == Steam.getSteamID()])


# ════════════════════════════════════════════
# 单人模式
# ════════════════════════════════════════════

func _spawn_local_player() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.position = Vector2(get_viewport_rect().size.x / 2.0, 550.0)
	player.peer_id = 1
	$Players.add_child(player)
	local_player = player


# ════════════════════════════════════════════
# 死亡 / 复活 / 游戏结束
# ════════════════════════════════════════════

## 玩家掉出相机 — 触发死亡
func on_player_fell(player: PlayerController) -> void:
	if not player.alive:
		return

	player.die()

	# 尝试在最高存活玩家上方复活
	_try_respawn_player(player)


func _try_respawn_player(player: PlayerController) -> void:
	if game_over:
		return

	if player.current_lives > 0:
		var spawn_pos := _get_highest_player_position()
		spawn_pos.y -= 100.0
		player.respawn(spawn_pos)
	else:
		# 检查是否所有玩家都死了
		_check_all_dead()


func _get_highest_player_position() -> Vector2:
	var highest_y := 99999.0
	var highest_pos := Vector2(get_viewport_rect().size.x / 2.0, 0.0)
	for p: PlayerController in get_tree().get_nodes_in_group("player"):
		if p.alive and p.position.y < highest_y:
			highest_y = p.position.y
			highest_pos = p.position
	return highest_pos


func _check_all_dead() -> void:
	for p: PlayerController in get_tree().get_nodes_in_group("player"):
		if p.current_lives > 0:
			return

	trigger_game_over()


func trigger_game_over() -> void:
	if game_over:
		return
	game_over = true
	hud.show_game_over()


func get_viewport_height() -> float:
	return get_viewport_rect().size.y


## 获取本地玩家的 Steam ID（供其他系统使用）
func get_local_steam_id() -> int:
	return Steam.getSteamID() if SteamMgr.steam_enabled else 1
