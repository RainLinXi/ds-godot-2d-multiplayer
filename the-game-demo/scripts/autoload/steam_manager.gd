class_name SteamMgr
extends Node
## Steam 管理器 — 全局单例
## 职责：Steam API 初始化 + 每帧 run_callbacks
## 不包含任何大厅/网络逻辑

var steam_enabled: bool = false


func _ready() -> void:
	_initialize_steam()


func _initialize_steam() -> void:
	var init_result: Dictionary = Steam.steamInitEx(480, false)
	var status: int = init_result.get("status", 0)

	if status != 1:
		push_warning("[SteamMgr] Steam 初始化失败 (status=%d, verbal='%s') — Steam 客户端可能未运行，多人模式不可用。" % [status, init_result.get("verbal", "未知")])
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
