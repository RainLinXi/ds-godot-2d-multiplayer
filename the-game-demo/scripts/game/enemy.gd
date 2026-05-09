class_name Enemy
extends CharacterBody2D
## 敌人 AI — 在平台上左右巡逻
## 碰撞检测由权威端处理，移动在所有客户端确定性计算

@export var patrol_speed: float = 60.0       # 巡逻速度
@export var patrol_distance: float = 150.0   # 从出生点向两侧巡逻的最大距离

var spawn_position: Vector2
var move_direction: int = 1  # 1=右, -1=左
var is_alive: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visual_rect: ColorRect = $VisualRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var death_timer: Timer = $DeathTimer


func _ready() -> void:
	spawn_position = position
	add_to_group("enemy")


func _process(delta: float) -> void:
	if not is_alive:
		return

	# 巡逻移动（确定性，所有客户端独立运行）
	position.x += move_direction * patrol_speed * delta

	# 到达巡逻边界时转向
	if abs(position.x - spawn_position.x) > patrol_distance:
		move_direction *= -1

	# 更新视觉朝向
	sprite.flip_h = move_direction < 0
	visual_rect.scale.x = 1.0 if move_direction > 0 else -1.0


func _physics_process(_delta: float) -> void:
	if not is_alive:
		return

	# 碰撞检测：检测与玩家的重叠
	var overlapping := detection_area.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player") and body.alive:
			_on_hit_player(body)


## 碰到玩家
func _on_hit_player(player: PlayerController) -> void:
	if player.is_invincible:
		# 玩家无敌 → 敌人被消灭
		die()
	else:
		# 正常碰撞 → 玩家扣命
		player.take_damage()


## 敌人死亡
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	sprite.hide()
	visual_rect.hide()
	collision_shape.set_deferred("disabled", true)
	# 短暂显示死亡特效后销毁
	death_timer.start(0.3)


func _on_death_timer_timeout() -> void:
	queue_free()
