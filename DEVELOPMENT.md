# MacVimSwitch 开发文档

## 项目概述

MacVimSwitch 是一个 macOS 菜单栏应用程序，专为 Vim 用户和频繁切换中英文输入法的用户设计。

### 核心功能

1. **ESC 键切换英文**：在指定应用中按 ESC 键自动切换到英文输入法
2. **Shift 键切换**：短按 Shift 键（< 0.5秒）在中英文输入法之间切换
3. **菜单栏控制**：通过菜单栏图标选择输入法、配置应用列表、设置开关
4. **开机启动**：可选开机自动启动

### 系统要求

- macOS 11.0 (Big Sur) 或更高版本
- 辅助功能权限（用于监听键盘事件）

---

## 架构设计

### 设计模式

| 模式 | 应用场景 |
|------|----------|
| 单例模式 | UserPreferences、KeyboardManager、InputMethodManager、LaunchManager |
| 代理模式 | KeyboardManager 与 AppDelegate 之间的通信 |
| 观察者模式 | CGEventTap 监听键盘事件 |

### 模块依赖关系

```
main.swift
    │
    └── AppDelegate.swift
            │
            ├── StatusBarManager.swift
            │       │
            │       └── InputMethodManager.swift
            │
            ├── KeyboardManager (inputsource.swift)
            │       │
            │       ├── InputSource (inputsource.swift)
            │       │
            │       └── InputSourceManager (inputsource.swift)
            │
            ├── UserPreferences.swift
            │
            └── LaunchManager.swift
```

---

## 源代码结构

### 1. main.swift

**职责**：应用程序入口点

**主要功能**：
- 检查辅助功能权限（Accessibility Permission）
- 设置应用程序激活策略（.accessory 模式）
- 启动应用程序主事件循环

**关键代码流程**：
```
启动 → 检查权限 → 失败则退出 → 设置激活策略 → 运行主循环
```

### 2. AppDelegate.swift

**职责**：应用程序生命周期管理

**主要类**：`AppDelegate`

**属性**：
- `statusBarManager`：状态栏管理器
- `allowedApps`：允许 ESC 切换的应用集合
- `systemApps`：系统应用列表

**关键方法**：
| 方法 | 功能 |
|------|------|
| `applicationDidFinishLaunching()` | 应用程序启动初始化 |
| `loadSystemApps()` | 加载系统应用列表 |
| `toggleApp()` | 切换应用启用状态 |
| `isCurrentAppAllowed()` | 检查当前应用是否允许切换 |
| `shouldSwitchInputSource()` | KeyboardManagerDelegate 协议方法 |

### 3. UserPreferences.swift

**职责**：用户偏好设置持久化

**主要类**：`UserPreferences`（单例）

**存储的配置项**：
| 键名 | 类型 | 说明 |
|------|------|------|
| `allowedApps` | Set<String> | ESC 生效的应用列表 |
| `selectedInputMethod` | String? | 选择的中文输入法 |
| `selectedEnglishInputMethod` | String | 选择的英文输入法 |
| `useShiftSwitch` | Bool | 是否启用 Shift 切换 |
| `launchAtLogin` | Bool | 是否开机启动 |

**默认配置**：
- 默认应用：Terminal、VSCode、MacVim、Windsurf、Obsidian、Warp、Cursor
- 默认 Shift 切换：启用
- 默认英文输入法：ABC

### 4. StatusBarManager.swift

**职责**：菜单栏图标和上下文菜单管理

**主要类**：`StatusBarManager`

**菜单结构**：
```
MacVimSwitch 图标点击显示：
├── 使用说明（链接到 GitHub）
├── ─────────────────────────
├── 选择中文输入法 → 子菜单
├── 选择英文输入法 → 子菜单
├── ─────────────────────────
├── Esc生效的应用 → 子菜单（所有系统应用列表）
├── ─────────────────────────
├── 使用 Shift 切换输入法（开关）
├── 开机启动（开关）
├── ─────────────────────────
└── 退出
```

**关键方法**：
| 方法 | 功能 |
|------|------|
| `setupStatusBarItem()` | 初始化状态栏 |
| `updateStatusBarIcon()` | 更新状态栏图标 |
| `createAndShowMenu()` | 创建菜单 |
| `updateMenuItemStates()` | 更新菜单项状态 |

### 5. inputsource.swift

**职责**：输入法管理和键盘事件监听（核心模块）

**主要类**：

#### InputSource
封装单个输入法的属性和操作：
- `id`：输入法唯一标识符
- `name`：输入法显示名称
- `isCJKV`：是否为中日韩越输入法
- `select()`：切换输入法

#### InputSourceManager
输入法管理器：
- `initialize()`：初始化输入法列表
- `getCurrentSource()`：获取当前输入法
- `getInputSource(name:)`：根据 ID 获取输入法
- `nonCJKVSource()`：获取非 CJKV 输入法
- `forceRefreshInputContext()`：强制刷新输入上下文

