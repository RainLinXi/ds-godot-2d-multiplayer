class_name Platform
extends StaticBody2D
## 平台 — 可站立的静态物体

@onready var color_rect: ColorRect = $ColorRect


## 设置平台宽度（从 PlatformGenerator 调用）
func set_width(width: float) -> void:
	var half := width / 2.0
	# 更新碰撞体
	var shape := $CollisionShape2D.shape as RectangleShape2D
	shape.size = Vector2(width, 20.0)
	# 更新视觉
	color_rect.position = Vector2(-half, -10.0)
	color_rect.size = Vector2(width, 20.0)
