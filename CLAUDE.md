# CLAUDE.md

## 项目概况

- **项目名**: TheGameDemo — 一个 Godot 4.6 2D 多人游戏
- **引擎**: Godot 4.6 (Forward Plus 渲染器, D3D12)
- **物理引擎**: Jolt Physics
- **语言**: GDScript
- **AI 工具**: godot-ai MCP 插件 (v2.4.2)，可让 AI 直接操控 Godot 编辑器

## 偏好设置

- **回复语言**: 始终用中文
- **提交方式**: 每完成一个功能自动 git commit
- **操作权限**: 适度自主 — 读文件/搜索无需确认，但删除、安装依赖、提交等需要确认
- **代码风格**: 关键逻辑需要加上注释说明

## 常用命令

- 打开项目: 通过桌面快捷方式启动 Godot，手动选择项目
- 运行游戏: 在 Godot 编辑器中点击"运行"按钮（F5）
- 运行测试: 暂无

## 项目结构

```
.
├── CLAUDE.md              # 本文件，AI 使用说明书
├── the-game-demo/          # Godot 项目主目录
│   ├── project.godot       # Godot 引擎配置
│   ├── addons/
│   │   └── godot_ai/       # godot-ai MCP 插件
│   ├── icon.svg            # 项目图标
│   └── ...
└── godot-ai-使用文档.md    # godot-ai 插件使用说明
```

## 注意事项

- 项目使用 godot-ai 插件连接 AI 与 Godot 编辑器，修改场景/节点时可通过 MCP 直接操作
- 这是一个多人游戏项目，网络相关逻辑需要特别注意同步问题
