class_name PlatformGenerator
extends Node2D
## 平台随机生成器 — 仅在服务器上运行
## 垂直方向不断生成可站立的平台，确保可达性

# 生成参数
@export var layer_height: float = 150.0           # 每层垂直间距
@export var platform_width_min: float = 120.0     # 平台最小宽度
@export var platform_width_max: float = 280.0     # 平台最大宽度
@export var world_width: float = 1152.0           # 世界宽度
@export var wall_margin: float = 50.0             # 边缘留白
@export var jump_distance_max: float = 320.0      # 玩家最大水平跳跃距离
@export var jump_height_max: float = 220.0        # 玩家最大跳跃高度
@export var lookahead_layers: int = 6             # 相机前方预生成的层数
@export var cleanup_layers_below: int = 3         # 相机下方保留层数
@export var enemy_chance: float = 0.25            # 平台生成敌人概率

# 内部状态
var max_generated_layer: int = 0
var all_platforms: Array = []   # [{layer, x, y, width}]
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# 已生成区域的最小 Y 坐标（world Y 向上为负）
var highest_generated_y: float = 0.0

# 场景路径
const PLATFORM_SCENE := "res://scenes/game/platform.tscn"
const ENEMY_SCENE := "res://scenes/game/enemy.tscn"

# 外部引用（GameWorld 注入）
var platforms_parent: Node2D
var enemies_parent: Node2D
var camera_controller: Node2D


func _ready() -> void:
	rng.randomize()
	_generate_initial_floor()


func setup(p_platforms_parent: Node2D, p_enemies_parent: Node2D, p_camera_controller: Node2D) -> void:
	platforms_parent = p_platforms_parent
	enemies_parent = p_enemies_parent
	camera_controller = p_camera_controller


func _process(_delta: float) -> void:
	if not camera_controller:
		return

	# 获取相机顶部 Y 坐标
	var camera_top_y: float = camera_controller.get_camera_top_y()

	# 在相机前方预生成平台层
	while highest_generated_y > camera_top_y - (lookahead_layers * layer_height):
		max_generated_layer += 1
		_generate_layer(max_generated_layer)
		highest_generated_y = -(max_generated_layer * layer_height)


## 生成起始安全区域（地面 + 几层简单平台）
func _generate_initial_floor() -> void:
	# 生成起始地面（宽大的平台）
	for i in range(1):
		var base_y := 0.0
		_spawn_platform(world_width / 2.0, base_y, 300.0)
		all_platforms.append({"layer": 0, "x": world_width / 2.0 - 150.0, "y": base_y, "width": 300.0})

	# 生成前几层的安全平台（引导玩家向上）
	var safe_layouts := [
		{"offset_x": 0, "width": 250.0},
		{"offset_x": -120, "width": 200.0},
		{"offset_x": 120, "width": 200.0},
		{"offset_x": -50, "width": 250.0},
	]

	for i in safe_layouts.size():
		var layer := i + 1
		var base_y := -(layer * layer_height)
		var cx := world_width / 2.0 + safe_layouts[i].offset_x
		var w := safe_layouts[i].width
		_spawn_platform(cx, base_y, w)
		all_platforms.append({"layer": layer, "x": cx - w / 2.0, "y": base_y, "width": w})

	max_generated_layer = safe_layouts.size()
	highest_generated_y = -(max_generated_layer * layer_height)


## 生成单层平台
func _generate_layer(layer: int) -> void:
	var base_y := -(layer * layer_height)
	var prev_platforms := _get_platforms_in_layer(layer - 1)

	if prev_platforms.is_empty():
		# 回退: 在世界中央生成
		_spawn_platform(world_width / 2.0, base_y, 200.0)
		all_platforms.append({"layer": layer, "x": world_width / 2.0 - 100.0, "y": base_y, "width": 200.0})
		return

	# 尝试找可到达的候选位置
	var candidates: Array = []
	for _attempt in 10:
		var width := rng.randf_range(platform_width_min, platform_width_max)
		var x := rng.randf_range(wall_margin + width / 2.0, world_width - wall_margin - width / 2.0)

		if _is_reachable(x, base_y, width, prev_platforms):
			candidates.append({"x": x - width / 2.0, "y": base_y, "width": width})

	# 如果候选不足，在最近平台正上方强制生成
	if candidates.size() < 1:
		var ref := prev_platforms[0]
		var forced_cx := ref.x + ref.width / 2.0 + rng.randf_range(-60.0, 60.0)
		forced_cx = clamp(forced_cx, wall_margin + platform_width_min / 2.0, world_width - wall_margin - platform_width_min / 2.0)
		candidates.append({"x": forced_cx - platform_width_min / 2.0, "y": base_y, "width": platform_width_min})

	# 选择 1~3 个候选实际生成
	var count := clampi(rng.randi_range(1, 3), 1, candidates.size())
	candidates.shuffle()
	for i in count:
		var p = candidates[i]
		_spawn_platform(p.x + p.width / 2.0, p.y, p.width)
		all_platforms.append({"layer": layer, "x": p.x, "y": p.y, "width": p.width})

		# 随机生成敌人
		if rng.randf() < enemy_chance:
			_spawn_enemy(p.x + p.width / 2.0, p.y)


## 检查新平台是否从上一层可达
func _is_reachable(cx: float, cy: float, width: float, prev_platforms: Array) -> bool:
	for prev in prev_platforms:
		var prev_cx := prev.x + prev.width / 2.0
		var dx := abs(cx - prev_cx)
		var dy := abs(cy - prev.y)

		# 水平距离在跳跃范围内，垂直距离在跳跃高度内
		if dx <= jump_distance_max and dy <= jump_height_max:
			# 额外检查: 新平台不能比上一层的最高点还高太多
			var reachable_height := prev.y - jump_height_max
			if cy >= reachable_height:
				return true

	return false


## 获取某一层的所有平台
func _get_platforms_in_layer(layer: int) -> Array:
	var result: Array = []
	for p in all_platforms:
		if p.layer == layer:
			result.append(p)
	return result


## 生成平台节点
func _spawn_platform(cx: float, y: float, width: float) -> void:
	var plat_scene := load(PLATFORM_SCENE) as PackedScene
	if not plat_scene:
		return
	var plat := plat_scene.instantiate() as Platform
	plat.position = Vector2(cx, y)
	plat.set_width(width)
	platforms_parent.add_child(plat)


## 在平台上生成敌人
func _spawn_enemy(x: float, platform_y: float) -> void:
	var enemy_scene := load(ENEMY_SCENE) as PackedScene
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.position = Vector2(x, platform_y - 30.0)
	enemies_parent.add_child(enemy)
