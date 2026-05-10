class_name PlayerController
extends CharacterBody2D
## 玩家控制器 — 单人/多人通用
## 单人: 本地输入直驱
## 多人: 每个客户端控制自己的角色 (peer_id == Steam ID)，位置通过 RPC 同步

# 基础参数
@export var move_speed: float = 250.0
@export var jump_velocity: float = -580.0
@export var gravity: float = 980.0
@export var max_lives: int = 3

# 当前状态
var current_lives: int
var alive: bool = true
var facing_right: bool = true

# 队友加成状态（阶段 5 实现）
var has_teammate_bonus: bool = false
var is_invincible: bool = false
var bonus_speed_mult: float = 1.5
var bonus_jump_mult: float = 1.3

# 缓冲系统
var coyote_time: float = 0.08
var jump_buffer_time: float = 0.1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# 网络 ID（对应用户的 Steam ID，单人模式默认 1）
var peer_id: int = 1

# 位置同步 (仅多人模式下自己的角色需要广播给其他客户端)
const SYNC_INTERVAL: float = 0.05   # 每秒 20 次
var _sync_timer: float = 0.0
var _is_multiplayer: bool = false
var _first_sync_logged: bool = false  # 仅首次收到同步时打印日志
var _first_send_logged: bool = false  # 仅首次发送同步时打印日志

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visual_rect: ColorRect = $VisualRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var invincibility_timer: Timer = $InvincibilityTimer


func _ready() -> void:
	current_lives = max_lives
	alive = true
	add_to_group("player")
	floor_max_angle = deg_to_rad(80.0)

	# 检测多人模式
	_is_multiplayer = multiplayer.multiplayer_peer != null
	if _is_multiplayer:
		print("[Player] peer_id=%d, my_steam_id=%d, is_mine=%s" % [peer_id, _get_my_steam_id(), _is_my_player()])


func _physics_process(delta: float) -> void:
	if not alive:
		# 已死亡: 远程玩家仍需碰撞检测（保持同步位置可站立于平台）
		if _is_multiplayer and not _is_my_player():
			set_collision_mask_value(1, velocity.y >= 0)
			move_and_slide()
		return

	if not _is_my_player():
		# 远程玩家: 碰撞检测用于正确站立在平台上
		set_collision_mask_value(1, velocity.y >= 0)
		move_and_slide()
		return

	# ── 以下仅本地玩家执行 ──
	_update_buffers(delta)

	var input_x := Input.get_axis("ui_left", "ui_right")
	var want_jump := Input.is_action_just_pressed("ui_accept")

	_apply_movement(input_x, delta)
	_apply_jump(want_jump)
	_apply_gravity(delta)

	# 单向平台
	set_collision_mask_value(1, velocity.y >= 0)
	move_and_slide()

	# 更新朝向
	if input_x != 0:
		facing_right = input_x > 0
		_update_visuals()

	# 广播位置给其他客户端
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		if not _first_send_logged:
			_first_send_logged = true
			print("[Player] _sync_state 首次发送: peer_id=%d pos=%s" % [peer_id, position])
		_sync_state.rpc(position, velocity, facing_right, alive)


func _update_buffers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)


func _apply_movement(input_x: float, _delta: float) -> void:
	var speed := move_speed
	if has_teammate_bonus:
		speed *= bonus_speed_mult
	velocity.x = input_x * speed


func _apply_jump(want_jump: bool) -> void:
	var can_coyote := coyote_timer > 0.0
	var has_buffered := jump_buffer_timer > 0.0

	if want_jump and can_coyote and has_buffered:
		var jump_vel := jump_velocity
		if has_teammate_bonus:
			jump_vel *= bonus_jump_mult
		velocity.y = jump_vel
		coyote_timer = 0.0
		jump_buffer_timer = 0.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _update_visuals() -> void:
	if is_invincible:
		sprite.modulate = Color(1.0, 0.85, 0.3, 1.0)
		visual_rect.color = Color(1.0, 0.85, 0.3, 1.0)
	else:
		sprite.modulate = Color.WHITE
		visual_rect.color = Color(0.2, 0.5, 0.9, 1.0)
	sprite.flip_h = not facing_right
	visual_rect.scale.x = 1.0 if facing_right else -1.0


# ════════════════════════════════════════════
# 多人同步 RPC
# ════════════════════════════════════════════

## 广播自己的状态给所有其他客户端 (unreliable = 低延迟, 不保证送达)
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _sync_state(pos: Vector2, vel: Vector2, facing: bool, is_alive: bool) -> void:
	if not _first_sync_logged:
		_first_sync_logged = true
		print("[Player] _sync_state 首次收到: peer_id=%d pos=%s" % [peer_id, pos])

	if _is_my_player():
		return  # 不覆盖自己的状态

	position = pos
	velocity = vel

	if facing_right != facing:
		facing_right = facing
		_update_visuals()

	if alive != is_alive:
		alive = is_alive
		visible = is_alive
		collision_shape.set_deferred("disabled", not is_alive)


# ════════════════════════════════════════════
# 伤害 / 死亡 / 复活
# ════════════════════════════════════════════

## 主机调用此 RPC 通知客户端受伤
@rpc("authority", "reliable", "call_remote")
func _rpc_take_damage() -> void:
	take_damage()


## 受到伤害 — 扣一条命并短暂无敌
func take_damage() -> void:
	if is_invincible or not alive:
		return

	current_lives -= 1

	if current_lives <= 0:
		die()
	else:
		is_invincible = true
		invincibility_timer.start(1.5)


func die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	collision_shape.set_deferred("disabled", true)


func respawn(spawn_pos: Vector2) -> void:
	position = spawn_pos
	velocity = Vector2.ZERO
	alive = true
	visible = true
	collision_shape.set_deferred("disabled", false)
	current_lives = max_lives


## 启用队友加成
func enable_teammate_bonus() -> void:
	has_teammate_bonus = true
	is_invincible = true


## 禁用队友加成
func disable_teammate_bonus() -> void:
	has_teammate_bonus = false
	is_invincible = false


func _on_invincibility_timer_timeout() -> void:
	is_invincible = false


# ════════════════════════════════════════════
# 工具方法
# ════════════════════════════════════════════

## 判断当前玩家是否属于本客户端
func _is_my_player() -> bool:
	if not _is_multiplayer:
		return true  # 单人模式，总是自己的
	return peer_id == _get_my_steam_id()


func _get_my_steam_id() -> int:
	if not SteamMgr.steam_enabled:
		return 1
	return Steam.getSteamID()