#### KeyboardManager
键盘事件管理器：
- `start()`：启动键盘监听
- `setupEventTap()`：设置键盘事件监听
- `switchToEnglish()`：切换到英文输入法
- `switchInputMethod()`：切换输入法
- `handleModifierFlags()`：处理修饰键状态变化

**键盘事件处理**：
```
键盘事件 → CGEventTap → eventCallback
                          │
                          ├── keyDown → 检查 ESC / Ctrl+[
                          ├── keyUp → 记录按键释放
                          └── flagsChanged → 处理 Shift 键
```

### 6. InputMethodManager.swift

**职责**：枚举和过滤系统输入法

**主要类**：`InputMethodManager`（单例）

**公共方法**：
| 方法 | 功能 |
|------|------|
| `getAvailableEnglishInputMethods()` | 获取所有英文输入法 |
| `getAvailableCJKVInputMethods()` | 获取所有 CJKV 输入法 |

**CJKV 语言代码**：
- 中文：`zh`、`zh-CN`、`zh-TW`、`zh-HK`
- 日语：`ja`
- 韩语：`ko`
- 越南语：`vi`

### 7. LaunchManager.swift

**职责**：开机启动管理

**主要类**：`LaunchManager`（单例）

**实现方式**：
- macOS 13.0+：使用 `SMAppService` API
- 旧版本：使用 AppleScript 操作 login item

**关键方法**：
| 方法 | 功能 |
|------|------|
| `isLaunchAtLoginEnabled()` | 检查是否开机启动 |
| `toggleLaunchAtLogin()` | 切换开机启动状态 |

---

## 关键技术实现

### 键盘事件监听

使用 `CGEventTap` API 在会话级别监听键盘事件：

```swift
// 创建事件tap
let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: eventCallback,
    userInfo: ...
)
```

**监听的事件类型**：
- `keyDown`：按键按下
- `keyUp`：按键释放
- `flagsChanged`：修饰键状态变化

### 输入法切换

使用 Carbon 框架的 `TIS` API：

```swift
// 切换输入法
TISSelectInputSource(inputSource)

// 获取当前输入法
TISCopyCurrentKeyboardInputSource()
```

### CJKV 输入法特殊处理

CJKV 输入法切换可能遇到延迟或失败，使用中转策略：

```swift
// 策略1：直接切换
TISSelectInputSource(target)

// 策略2：通过非 CJKV 中转
TISSelectInputSource(nonCJKV)
TISSelectInputSource(target)
```

### 辅助功能权限

使用 `AXIsProcessTrusted` API 检查权限：

```swift
if AXIsProcessTrusted() {
    // 已获得权限
} else {
    // 显示权限请求
    let options = [kAXTrustedCheckOptionPrompt: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
}
```

---

## 构建说明

### 环境要求

- Xcode Command Line Tools
- Swift 5.0+

### 构建命令

```bash
# 基本构建
./build.sh

# 构建并创建 DMG
./build.sh --create-dmg
```

### 权限重置（测试用）

```bash
tccutil reset All com.jackiexiao.macvimswitch
```

### 运行应用

```bash
# 杀掉旧进程
pkill -f MacVimSwitch

# 直接运行
./dist/MacVimSwitch.app/Contents/MacOS/macvimswitch
```

---

## 配置说明

### 默认启用的应用

| 应用名称 | Bundle Identifier |
|----------|-------------------|
| Terminal | com.apple.Terminal |
| VSCode | com.microsoft.VSCode |
| MacVim | com.vim.MacVim |
| Windsurf | com.exafunction.windsurf |
| Obsidian | md.obsidian |
| Warp | dev.warp.Warp-Stable |
| Cursor | com.todesktop.230313mzl4w4u92 |

### 快捷键

| 按键 | 功能 |
|------|------|
| ESC | 切换到英文输入法（仅限指定应用） |
| Ctrl + [ | 同 ESC 键 |
| Shift（短按） | 在中英文之间切换 |
| CapsLock（短按） | macOS 原生输入法切换 |

### 注意事项

1. **输入法设置**：使用 MacVimSwitch 前，请关闭输入法中的"使用 Shift 切换中英文"选项，避免冲突

2. **权限要求**：首次运行需要授予辅助功能权限

3. **重启要求**：修改某些系统设置后可能需要重启应用

---

## 文件清单

```
macvimswitch/
├── main.swift                    # 应用程序入口
├── AppDelegate.swift             # 应用委托
├── UserPreferences.swift         # 用户偏好设置
├── StatusBarManager.swift        # 状态栏管理
├── inputsource.swift             # 输入法管理 + 键盘监听
├── InputMethodManager.swift      # 输入法枚举
├── LaunchManager.swift           # 开机启动管理
├── build.sh                      # 构建脚本
├── README.md                     # 项目说明
└── DEVELOPMENT.md                # 本文档
```
