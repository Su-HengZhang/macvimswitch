# MacVimSwitch

> 这个项目的核心代码基于 [macism](https://github.com/laishulu/macism) 实现

[中文说明](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [한국어](README_KO.md)

MacVimSwitch 是一个 macOS 菜单栏工具，专为 Vim 用户和经常在中文/英文输入法间切换的用户设计。

## 功能特点

- **一键切换**: 按 `ESC` 或 `Ctrl+[` 键自动切换到选定的英文输入法（仅在指定应用中生效）
- **Shift 切换**: 按 `Shift` 键快速切换中英文输入法
- **自由选择**: 可在菜单栏中选择偏好的英文输入法和中文输入法
- **应用配置**: 可设置 ESC 切换功能生效的应用列表
- **开机启动**: 支持开机自动启动

## 键盘快捷键

| 按键 | 功能 |
|-----|------|
| `ESC` | 切换到英文输入法 |
| `Ctrl + [` | 与 ESC 等价（Vim 兼容） |
| `Shift` | 切换中英文输入法 |

## 支持的应用

Terminal、VSCode、MacVim、Windsurf、Obsidian、Warp、Cursor 等任何需要 Vim 模式的应用。

## 安装方法

### Homebrew

```bash
brew tap Jackiexiao/tap
brew install --cask macvimswitch
```

### 手动安装

从 [GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases) 下载 `MacVimSwitch.dmg`。

## 使用方法

1. **首次启动**:
   - 打开 MacVimSwitch
   - 根据提示授予辅助功能权限
   - 打开系统设置 → 隐私与安全性 → 辅助功能
   - 添加并启用 MacVimSwitch

2. **首次配置**:
   - 关闭输入法中的"使用 Shift 切换中英文"选项
   - 在菜单栏图标中选择您偏好的中英文输入法

3. **菜单栏选项**:
   - 使用说明 - 查看使用说明对话框
   - 选择中文输入法
   - 选择英文输入法
   - Esc 生效的应用（可多选）
   - 使用 Shift 切换输入法（开关）
   - 开机启动（开关）
   - 退出

## 常见问题

### 更新后需要重新授权辅助功能

由于应用使用自签名证书，每次构建的签名标识不同，macOS 会将其识别为新应用。

**解决方法**:
1. 打开系统设置 → 隐私与安全性 → 辅助功能
2. 删除旧的 MacVimSwitch 条目
3. 添加新的 MacVimSwitch
4. 确保开关已打开

## 技术架构

```
MacVimSwitch/
├── main.swift              # 应用入口点
├── AppDelegate.swift       # 应用生命周期管理
├── StatusBarManager.swift  # 菜单栏 UI 管理
├── inputsource.swift       # 输入法切换核心逻辑
│   ├── InputSource         # 输入法封装
│   ├── InputSourceManager  # 输入法管理
│   └── KeyboardManager     # 键盘事件监听
├── InputMethodManager.swift # 输入法发现与分类
├── UserPreferences.swift   # 用户偏好设置
└── LaunchManager.swift     # 开机启动管理
```

### 核心技术

- **Carbon TIS API**: 获取和切换输入法
- **CGEvent API**: 监听全局键盘事件
- **Accessibility**: 键盘事件捕获
- **Swift 直接编译**: 无外部依赖，创建通用二进制

### 系统要求

- macOS 11.0+
- Apple Silicon 或 Intel Mac

## 开发

### 本地构建

```bash
./build.sh                    # 构建应用
./build.sh --create-dmg       # 构建并创建 DMG
```

### 测试

```bash
pkill -f MacVimSwitch
./dist/MacVimSwitch.app/Contents/MacOS/MacVimSwitch
```

### 权限重置（测试用）

```bash
tccutil reset All com.jackiexiao.macvimswitch
```

## 致谢

- [macism](https://github.com/laishulu/macism) - 输入法切换底层实现

## 许可证

MIT License
