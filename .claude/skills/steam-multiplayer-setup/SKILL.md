---
name: Steam 多人游戏大厅集成
description: >
  Use this skill whenever the user wants to add Steam multiplayer lobby support
  to a Godot 4.4+ project. Covers GodotSteam GDExtension installation, Steam
  initialization, lobby creation/joining, member management, and lobby UI.
  Trigger when the user mentions: Steam multiplayer, Steam lobby, GodotSteam,
  Steam P2P, 多人联机, Steam 大厅, or similar multiplayer networking tasks
  in a Godot project context.
---

# Steam 多人游戏大厅集成

## 概述

本 skill 提供将 Steam 多人游戏大厅功能集成到 Godot 4.4+ 项目的完整流程。

覆盖范围：
- GodotSteam GDExtension 安装与配置
- Steam 初始化与回调处理
- 大厅创建、加入、离开、成员管理
- 大厅 UI 展示
- 主菜单入口集成

**未覆盖**（待后续阶段）：
- 游戏内网络同步（MultiplayerSpawner / MultiplayerSynchronizer）
- 游戏内 RPC 通信

---

## 前置条件

- Godot 4.4+
- Steam 客户端已安装并运行
- 一个 Steam App ID（开发阶段用 480 SpaceWar）

---

## 步骤 1：安装 GodotSteam GDExtension

从以下地址下载最新 GodotSteam GDExtension：
- https://codeberg.org/GodotSteam/godotsteam-gdextension/releases

解压后将 `addons/godotsteam/` 目录放入项目根目录。

### steam_appid.txt

在项目根目录创建 `steam_appid.txt`，内容为你的 App ID：

```
480
```

### DLL 版本匹配（Windows 常见问题）

Godot 编辑器自带的 `steam_api64.dll` 可能与 GDExtension 需要的版本不匹配。

**症状**：启动时报错 "无法定位程序输入点 SteamAPI_SteamApps_v009"

**修复**：将 `addons/godotsteam/win64/steam_api64.dll` 复制到 Godot 编辑器所在目录（覆盖原有文件）。建议先备份旧 dll 为 `.bak`。

---

## 步骤 2：配置 project.godot

在项目 `project.godot` 中添加：

```ini
[autoload]

SteamMgr="*res://scripts/autoload/steam_manager.gd"
LobbyMgr="*res://scripts/autoload/lobby_manager.gd"

[steam]

initialization/app_id=480
initialization/initialize_on_startup=true
initialization/embed_callbacks=false
multiplayer_peer/max_channels=4
```

**关键点**：
- `SteamMgr` 必须在 `LobbyMgr` **之前**注册（LobbyMgr 依赖 SteamMgr.steam_enabled）
- `embed_callbacks=false` 避免内置回调的已知 bug
- `initialize_on_startup=true` 让 GDExtension 在引擎启动时自动初始化；手动 `steamInit()` 作为兜底

---

## 步骤 3：创建 SteamMgr Autoload

文件：`scripts/autoload/steam_manager.gd`

```gdscript
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
```

**关键点**：
- 使用 `Steam.steamInit()` 而非 `steamInitEx()` — 前者返回 `bool`，跨版本兼容性更好
- `steamInitEx()` 在不同 GDExtension 版本中返回值格式不一致（Dict 或 int）
- `initRelayNetworkAccess()` 是 P2P 大厅通信的前提
- `run_callbacks()` **必须每帧调用**，否则 Steam 信号不会触发
- **不要给这个脚本加 `class_name`** — autoload 名称与 class_name 冲突会导致编辑器报错

---

## 步骤 4：创建 LobbyMgr Autoload

文件：`scripts/autoload/lobby_manager.gd`

```gdscript
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
var multiplayer_peer: RefCounted    # SteamMultiplayerPeer (GDExtension C++ 类)
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


## 开始游戏（阶段 3: 仅切换场景；阶段 4: 先激活 multiplayer_peer 再切换）
func start_game() -> void:
	if not is_host:
		error_occurred.emit("只有房主可以开始游戏")
		return

	print("[LobbyMgr] 房主开始游戏 — 切换到 game_world")
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


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
```

**关键点**：
- **不要加 `class_name`** — 与 autoload 名称冲突
- `multiplayer_peer` 类型用 `RefCounted` 而非 `SteamMultiplayerPeer` — GDExtension C++ 类不能作为 GDScript 类型注解
- `Steam.createLobby()` 会**同时触发** `lobby_created` 和 `lobby_joined` 信号，用 `_is_creating` 标记区分
- 成员刷新用 `lobby_chat_update` 信号（每次全量刷新），比手动解析 bitmask 更可靠
- 如果你的项目没有 SettingsMgr，把 `SettingsMgr.player_name` 替换为固定字符串或你自己的设置系统

---

## 步骤 5：创建大厅 UI

### 场景结构

```
Lobby (Control)
├── Background (ColorRect, 深色背景)
├── VBoxContainer
│   ├── TitleLabel ("多人游戏大厅")
│   ├── StatusLabel ("正在创建大厅...")
│   ├── LobbyIdLabel ("大厅 ID: —")
│   ├── HSeparator
│   ├── MemberLabel ("成员列表:")
│   ├── MemberContainer (VBoxContainer — 动态添加成员条目)
│   ├── HSeparator
│   ├── InfoLabel (状态提示文字)
│   └── ButtonRow (HBoxContainer)
│       ├── StartGameBtn ("开始游戏", 仅房主可见)
│       ├── InviteBtn ("邀请好友")
│       └── LeaveBtn ("离开大厅")
```

节点使用 `%` 唯一名称（Scene Unique Name）让脚本引用更简洁。

### 脚本

