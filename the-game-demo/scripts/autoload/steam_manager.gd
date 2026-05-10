extends Node
## Steam 管理器 — 全局单例
## 职责：验证 Steam 自动初始化 + 每帧 run_callbacks
## 注意：初始化由 project.godot [steam] 配置自动完成

var steam_enabled: bool = false


func _ready() -> void:
	# project.godot 已配置 initialize_on_startup=true, steamInitEx 已自动调用
	# 只需验证初始化是否成功并设置中继网络
	var steam_id: int = Steam.getSteamID()
	print("[SteamMgr] Steam ID: %d (0=未运行)" % steam_id)

	if steam_id == 0:
		push_warning("[SteamMgr] Steam 未运行或初始化失败，多人模式不可用。")
		steam_enabled = false
		return

	Steam.initRelayNetworkAccess()
	steam_enabled = true
	var persona: String = Steam.getFriendPersonaName(steam_id)
	print("[SteamMgr] Steam 初始化成功 — 用户: %s (ID: %d)" % [persona, steam_id])


func _process(_delta: float) -> void:
	if steam_enabled:
		Steam.run_callbacks()
