extends Node
## Steam 管理器 — 全局单例
## 职责：Steam API 初始化 + 每帧 run_callbacks
## 不包含任何大厅/网络逻辑

var steam_enabled: bool = false


func _ready() -> void:
	_initialize_steam()


func _initialize_steam() -> void:
	var init_result = Steam.steamInitEx(480, false)
	print("[SteamMgr] steamInitEx 原始返回值: ", init_result, " (type=", typeof(init_result), ")")

	# 兼容不同 GDExtension 版本的返回格式
	var status: int = -1
	if typeof(init_result) == TYPE_DICTIONARY:
		status = init_result.get("status", -1)
	elif typeof(init_result) == TYPE_INT:
		status = init_result

	if status != 1:
		push_warning("[SteamMgr] Steam 初始化失败 (status=%d) — Steam 客户端可能未运行，多人模式不可用。" % status)
		steam_enabled = false
		return

	# 启用 P2P 中继网络（大厅通信必需）
	Steam.initRelayNetworkAccess()
	steam_enabled = true

	var steam_id: int = Steam.getSteamID()
	var persona: String = Steam.getFriendPersonaName(steam_id)
	print("[SteamMgr] Steam 初始化成功 — 用户: %s (ID: %d)" % [persona, steam_id])


func _process(_delta: float) -> void:
	# Steam 回调必须每帧在主线程运行
	if steam_enabled:
		Steam.run_callbacks()