文件：`scripts/lobby/lobby_ui.gd`

```gdscript
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

	# 如果 LobbyMgr.lobby_id 已设置（信号在场景加载前已触发）
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


func _on_member_joined(_steam_id: int, player_name: String) -> void:
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
```

**关键点**：
- 不要给 LobbyUI 加 `class_name`（可选，但保持一致性）
- `_ready()` 中检查 `LobbyMgr.lobby_id != 0` 处理信号在连接前已触发的竞态
- 成员列表用 `m.get("name", "未知")` 安全取值，避免运行时错误

---

## 步骤 6：主菜单集成

在主菜单脚本的多人按钮回调中：

```gdscript
func _ready() -> void:
	# 显示 Steam 连接状态
	if not LobbyMgr.is_steam_available():
		multiplayer_btn.text = "多人游戏 (Steam 未连接)"
		multiplayer_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _on_multiplayer_pressed() -> void:
	if not LobbyMgr.is_steam_available():
		_show_steam_unavailable()
		return
	LobbyMgr.create_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _show_steam_unavailable() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Steam 未运行"
	dialog.dialog_text = "Steam 客户端未运行或初始化失败。\n\n请先启动 Steam 客户端再使用多人模式。"
	dialog.add_theme_font_size_override("font_size", 14)
	add_child(dialog)
	dialog.popup_centered()
```

---

## 常见 Bug 与修复

### 1. DLL 版本不匹配

**症状**：启动报错 "无法定位程序输入点 SteamAPI_SteamApps_v009"

**原因**：Godot 编辑器自带的 `steam_api64.dll` 版本过旧（SDK 1.58），GDExtension 需要 v009 导出（SDK 1.64+）

**修复**：用 `addons/godotsteam/win64/steam_api64.dll` 覆盖编辑器目录下的同名文件。

### 2. class_name 与 autoload 冲突

**症状**：编辑器报错或 autoload 不生效

**原因**：autoload 注册名 `SteamMgr` 与脚本中 `class_name SteamMgr` 产生全局名称冲突

**修复**：**删除** autoload 脚本中的 `class_name` 声明。autoload 本身就是全局单例，不需要 class_name。

### 3. GDExtension C++ 类不能作为类型注解

**症状**：`var multiplayer_peer: SteamMultiplayerPeer` 报类型错误

**原因**：`SteamMultiplayerPeer` 是 GDExtension 导出的 C++ 类，GDScript 编译期无法识别

**修复**：改为 `var multiplayer_peer: RefCounted`

### 4. 遍历未类型化 Array 不能用类型注解

**症状**：`for m: Dictionary in members` 编译失败

**原因**：`members` 声明为 `Array`（无泛型），GDScript 不允许在 for 循环中加 `: Dictionary`

**修复**：改为 `for m in members`，访问时用 `m.get("key", default)` 或 `m.key`

### 5. steamInitEx 返回值不一致

**症状**：`Steam.steamInitEx(480, false)` 在不同版本返回 `{}`（Dict）或整数

**修复**：改用 `Steam.steamInit()` 不传参数，返回 `bool`，跨版本一致。配合 `project.godot` 中的 `[steam]` 配置提供 App ID。

### 6. createLobby 双重信号

**症状**：创建大厅时 `lobby_created` 和 `lobby_joined` 都被触发，导致重复处理

**原因**：`Steam.createLobby()` 成功后 Steam 同时触发两个信号

**修复**：用 `_is_creating` 标记 — `create_lobby()` 中设 true，`_on_lobby_joined` 中检查后跳过

### 7. 编辑器 DLL 与打包后 DLL 路径不同

编辑器运行时从 Godot 编辑器目录加载 `steam_api64.dll`，导出后的 exe 从 exe 所在目录加载。

---

## 验证清单

完成后按顺序验证：

1. [ ] 启动 Godot 编辑器，无 Steam 相关报错
2. [ ] 启动 Steam 客户端（必须登录）
3. [ ] F5 运行游戏，控制台输出 `[SteamMgr] steamInit() = true`
4. [ ] 控制台显示用户 Steam 昵称和 ID
5. [ ] 主菜单多人按钮可点击（非灰色）
6. [ ] 点击多人 → 进入大厅，显示 "大厅已创建"
7. [ ] 成员列表显示自己的名字（带 ★ 标记）
8. [ ] 另一台电脑加入同一大厅 → 双方都能看到对方
9. [ ] 邀请好友按钮打开 Steam Overlay（Shift+Tab）
10. [ ] 离开大厅 → 返回主菜单，无报错

---

## 项目结构调整

集成后你的项目应包含：

```
project/
├── steam_appid.txt
├── project.godot          # [steam] 段 + autoload
├── addons/godotsteam/     # GDExtension 插件
├── scripts/autoload/
│   ├── steam_manager.gd   # SteamMgr
│   └── lobby_manager.gd   # LobbyMgr
├── scripts/lobby/
│   └── lobby_ui.gd
├── scripts/main_menu/
│   └── main_menu_ui.gd    # 多人入口
└── scenes/lobby/
    └── lobby.tscn
```

## 下一步

本 skill 覆盖大厅阶段（Steam 连接 + 大厅成员管理）。游戏内的网络同步（MultiplayerSpawner、MultiplayerSynchronizer、RPC）需要在后续阶段实现。激活网络同步的关键步骤是在 `start_game()` 中将 `multiplayer_peer` 赋给场景树：

```gdscript
# 阶段 4 需要添加（目前 start_game() 仅切换场景）
func start_game() -> void:
	# 设置 multiplayer_peer 激活 P2P 网络
	get_tree().set_multiplayer_peer(multiplayer_peer)
	# 然后切换场景
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")
```
