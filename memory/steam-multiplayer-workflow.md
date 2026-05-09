# Godot 4 项目 Steam 多人集成通用流程

> 提炼自 TheGameDemo 阶段 3，可直接用于任何 Godot 4.4+ 项目。

## 前置条件

1. Godot 4.4+ 编辑器
2. Steam 客户端（开发阶段需安装并登录）
3. Steamworks App ID（开发阶段可用 480 SpaceWar 测试 ID）

## 第 1 步：安装 GodotSteam GDExtension

### 下载
- 最新版本见 [Codeberg Releases](https://codeberg.org/godotsteam/GodotSteam/releases)
- 选择带 `gde` 标签的版本（如 `v4.18.1-gde`）
- 下载名为 `godotsteam-X.X.X-gdextension-plugin-4.4.zip` 的文件

### 安装
```bash
# 解压到项目根目录
unzip godotsteam-gde.zip -d your_project/
```
- 解压后在 `your_project/addons/godotsteam/` 下
- 包含 GDExtension 库文件（.dll/.so/.dylib）+ Steam API 库
- **无需**在 Godot 编辑器中启用插件（只需重启编辑器）

### 创建 steam_appid.txt
```
# 项目根目录（与 project.godot 同级）
echo "480" > your_project/steam_appid.txt
```

## 第 2 步：创建 SteamMgr 自动加载

```gdscript
# scripts/autoload/steam_manager.gd
class_name SteamMgr
extends Node

var steam_enabled: bool = false

func _ready() -> void:
    var result: Dictionary = Steam.steamInitEx(480, false)
    if result.get("status", 0) != 1:
        push_warning("[SteamMgr] Steam 初始化失败")
        return
    Steam.initRelayNetworkAccess()
    steam_enabled = true
    print("[SteamMgr] Steam 初始化成功 — 用户: %s" % Steam.getFriendPersonaName(Steam.getSteamID()))

func _process(_delta: float) -> void:
    if steam_enabled:
        Steam.run_callbacks()
```

**关键点：**
- `steamInitEx` 返回 `{status: int, verbal: String}`，status=1 为成功
- `initRelayNetworkAccess()` 启用 P2P 中继，大厅通信必需
- `run_callbacks()` 必须每帧在主线程调用
- 初始化失败设 `steam_enabled = false`，多人功能降级但不影响单人模式

## 第 3 步：创建 LobbyMgr 自动加载

```gdscript
# scripts/autoload/lobby_manager.gd
class_name LobbyMgr
extends Node

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_left()
signal member_joined(steam_id: int, player_name: String)
signal member_left(steam_id: int, player_name: String)
signal members_refreshed()
signal error_occurred(message: String)

var lobby_id: int = 0
var is_host: bool = false
var members: Array = []           # [{steam_id: int, name: String}]
var multiplayer_peer: SteamMultiplayerPeer
var _is_creating: bool = false   # 防止 createLobby 双重信号

func is_steam_available() -> bool:
    return SteamMgr.steam_enabled

func create_lobby() -> void:
    if not SteamMgr.steam_enabled: return
    _is_creating = true
    Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)

func join_lobby(id: int) -> void:
    if not SteamMgr.steam_enabled: return
    Steam.joinLobby(id)

func leave_lobby() -> void:
    if multiplayer_peer:
        multiplayer_peer.close()
        multiplayer_peer = null
    if lobby_id != 0:
        Steam.leaveLobby(lobby_id)
    lobby_id = 0; is_host = false; members.clear()
    lobby_left.emit()

func _ready() -> void:
    Steam.lobby_created.connect(_on_lobby_created)
    Steam.lobby_joined.connect(_on_lobby_joined)
    Steam.lobby_chat_update.connect(_on_lobby_chat_update)

func _on_lobby_created(connect: int, created_id: int) -> void:
    if connect != 1: return
    lobby_id = created_id; is_host = true
    Steam.setLobbyJoinable(lobby_id, true)
    Steam.setLobbyData(lobby_id, "name", "游戏房间")
    Steam.allowP2PPacketRelay(true)
    multiplayer_peer = SteamMultiplayerPeer.new()
    multiplayer_peer.host_with_lobby(lobby_id)
    _add_self_to_members()
    lobby_created.emit(lobby_id)

func _on_lobby_joined(id: int, _p: int, _l: bool, resp: int) -> void:
    if _is_creating:           # 房主跳过（自己创建自己加入）
        _is_creating = false; return
    if resp != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
        return
    lobby_id = id; is_host = false
    multiplayer_peer = SteamMultiplayerPeer.new()
    multiplayer_peer.connect_to_lobby(lobby_id)
    _refresh_members()
    lobby_joined.emit(lobby_id)

func _on_lobby_chat_update(_lid, _uid, _mid, _st) -> void:
    if lobby_id != 0: _refresh_members()

func _refresh_members() -> void:
    # 对比新旧成员，发送 member_joined / member_left 信号
    var old := members.duplicate()
    members.clear()
    for i in Steam.getNumLobbyMembers(lobby_id):
        var sid := Steam.getLobbyMemberByIndex(lobby_id, i)
        members.append({"steam_id": sid, "name": Steam.getFriendPersonaName(sid)})
    # 检测增减（细节省略，参考完整实现）
    members_refreshed.emit()
```

**关键陷阱：**
1. **createLobby 双重信号** — `Steam.createLobby()` 同时触发 `lobby_created` 和 `lobby_joined`，需用 `_is_creating` 标记区分
2. **SteamMultiplayerPeer** — 房主调 `host_with_lobby()`，客户端调 `connect_to_lobby()`
3. **成员管理** — 通过 `lobby_chat_update` 信号检测变化，每次全量刷新
4. **Steam 不可用降级** — 所有公开方法开头检查 `SteamMgr.steam_enabled`

## 第 4 步：创建大厅 UI

```gdscript
# scripts/lobby/lobby_ui.gd
class_name LobbyUI
extends Control

func _ready() -> void:
    LobbyMgr.lobby_created.connect(_on_lobby_created)
    LobbyMgr.lobby_joined.connect(_on_lobby_joined)
    LobbyMgr.members_refreshed.connect(_refresh_member_list)
    # ... 其他信号
    start_game_btn.hide()
    status_label.text = "正在创建大厅..."

func _on_lobby_created(lobby_id: int) -> void:
    start_game_btn.show()  # 房主可见
    status_label.text = "大厅已创建"
    _refresh_member_list()

func _on_lobby_joined(_id: int) -> void:
    start_game_btn.hide()
    status_label.text = "已加入大厅"
    _refresh_member_list()

func _refresh_member_list() -> void:
    # 清空 member_container
    for child in member_container.get_children():
        child.queue_free()
    # 遍历 LobbyMgr.members 添加 Label
    for m in LobbyMgr.members:
        var label := Label.new()
        label.text = "★ %s" % m.name if m.steam_id == Steam.getSteamID() else m.name
        member_container.add_child(label)

func _on_start_game_pressed() -> void:
    LobbyMgr.start_game()  # → get_tree().change_scene(...)

func _on_leave_pressed() -> void:
    LobbyMgr.leave_lobby()
    get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_invite_pressed() -> void:
    Steam.activateGameOverlayInviteDialog(LobbyMgr.lobby_id)
```

## 第 5 步：连接主菜单

```gdscript
func _on_multiplayer_pressed() -> void:
    if not LobbyMgr.is_steam_available():
        _show_steam_unavailable_dialog()
        return
    LobbyMgr.create_lobby()
    get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
```

## 第 6 步：注册 autoload

```ini
# project.godot
[autoload]
SteamMgr="*res://scripts/autoload/steam_manager.gd"   # 先于 LobbyMgr
LobbyMgr="*res://scripts/autoload/lobby_manager.gd"   # 先于任何场景
```

**顺序至关重要**：`SteamMgr` → `LobbyMgr` → 场景

## 完整调用流程

```
游戏启动
  → SteamMgr._ready(): steamInitEx → initRelayNetworkAccess
  → SteamMgr._process(): run_callbacks (每帧)
主菜单 [多人游戏]
  → 检查 LobbyMgr.is_steam_available()
  → LobbyMgr.create_lobby() → change_scene(lobby.tscn)
大厅 LobbyUI._ready()
  → 连接 LobbyMgr 信号
  → 等待 Steam 回调:
      房主: lobby_created → host_with_lobby → 加自己到成员
      客户端: lobby_joined → connect_to_lobby → 刷新成员
成员变更: lobby_chat_update → 刷新成员列表 → 通知 UI
房主点击 [开始游戏] → LobbyMgr.start_game() → game_world.tscn
离开: LobbyMgr.leave_lobby() → main_menu.tscn
```

## 导出注意事项

1. 发布到 Steam 时**不要包含** `steam_appid.txt`
2. 使用普通 Godot 导出模板，不是 GodotSteam 专用模板
3. 确保导出设置中包含 `.gdextension` 文件和对应平台的 `.dll/.so/.dylib`

## 测试方法

1. 启动 Steam 客户端并登录
2. 在 Godot 编辑器中 F5 运行
3. 查看控制台：应输出 `[SteamMgr] Steam 初始化成功`
4. 点击多人游戏 → 大厅 UI 显示成员列表
5. 通过 Steam Overlay 邀请好友测试（`activateGameOverlayInviteDialog`）
