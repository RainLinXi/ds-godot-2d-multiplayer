extends Node
## 大厅管理器 — 全局单例
## 职责：大厅创建/加入/离开、成员管理、SteamMultiplayerPeer 生命周期
## 所有 Steam 信号在此集中处理，通过信号通知 UI

# ── 信号（供 LobbyUI 监听）────

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_left()
signal lobby_join_failed(reason: String)
signal member_joined(steam_id: int, player_name: String)
signal member_left(steam_id: int, player_name: String)
signal members_refreshed()          # 成员列表整体刷新（供 UI 重绘）
signal error_occurred(message: String)

# ── 状态变量 ────

var lobby_id: int = 0               # 0 = 无大厅
var is_host: bool = false
var members: Array = []             # [{steam_id: int, name: String}]
var multiplayer_peer: RefCounted  # SteamMultiplayerPeer (GDExtension C++ 类)
var _is_creating: bool = false      # 防止 createLobby 双重信号


# ════════════════════════════════════════════
# 公共 API
# ════════════════════════════════════════════

func is_steam_available() -> bool:
	return SteamMgr.steam_enabled


## 创建大厅（房主调用）
func create_lobby() -> void:
	if not _check_steam():
		return

	_is_creating = true
	print("[LobbyMgr] 正在创建大厅...")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)


## 加入大厅（客户端调用）
func join_lobby(p_lobby_id: int) -> void:
	if not _check_steam():
		return

	print("[LobbyMgr] 正在加入大厅 %d..." % p_lobby_id)
	Steam.joinLobby(p_lobby_id)


## 离开大厅
func leave_lobby() -> void:
	print("[LobbyMgr] 离开大厅 %d" % lobby_id)

	# 关闭网络对等端
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null

	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)

	lobby_id = 0
	is_host = false
	members.clear()
	_is_creating = false

	lobby_left.emit()


## 开始游戏 — 通过 Steam 大厅数据通知客户端同步切换
func start_game() -> void:
	if not is_host:
		error_occurred.emit("只有房主可以开始游戏")
		return

	print("[LobbyMgr] 房主开始游戏 — 通过 lobby_data 通知客户端")
	# 设置大厅数据 "state"="in_game"，客户端监听此变化自动切换
	Steam.setLobbyData(lobby_id, "state", "in_game")

	# 激活 P2P 网络并切换场景
	_activate_and_switch()


## 获取当前大厅成员数量
func get_member_count() -> int:
	return members.size()


# ════════════════════════════════════════════
# 内部方法
# ════════════════════════════════════════════

func _check_steam() -> bool:
	if not SteamMgr.steam_enabled:
		error_occurred.emit("Steam 未运行，无法使用多人模式")
		return false
	return true


func _ready() -> void:
	_connect_steam_signals()


func _connect_steam_signals() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	# 好友通过 Steam 叠加层接受邀请 → 自动加入大厅
	Steam.join_requested.connect(_on_join_requested)
	# 大厅数据变更（用于信号场景切换等）
	Steam.lobby_data_update.connect(_on_lobby_data_update)


# ── Steam 回调处理 ────

func _on_lobby_created(connect: int, created_id: int) -> void:
	if connect != 1:
		error_occurred.emit("大厅创建失败 (Steam 连接错误)")
		_is_creating = false
		return

	lobby_id = created_id
	is_host = true

	# 设置大厅属性（可被搜索、加入）
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "name", SettingsMgr.player_name + " 的房间")
	# 启用 P2P 数据包中继（客户端间穿透 NAT）
	Steam.allowP2PPacketRelay(true)

	# 创建 SteamMultiplayerPeer 并绑定大厅
	multiplayer_peer = SteamMultiplayerPeer.new()
	var err: int = multiplayer_peer.host_with_lobby(lobby_id)
	if err != OK:
		push_warning("[LobbyMgr] host_with_lobby 失败 (err=%d)" % err)

	# 将自己加入成员列表
	_add_self_to_members()

	print("[LobbyMgr] 大厅创建成功 — ID: %d" % lobby_id)
	lobby_created.emit(lobby_id)


