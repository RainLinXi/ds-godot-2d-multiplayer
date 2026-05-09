# Godot AI 中文使用文档

## 项目概述

**Godot AI** 是一个面向 Godot 引擎的生产级 MCP（Model Context Protocol，模型上下文协议）服务器与 AI 工具集。它通过 MCP 协议让 AI 助手（如 Claude Code、Codex、Cursor、Antigravity 等）直接连接到运行中的 Godot 编辑器，实现对场景、节点、脚本、信号、UI、材质、动画、粒子、摄像机和环境的全面操控。

- GitHub: https://github.com/hi-godot/godot-ai
- 许可证: MIT
- 语言: GDScript (60.7%) / Python (36.3%) / Shell (2.5%)
- Godot 版本要求: 4.3+（推荐 4.4+）
- 最新版本: v2.4.2（2026-05-07）
- 工具总量: ~39 个 MCP 工具，超过 120 个操作

---

## 架构原理

```
MCP 客户端（Claude Code / Codex / Cursor 等）
   | HTTP 请求 (/mcp)
   v
Python MCP 服务器 (FastMCP)     端口 8000
   | WebSocket 通信             端口 9500
   v
Godot 编辑器插件
   | EditorInterface + SceneTree API
   v
Godot 编辑器
```

工作流程：
1. Godot 插件启动（或复用已有的）Python MCP 服务器
2. Python 服务器通过 WebSocket 连接到 Godot 编辑器
3. AI 客户端通过 HTTP 向 Python 服务器发送 MCP 请求
4. Python 服务器将请求转发给 Godot 插件，调用编辑器 API 执行操作
5. 结果沿原路返回给 AI 客户端

---

## 快速开始

### 前置依赖

| 依赖 | 说明 |
|------|------|
| **Godot 4.3+** | 推荐 4.4+ |
| **uv** | Python 包管理器（用于运行 MCP 服务器） |
| **MCP 客户端** | Claude Code / Codex / Antigravity / Cursor 等 |

**安装 uv：**

macOS / Linux:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Windows (PowerShell):
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### 第一步：安装插件

**方式一：从源码安装（推荐，总是最新版）**

```bash
git clone https://github.com/hi-godot/godot-ai.git
cp -r godot-ai/plugin/addons/godot_ai your-project/addons/
```

**方式二：下载 Release ZIP**

