class_name PlatformGenerator
extends Node2D
## 平台随机生成器
## 垂直方向不断生成可站立的平台，确保可达性

# 生成参数
@export var layer_height: float = 150.0
@export var platform_width_min: float = 120.0
@export var platform_width_max: float = 280.0
@export var world_width: float = 1152.0
@export var wall_margin: float = 50.0
@export var jump_distance_max: float = 320.0
@export var jump_height_max: float = 220.0
@export var lookahead_layers: int = 6
@export var cleanup_layers_below: int = 3
@export var enemy_chance: float = 0.25
@export var ground_y: float = 580.0  # 初始地面 Y 坐标（屏幕底部附近）

# 内部状态
var max_generated_layer: int = 0
var all_platforms: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var highest_generated_y: float = 0.0  # 已生成的最上方平台的 Y 坐标

# 场景路径
const PLATFORM_SCENE := "res://scenes/game/platform.tscn"
const ENEMY_SCENE := "res://scenes/game/enemy.tscn"

# 外部引用（GameWorld 在 setup() 中注入）
var platforms_parent: Node2D
var enemies_parent: Node2D
var camera_controller: Node2D
var ready_to_generate: bool = false


func _ready() -> void:
	rng.randomize()
	# 注意: _generate_initial_floor() 在 setup() 中调用，因为需要 platforms_parent 和 camera


func setup(p_platforms_parent: Node2D, p_enemies_parent: Node2D, p_camera_controller: Node2D) -> void:
	platforms_parent = p_platforms_parent
	enemies_parent = p_enemies_parent
	camera_controller = p_camera_controller
	_generate_initial_floor()
	ready_to_generate = true


func _process(_delta: float) -> void:
	if not ready_to_generate or not camera_controller:
		return

	var camera_top_y: float = camera_controller.get_camera_top_y()

	# 在相机上方预生成平台层
	while highest_generated_y > camera_top_y - (lookahead_layers * layer_height):
		max_generated_layer += 1
		_generate_layer(max_generated_layer)
		highest_generated_y = ground_y - (max_generated_layer * layer_height)


## 生成起始安全区域
func _generate_initial_floor() -> void:
	# 地面层（layer 0）— 宽大平台，在屏幕底部
	_spawn_platform(world_width / 2.0, ground_y, 350.0)
	all_platforms.append({"layer": 0, "x": world_width / 2.0 - 175.0, "y": ground_y, "width": 350.0})

	# 向上几层做安全引导
	var safe_layouts := [
		{"offset_x": 0, "width": 260.0},
		{"offset_x": -120, "width": 200.0},
		{"offset_x": 120, "width": 200.0},
		{"offset_x": -50, "width": 240.0},
	]

	for i in safe_layouts.size():
		var layer := i + 1
		var base_y := ground_y - (layer * layer_height)
		var cx: float = world_width / 2.0 + safe_layouts[i].offset_x
		var w: float = safe_layouts[i].width
		_spawn_platform(cx, base_y, w)
		all_platforms.append({"layer": layer, "x": cx - w / 2.0, "y": base_y, "width": w})

	max_generated_layer = safe_layouts.size()
	highest_generated_y = ground_y - (max_generated_layer * layer_height)


## 生成单层平台
func _generate_layer(layer: int) -> void:
	var base_y := ground_y - (layer * layer_height)
	var prev_platforms := _get_platforms_in_layer(layer - 1)

	if prev_platforms.is_empty():
		_spawn_platform(world_width / 2.0, base_y, 200.0)
		all_platforms.append({"layer": layer, "x": world_width / 2.0 - 100.0, "y": base_y, "width": 200.0})
		return

	# 随机尝试找可到达的候选位置
	var candidates: Array = []
	for _attempt in 10:
		var width := rng.randf_range(platform_width_min, platform_width_max)
		var cx: float = rng.randf_range(wall_margin + width / 2.0, world_width - wall_margin - width / 2.0)

		if _is_reachable_from_prev(cx, base_y, width, prev_platforms):
			candidates.append({"x": cx - width / 2.0, "y": base_y, "width": width})

	# 候选不足时强制在上一平台上方生成
	if candidates.size() < 1:
		var ref: Dictionary = prev_platforms[0]
		var forced_cx: float = ref.x + ref.width / 2.0 + rng.randf_range(-60.0, 60.0)
		forced_cx = clamp(forced_cx, wall_margin + platform_width_min / 2.0, world_width - wall_margin - platform_width_min / 2.0)
		candidates.append({"x": forced_cx - platform_width_min / 2.0, "y": base_y, "width": platform_width_min})

	var count: int = clampi(rng.randi_range(1, 3), 1, candidates.size())
	candidates.shuffle()
	for i in count:
		var p = candidates[i]
		_spawn_platform(p.x + p.width / 2.0, p.y, p.width)
		all_platforms.append({"layer": layer, "x": p.x, "y": p.y, "width": p.width})

		if rng.randf() < enemy_chance:
			_spawn_enemy(p.x + p.width / 2.0, p.y)


## 从上一层是否可达
func _is_reachable_from_prev(cx: float, cy: float, width: float, prev_platforms: Array) -> bool:
	for prev: Dictionary in prev_platforms:
		var prev_cx: float = prev.x + prev.width / 2.0
		if abs(cx - prev_cx) <= jump_distance_max and abs(cy - prev.y) <= jump_height_max:
			return true
	return false


func _get_platforms_in_layer(layer: int) -> Array:
	var result: Array = []
	for p: Dictionary in all_platforms:
		if p.layer == layer:
			result.append(p)
	return result


func _spawn_platform(cx: float, y: float, width: float) -> void:
	var plat_scene := load(PLATFORM_SCENE) as PackedScene
	if not plat_scene:
		return
	var plat := plat_scene.instantiate() as Platform
	plat.position = Vector2(cx, y)
	plat.set_width(width)
	platforms_parent.add_child(plat)


func _spawn_enemy(x: float, platform_y: float) -> void:
	var enemy_scene := load(ENEMY_SCENE) as PackedScene
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.position = Vector2(x, platform_y - 30.0)
	enemies_parent.add_child(enemy)