func _on_lobby_joined(joined_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# createLobby 会同时触发 lobby_created 和 lobby_joined
	# 房主已在 _on_lobby_created 中处理，这里跳过
	if _is_creating:
		_is_creating = false
		return

	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var reason := "加入大厅失败 (错误码 %d)" % response
		print("[LobbyMgr] " + reason)
		lobby_join_failed.emit(reason)
		return

	lobby_id = joined_id
	is_host = false

	# 创建 SteamMultiplayerPeer 并连接大厅
	multiplayer_peer = SteamMultiplayerPeer.new()
	var err: int = multiplayer_peer.connect_to_lobby(lobby_id)
	if err != OK:
		push_warning("[LobbyMgr] connect_to_lobby 失败 (err=%d)" % err)

	# 刷新成员列表
	_refresh_members()

	print("[LobbyMgr] 已加入大厅 — ID: %d, 成员数: %d" % [lobby_id, members.size()])
	lobby_joined.emit(lobby_id)


func _on_lobby_chat_update(_chat_lobby_id: int, _changed_user_id: int, _making_change_id: int, _chat_state: int) -> void:
	if lobby_id == 0:
		return
	_refresh_members()


## 好友通过 Steam 叠加层接受邀请 → 自动加入大厅
func _on_join_requested(p_lobby_id: int, _friend_id: int) -> void:
	print("[LobbyMgr] 收到好友邀请 — 加入大厅 %d (好友: %d)" % [p_lobby_id, _friend_id])
	join_lobby(p_lobby_id)
	# 切换到大厅场景（join_lobby 异步完成，UI 通过信号更新）
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


## 大厅数据变更 — 用于检测房主开始游戏等信号
func _on_lobby_data_update(success: int, p_lobby_id: int, _member_id: int) -> void:
	print("[LobbyMgr] lobby_data_update: success=%d lobby=%d my_lobby=%d" % [success, p_lobby_id, lobby_id])
	if not success:
		return
	# 手动查询 "state" 键判断房主是否开始了游戏
	var state: String = Steam.getLobbyData(p_lobby_id, "state")
	print("[LobbyMgr] 大厅数据变更: lobby=%d state='%s' (is_host=%s)" % [p_lobby_id, state, is_host])
	if state == "in_game" and not is_host:
		print("[LobbyMgr] 房主已开始游戏 — 切换到 game_world")
		_activate_and_switch()


## 激活 P2P 网络并切换到游戏场景（主机和客户端共用）
func _activate_and_switch() -> void:
	get_tree().set("multiplayer_peer", multiplayer_peer)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


# ── 成员管理 ────

func _add_self_to_members() -> void:
	var steam_id: int = Steam.getSteamID()
	var name: String = Steam.getFriendPersonaName(steam_id)
	members.append({"steam_id": steam_id, "name": name})


func _refresh_members() -> void:
	var old_ids: Array = []
	for m in members:
		old_ids.append(m.steam_id)

	members.clear()
	var count: int = Steam.getNumLobbyMembers(lobby_id)
	for i in count:
		var steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
		var name: String = Steam.getFriendPersonaName(steam_id)
		members.append({"steam_id": steam_id, "name": name})

	# 对比变化，发送增减信号
	var new_ids: Array = []
	for m in members:
		new_ids.append(m.steam_id)

	for old_id in old_ids:
		if old_id not in new_ids:
			var old_name := ""
			for m in members:
				if m.steam_id == old_id:
					old_name = m.name
					break
			if old_name == "":
				old_name = "玩家 %d" % old_id
			member_left.emit(old_id, old_name)

	for new_id in new_ids:
		if new_id not in old_ids:
			var new_name: String = Steam.getFriendPersonaName(new_id)
			member_joined.emit(new_id, new_name)

	members_refreshed.emit()
