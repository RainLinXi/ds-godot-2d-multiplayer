class_name PlayerController
extends CharacterBody2D
## 玩家控制器 — 单人/多人通用（服务器权威模式）
## 职责：移动/跳跃/重力/命数/加成状态

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
var coyote_time: float = 0.08    # 离开平台后可跳跃的缓冲时间
var jump_buffer_time: float = 0.1  # 按跳跃键后的缓冲时间
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# 网络 ID（多人时由 GameWorld 设置）
var peer_id: int = 1

# 预加载
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visual_rect: ColorRect = $VisualRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var invincibility_timer: Timer = $InvincibilityTimer


func _ready() -> void:
	current_lives = max_lives
	alive = true
	add_to_group("player")
	# 放宽地板判定角度到 80°，让平台边缘的浅重叠也能被正确识别为地板
	# 默认 45° 太严格：边缘只有 2-3px 重叠时法线接近水平，会被误判为墙壁推开
	floor_max_angle = deg_to_rad(80.0)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	# 更新缓冲计时器
	_update_buffers(delta)

	# 处理输入和物理
	var input_x := Input.get_axis("ui_left", "ui_right")
	var want_jump := Input.is_action_just_pressed("ui_accept")

	_apply_movement(input_x, delta)
	_apply_jump(want_jump)
	_apply_gravity(delta)

	# 单向平台: 上升(v<0)关闭碰撞可穿过，下落/静止(v>=0)开启碰撞可站立
	# 搭配 floor_max_angle=80° 解决边缘法线偏水平导致滑落的问题
	set_collision_mask_value(1, velocity.y >= 0)
	move_and_slide()

	# 更新朝向
	if input_x != 0:
		facing_right = input_x > 0
	_update_visuals()


func _update_buffers(delta: float) -> void:
	# 土狼时间: 在地面上时重置，否则倒计时
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# 跳跃缓冲: 按跳跃键时充值，否则倒计时
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
		# 消耗缓冲
		coyote_timer = 0.0
		jump_buffer_timer = 0.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _update_visuals() -> void:
	if is_invincible:
		sprite.modulate = Color(1.0, 0.85, 0.3, 1.0)  # 金色闪烁
		visual_rect.color = Color(1.0, 0.85, 0.3, 1.0)
	else:
		sprite.modulate = Color.WHITE
		visual_rect.color = Color(0.2, 0.5, 0.9, 1.0)  # 蓝色
	sprite.flip_h = not facing_right
	visual_rect.scale.x = 1.0 if facing_right else -1.0


## 受到伤害 — 扣一条命并短暂无敌
func take_damage() -> void:
	if is_invincible or not alive:
		return

	current_lives -= 1

	if current_lives <= 0:
		die()
	else:
		# 短暂无敌防止连续受伤
		is_invincible = true
		invincibility_timer.start(1.5)
		# TODO: 播放受伤动画/音效


## 玩家死亡
func die() -> void:
	if not alive:
		return
	alive = false
	visible = false
	collision_shape.set_deferred("disabled", true)
	# GameWorld 会检测所有玩家死亡并结束游戏


## 复活（阶段 4 多人时由服务器调用）
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