从 [最新 Release 页面](https://github.com/hi-godot/godot-ai/releases/latest) 下载 ZIP，将 `addons/godot_ai` 解压到你项目的 `addons/` 目录。

**方式三：通过 Godot Asset Library**

在 Godot 编辑器中，打开 **AssetLib** 标签页，搜索 **Godot AI**，点击 **Download**，然后 **Install**。

> 注意：Asset Library 版本可能滞后于 GitHub 最新版。

> 如果从 Asset Library 安装后遇到问题，在 **项目 > 项目设置 > 插件** 中禁用再重新启用插件通常可以解决。

### 第二步：启用插件

在 Godot 编辑器中：**项目 > 项目设置 > 插件** — 启用 **Godot AI**。

插件将自动启动 MCP 服务器，通过 WebSocket 连接，并在 **Godot AI** 停靠面板中显示状态。

### 第三步：连接 MCP 客户端

Godot AI 停靠面板会列出所有支持的客户端，每个客户端都有状态指示灯和 **Configure** / **Remove** 按钮。

**服务器地址统一为：** `http://127.0.0.1:8000/mcp`

#### 支持的客户端列表

| AI 客户端 | 自动配置 |
|-----------|---------|
| Claude Code | 支持 |
| Claude Desktop | 支持 |
| Antigravity | 支持 |
| Codex | 支持 |
| Cursor | 支持 |
| Windsurf | 支持 |
| VS Code | 支持 |
| VS Code Insiders | 支持 |
| Zed | 支持 |
| Gemini CLI | 支持 |
| Cline | 支持 |
| Kilo Code | 支持 |
| Roo Code | 支持 |
| Kiro | 支持 |
| Trae | 支持 |
| Cherry Studio | 支持 |
| OpenCode | 支持 |
| Qwen Code（通义灵码） | 支持 |
| Kimi Code | 支持 |

#### 手动配置方法

**Claude Code：**

```bash
claude mcp add --scope user --transport http godot-ai http://127.0.0.1:8000/mcp
```

**Codex**（编辑 `~/.codex/config.toml`）：

```toml
[mcp_servers."godot-ai"]
url = "http://127.0.0.1:8000/mcp"
enabled = true
```

**Antigravity**（编辑 `~/.gemini/antigravity/mcp_config.json`）：

```json
{
  "mcpServers": {
    "godot-ai": {
      "serverUrl": "http://127.0.0.1:8000/mcp",
      "disabled": false
    }
  }
}
```

### 第四步：开始使用

以下是几个典型的对话示例：

- "显示当前场景层级结构"（Show me the current scene hierarchy）
- "在 /Main 下创建一个名为 MainCamera 的 Camera3D 节点"
- "搜索项目中 ui/ 目录下的 PackedScene 文件"
- "运行场景测试套件"
- "构建一个体素方块世界游戏，包含玩家、可放置和破坏的方块，以及存档槽位"

---

## 完整工具参考

Godot AI 暴露了约 **39 个 MCP 工具**，涵盖超过 **120 个操作**。工具采用了特殊的分组设计：

- **顶层具名工具**：高频使用的核心操作（如 `node_create`、`scene_open`、`script_create` 等），约 18 个
- **域聚合工具**（`_manage` 后缀）：每个域一个工具，通过 `op` 参数分发具体操作。如 `scene_manage`、`node_manage`、`material_manage` 等

调用聚合工具的格式：
```json
{
  "op": "set_color",
  "params": {
    "theme_path": "res://theme.tres",
    "class_name": "Label",
    "name": "font_color",
    "value": "#ff0000"
  }
}
```

### 核心工具

| 工具名 | 功能描述 |
|--------|---------|
| `editor_state` | 获取编辑器版本、项目名、当前场景、就绪状态、播放状态 |
| `scene_get_hierarchy` | 分页遍历场景树（支持 depth、offset、limit） |
| `node_get_properties` | 获取节点的完整属性快照 |
| `session_activate` | 将后续调用固定到指定的已连接编辑器 |

### 顶层操作工具（高频读写）

| 工具名 | 功能描述 |
|--------|---------|
| `batch_execute` | 原子批量执行多个插件命令（首错回滚） |
| `node_create` | 创建新节点 |
| `node_set_property` | 设置节点属性 |
| `node_find` | 搜索节点 |
| `scene_open` | 打开场景 |
| `scene_save` | 保存场景 |
| `script_create` | 创建 GDScript 脚本文件 |
| `script_attach` | 将脚本附加到节点 |
| `script_patch` | 锚点编辑 GDScript 文件 |
| `project_run` | 运行项目（默认 autosave=True，持久化 MCP 编辑） |
| `test_run` | 在编辑器中运行 GDScript 测试套件 |
| `logs_read` | 读取插件/游戏/编辑器/合并日志缓冲区 |
| `editor_screenshot` | 截取编辑器视口、电影级摄像机或运行中的游戏帧缓冲 |
| `editor_reload_plugin` | 重载插件并等待重连（服务器需为外部启动） |
| `animation_create` | 创建动画剪辑（自动创建 AnimationPlayer + 动画库） |

### 场景管理 `scene_manage`

| op 值 | 功能 |
|-------|------|
| `create` | 创建新场景 |
| `save_as` | 另存为场景 |
| `get_roots` | 获取根节点列表 |

### 节点管理 `node_manage`

| op 值 | 功能 |
|-------|------|
| `get_children` | 获取子节点 |
| `get_groups` | 获取组信息 |
| `delete` | 删除节点 |
| `duplicate` | 复制节点 |
| `rename` | 重命名节点 |
| `move` | 移动节点 |
| `reparent` | 重新设置父节点 |
| `add_to_group` | 添加到组 |
| `remove_from_group` | 从组中移除 |

### 脚本管理 `script_manage`

| op 值 | 功能 |
|-------|------|
| `read` | 读取脚本源码 |
| `detach` | 从节点上分离脚本 |
| `find_symbols` | 查找符号（函数、变量等） |

### 项目管理 `project_manage`

| op 值 | 功能 |
|-------|------|
| `stop` | 停止运行中的项目 |
| `settings_get` | 获取项目设置 |
| `settings_set` | 设置项目配置 |

### 编辑器管理 `editor_manage`

| op 值 | 功能 |
|-------|------|
| `state` | 获取编辑器状态 |
| `selection_get` | 获取当前选中节点 |
| `selection_set` | 设置选中节点 |
| `monitors_get` | 获取性能监视器数据 |
| `quit` | 退出编辑器 |
| `logs_clear` | 清除日志缓冲区 |

### 会话管理 `session_manage`

| op 值 | 功能 |
|-------|------|
| `list` | 列出所有已连接编辑器会话 |

### 测试管理 `test_manage`

| op 值 | 功能 |
|-------|------|
| `results_get` | 获取最近一次 test_run 的结果 |

### 动画管理 `animation_manage`

| op 值 | 功能 |
|-------|------|
| `player_create` | 创建 AnimationPlayer |
| `delete` | 删除动画 |
| `validate` | 校验动画数据 |
| `add_property_track` | 添加属性轨道 |
| `add_method_track` | 添加方法调用轨道 |
| `set_autoplay` | 设置自动播放 |
| `play` | 播放动画 |
| `stop` | 停止动画 |
| `list` | 列出所有动画 |
| `get` | 获取动画详情 |
| `create_simple` | 快速创建简单动画 |
| `preset_fade` | 预设渐隐动画 |
| `preset_slide` | 预设滑动动画 |
| `preset_shake` | 预设震动动画 |
| `preset_pulse` | 预设脉冲动画 |

### 材质管理 `material_manage`

| op 值 | 功能 |
|-------|------|
| `create` | 创建材质 |
| `set_param` | 设置材质参数 |
| `set_shader_param` | 设置着色器参数 |
| `get` | 获取材质详情 |
| `list` | 列出所有材质 |
| `assign` | 分配材质到节点 |
| `apply_to_node` | 将材质应用到节点 |
| `apply_preset` | 应用预设材质 |

### 音频管理 `audio_manage`

| op 值 | 功能 |
|-------|------|
| `player_create` | 创建 AudioStreamPlayer |
| `player_set_stream` | 设置音频流 |
| `player_set_playback` | 设置播放参数 |
| `play` | 播放音频 |
| `stop` | 停止音频 |
| `list` | 列出所有音频播放器 |

### 粒子管理 `particle_manage`

| op 值 | 功能 |
|-------|------|
| `create` | 创建粒子系统 |
| `set_main` | 设置主参数 |
| `set_process` | 设置处理参数 |
| `set_draw_pass` | 设置绘制通道 |
| `restart` | 重启粒子 |
| `get` | 获取粒子系统详情 |
| `apply_preset` | 应用预设粒子效果 |

### 摄像机管理 `camera_manage`

| op 值 | 功能 |
|-------|------|
| `create` | 创建摄像机 |
| `configure` | 配置摄像机参数 |
| `set_limits_2d` | 设置 2D 摄像机限制 |
| `set_damping_2d` | 设置 2D 摄像机阻尼 |
| `follow_2d` | 设置 2D 跟随目标 |
| `get` | 获取摄像机详情 |
| `list` | 列出所有摄像机 |
| `apply_preset` | 应用预设摄像机配置 |

### 信号管理 `signal_manage`

| op 值 | 功能 |
|-------|------|
| `list` | 列出信号 |
| `connect` | 连接信号 |
| `disconnect` | 断开信号连接 |

### 输入映射管理 `input_map_manage`

| op 值 | 功能 |
|-------|------|
| `list` | 列出输入映射 |
| `add_action` | 添加输入动作 |
| `remove_action` | 移除输入动作 |
| `bind_event` | 绑定输入事件 |

### 自动加载管理 `autoload_manage`

| op 值 | 功能 |
|-------|------|
| `list` | 列出自动加载的单例 |
| `add` | 添加自动加载 |
| `remove` | 移除自动加载 |

### 文件系统管理 `filesystem_manage`

| op 值 | 功能 |
|-------|------|
| `read_text` | 读取文本文件 |
| `write_text` | 写入文本文件 |
| `reimport` | 重新导入资源 |
| `search` | 搜索文件 |

### 主题管理 `theme_manage`

| op 值 | 功能 |
|-------|------|
| `create` | 创建主题 |
| `set_color` | 设置颜色 |
| `set_constant` | 设置常量 |
| `set_font_size` | 设置字体大小 |
| `set_stylebox_flat` | 设置平面样式盒 |
| `apply` | 应用主题 |

### UI 管理 `ui_manage`

| op 值 | 功能 |
|-------|------|
| `set_anchor_preset` | 设置锚点预设 |
| `set_text` | 设置文本内容 |
| `build_layout` | 构建布局 |
| `draw_recipe` | 程序化绘制 UI |

### 资源管理 `resource_manage`

| op 值 | 功能 |
|-------|------|
| `search` | 搜索资源 |
| `load` | 加载资源 |
| `assign` | 分配资源 |
| `get_info` | 获取资源信息 |
| `create` | 创建新资源 |
| `curve_set_points` | 设置曲线点 |
| `environment_create` | 创建环境资源 |
| `physics_shape_autofit` | 自动适配物理形状 |
| `gradient_texture_create` | 创建渐变纹理 |
| `noise_texture_create` | 创建噪声纹理 |

### 客户端管理 `client_manage`

| op 值 | 功能 |
|-------|------|
| `status` | 获取客户端连接状态 |
| `configure` | 配置客户端 |
| `remove` | 移除客户端配置 |

---

## MCP 资源（Resources）

MCP 资源是只读的 URI 端点，不占用工具配额，适合读取活跃会话状态：

| 资源 URI | 描述 |
|----------|------|
| `godot://sessions` | 所有已连接编辑器会话及元数据 |
| `godot://editor/state` | 编辑器版本、项目、当前场景、就绪状态、播放状态 |
| `godot://selection/current` | 当前编辑器选中内容 |
| `godot://logs/recent` | 最近 100 条插件日志 |
| `godot://scene/current` | 活动场景路径 + 项目 + 播放状态 |
| `godot://scene/hierarchy` | 当前编辑器的完整场景层级 |
| `godot://node/{path}/properties` | 按场景路径获取节点的所有属性 |
| `godot://node/{path}/children` | 节点的直接子节点（名称、类型、路径） |
| `godot://node/{path}/groups` | 节点的组成员信息 |
| `godot://script/{path}` | 按 res:// 路径读取 GDScript 源码（省略 `res://` 前缀） |
| `godot://project/info` | 活跃项目元数据 |
| `godot://project/settings` | 常用项目设置子集 |
| `godot://materials` | res:// 下所有 Material 资源 |
| `godot://input_map` | 项目输入动作及其绑定事件 |
| `godot://performance` | Performance 单例快照 |
| `godot://test/results` | 最近一次 test_run 结果 |

---

## 技巧与最佳实践

### 1. 批量执行

使用 `batch_execute` 一次性提交多个命令，保证原子性（任一命令失败则全部回滚）：

```json
{
  "commands": [
    {"command": "create_node", "params": {...}},
    {"command": "set_property", "params": {...}},
    {"command": "script_attach", "params": {...}}
  ]
}
```

> 注意：`batch_execute` 的 `commands[].command` 字段应使用底层插件命令名（如 `create_node`、`set_property`），而不是 MCP 工具名。

### 2. 多编辑器路由

如果你的 MCP 客户端同时连接了多个 Godot 编辑器，可以使用 `session_activate` 工具将后续调用固定到特定编辑器，或者在每个聚合工具调用中传递可选的顶级 `session_id` 参数。

### 3. 运行项目与自动保存

`project_run` 默认会执行 `autosave=True`，将 MCP 所做的内存编辑持久化到磁盘。如果不想保存，传入 `autosave=False`。

### 4. 调试脚本错误

当编辑器的 Output 面板显示红线但 `logs_read` 返回内容为空时，尝试 `logs_read` 设置 `source="editor"`，它会显示解析错误、@tool/EditorPlugin 运行时错误以及 push_error/push_warning（Godot 4.5+）。

### 5. 截屏能力

`editor_screenshot` 可以截取三种画面：
- 编辑器视口
- 电影级摄像机画面
- 运行中游戏的帧缓冲

### 6. 使用资源（Resources）代替工具调用

MCP 资源不占用工具配额，适合频繁读取数据。如果你的客户端支持资源 URI，优先使用资源来获取场景层级、节点属性、项目设置等信息。

---

## Windows 平台注意事项

### uvx mcp-proxy 启动失败问题

**现象**（MCP 客户端服务器日志中）：

```
error: Failed to install: pywin32-311-cp313-cp313-win_amd64.whl (pywin32==311)
  Caused by: failed to remove directory `...\builds-v0\.tmpXXXXXX\...`: os error 32
```

**原因**：uv 使用硬链接共享 `.pyd` 文件，运行中的 Python 进程锁定了这些文件，导致 Windows 拒绝删除。

**解决方案**：

1. 插件已在 `_stop_server` 和 `force_restart_server` 中自动清理过期构建缓存
2. **自动配置功能会为所有 uvx-bridge 客户端写入 `UV_LINK_MODE=copy`** 环境变量，告诉 uv 复制而非硬链接 C 扩展
3. 如果已遇到此问题，在 Godot AI 面板中点击对应 uvx-bridge 客户端（Claude Desktop 或 Zed）的 **Configure** 按钮重写配置，然后退出并重新打开客户端
4. 如果问题仍然存在（罕见），手动终止命令行中含 `spawn_main(parent_pid=...)` 的残留 `python.exe` 进程，并删除 `%LOCALAPPDATA%\uv\cache\builds-v0\.tmp*` 目录

---

## 开发与贡献

### 开发环境搭建

**macOS / Linux：**

```bash
git clone https://github.com/hi-godot/godot-ai.git
cd godot-ai
script/setup-dev             # 创建 .venv、安装依赖、构建插件符号链接、安装 git hooks
source .venv/bin/activate
```

**Windows (PowerShell)：**

```powershell
git clone https://github.com/hi-godot/godot-ai.git
cd godot-ai
.\script\setup-dev.ps1       # 创建 .venv、安装依赖、构建插件目录连接、安装 git hooks
.venv\Scripts\Activate.ps1
```

### 测试

Python 测试：
```bash
pytest -v                    # 单元 + 集成测试
ruff check src/ tests/       # 代码检查
ruff format src/ tests/      # 代码格式化
```

Godot 端测试（通过 MCP）：
```
test_run                     # 运行全部测试套件
test_run suite=scene         # 运行指定测试套件
test_results_get             # 查看最近的结果
```

### 开发服务器（自动重载）

修改 Python 代码无需重启 Godot：

```bash
python -m godot_ai --transport streamable-http --port 8000 --reload
```

Godot AI 停靠面板在开发检出模式下也有 **Start/Stop Dev Server** 按钮。

### PR 工作流

```bash
git checkout -b feature/my-feature
pytest -v && ruff check src/ tests/
git push -u origin feature/my-feature
gh pr create
```

---

## 常见问题（FAQ）

**Q: 插件安装后不工作？**
A: 尝试在 **项目 > 项目设置 > 插件** 中禁用再重新启用 Godot AI 插件。

**Q: 如何更新到最新版？**
A: 推荐从 GitHub 拉取最新源码，重新复制 `addons/godot_ai` 目录到你的项目中。也可以在 Godot AI 面板中点击 Update 按钮（如果支持）。

**Q: 支持多个编辑器同时连接吗？**
A: 支持。使用 `session_activate` 或 `session_id` 参数在多个编辑器实例之间切换。

**Q: 可以不使用 uv 吗？**
A: 目前 Python MCP 服务器依赖 uv 来管理依赖和运行环境。

**Q: Godot 版本要求？**
A: 最低 4.3，推荐 4.4+。

**Q: 支持 GDScript 以外的脚本语言吗？**
A: 目前工具主要面向 GDScript（`script_create`、`script_patch` 等），但你可以通过 `filesystem_manage` 读写任意文件。

---

## 相关链接

| 资源 | 链接 |
|------|------|
| GitHub 仓库 | https://github.com/hi-godot/godot-ai |
| Godot Asset Library | https://godotengine.org/asset-library/asset/5050 |
| Godot Asset Store | https://store.godotengine.org/asset/dlight/godot-ai/ |
| Discord 社区 | https://discord.gg/FDZ5fr2QkP |
| MCP 协议文档 | https://modelcontextprotocol.io/introduction |
| 工具完整列表 | https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md |
| 贡献指南 | https://github.com/hi-godot/godot-ai/blob/main/docs/CONTRIBUTING.md |
