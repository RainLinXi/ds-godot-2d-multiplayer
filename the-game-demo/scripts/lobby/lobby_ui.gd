class_name LobbyUI
extends Control
## 大厅 UI — 纯展示层
## 所有逻辑委托给 LobbyMgr，仅负责刷新界面

@onready var status_label: Label = %StatusLabel
@onready var lobby_id_label: Label = %LobbyIdLabel
@onready var member_container: VBoxContainer = %MemberContainer
@onready var start_game_btn: Button = %StartGameBtn
@onready var leave_btn: Button = %LeaveBtn
@onready var info_label: Label = %InfoLabel


func _ready() -> void:
	# 连接 LobbyMgr 信号
	LobbyMgr.lobby_created.connect(_on_lobby_created)
	LobbyMgr.lobby_joined.connect(_on_lobby_joined)
	LobbyMgr.lobby_left.connect(_on_lobby_left)
	LobbyMgr.lobby_join_failed.connect(_on_lobby_join_failed)
	LobbyMgr.member_joined.connect(_on_member_joined)
	LobbyMgr.member_left.connect(_on_member_left)
	LobbyMgr.members_refreshed.connect(_on_members_refreshed)
	LobbyMgr.error_occurred.connect(_on_error)

	# 初始 UI 状态
	start_game_btn.hide()
	status_label.text = "正在创建大厅..."
	info_label.text = ""

	# 模拟进入：LobbyMgr 的 create_lobby 已在 MainMenu 中调用
	# 如果 LobbyMgr.lobby_id 已设置，说明信号已触发（连接前就完成了）
	if LobbyMgr.lobby_id != 0:
		_on_lobby_created(LobbyMgr.lobby_id)


# ════════════════════════════════════════════
# LobbyMgr 信号回调
# ════════════════════════════════════════════

func _on_lobby_created(p_lobby_id: int) -> void:
	status_label.text = "大厅已创建 — 等待其他玩家..."
	lobby_id_label.text = "大厅 ID: %d" % p_lobby_id
	start_game_btn.show()
	_refresh_member_list()


func _on_lobby_joined(p_lobby_id: int) -> void:
	status_label.text = "已加入大厅 — 等待房主开始游戏..."
	lobby_id_label.text = "大厅 ID: %d" % p_lobby_id
	start_game_btn.hide()
	_refresh_member_list()


func _on_lobby_left() -> void:
	status_label.text = "已离开大厅"


func _on_lobby_join_failed(reason: String) -> void:
	info_label.text = "加入失败: " + reason
	status_label.text = "加入大厅失败"


func _on_member_joined(steam_id: int, player_name: String) -> void:
	_refresh_member_list()
	info_label.text = "%s 加入了房间" % player_name


func _on_member_left(_steam_id: int, player_name: String) -> void:
	_refresh_member_list()
	info_label.text = "%s 离开了房间" % player_name


func _on_members_refreshed() -> void:
	_refresh_member_list()


func _on_error(message: String) -> void:
	info_label.text = "错误: " + message


# ════════════════════════════════════════════
# UI 刷新
# ════════════════════════════════════════════

func _refresh_member_list() -> void:
	# 清空现有成员条目
	for child in member_container.get_children():
		child.queue_free()

	# 重建成员列表
	for m in LobbyMgr.members:
		var label := Label.new()
		var name: String = m.get("name", "未知")
		var sid: int = m.get("steam_id", 0)

		if sid == Steam.getSteamID():
			label.text = "★ %s (你)" % name
			label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			label.text = "  %s" % name
			label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))

		label.add_theme_font_size_override("font_size", 18)
		member_container.add_child(label)


# ════════════════════════════════════════════
# 按钮回调
# ════════════════════════════════════════════

func _on_start_game_pressed() -> void:
	LobbyMgr.start_game()


func _on_leave_pressed() -> void:
	LobbyMgr.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_invite_pressed() -> void:
	# 打开 Steam Overlay 邀请好友
	if LobbyMgr.lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(LobbyMgr.lobby_id)
