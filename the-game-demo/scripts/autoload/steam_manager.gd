extends Node
## Steam 管理器 — 全局单例
## Steam 初始化 + 每帧 run_callbacks

var steam_enabled: bool = false
var _init_attempted: bool = false


func _ready() -> void:
	_init_attempted = true
	# 尝试手动初始化（兼容不同 GDExtension 版本）
	var ok: bool = Steam.steamInit()
	print("[SteamMgr] steamInit() = %s" % ok)

	if not ok:
		# 也许已经通过 project.godot 自动初始化了？检查一下
		if Steam.getSteamID() != 0:
			ok = true
			print("[SteamMgr] 自动初始化已生效")

	if not ok:
		push_warning("[SteamMgr] Steam 初始化失败 — 多人模式不可用")
		steam_enabled = false
		return

	Steam.initRelayNetworkAccess()
	steam_enabled = true
	var steam_id: int = Steam.getSteamID()
	var persona: String = Steam.getFriendPersonaName(steam_id)
	print("[SteamMgr] Steam 就绪 — 用户: %s (ID: %d)" % [persona, steam_id])


func _process(_delta: float) -> void:
	if steam_enabled:
		Steam.run_callbacks()
