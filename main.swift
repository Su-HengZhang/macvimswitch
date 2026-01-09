/**
 * MacVimSwitch - macOS 输入法自动切换工具
 *
 * 功能：
 * - 按 ESC 键自动切换到英文输入法（仅在指定应用中生效）
 * - 按 Shift 键在中英文输入法之间切换
 * - 菜单栏图标显示当前输入法状态
 *
 * 需要的权限：
 * - 辅助功能权限（Accessibility Permission）：用于监听键盘事件
 */

// ================================
// 导入系统框架
// ================================

import Cocoa
// Cocoa 框架提供 macOS 应用程序的基础类（NSApplication, NSAlert 等）

import Carbon
// Carbon 框架提供底层系统功能（辅助功能 API：AXIsProcessTrusted 等）

// ================================
// 辅助功能权限检查工具
// ================================

/// MacVimSwitch 工具结构体
/// 用于检查和请求辅助功能权限
struct MacVimSwitch {

    /**
     * 检查当前进程是否已获得辅助功能权限
     *
     * 辅助功能权限是 macOS 的一种安全机制，允许应用程序监听其他应用程序的键盘和鼠标事件。
     * MacVimSwitch 需要此权限来检测 ESC 和 Shift 键的按下事件。
     *
     * @return Bool 如果已获得权限返回 true，否则返回 false
     */
    static func checkAccessibilityPermission() -> Bool {
        // 第一次检查：使用 AXIsProcessTrusted API 快速判断
        // AXIsProcessTrusted() 检查进程是否已在系统隐私设置中被授权
        if AXIsProcessTrusted() {
            // 已获得权限，直接返回 true
            return true
        }

        // 第二次检查：如果没有权限，尝试使用带提示的方式检查
        // kAXTrustedCheckOptionPrompt 选项会在系统隐私设置中显示授权提示
        let options = NSDictionary(dictionary: [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ])

        // AXIsProcessTrustedWithOptions 会显示系统权限对话框
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        // 返回检查结果
        return accessibilityEnabled
    }
}

// ================================
// 程序主入口
// ================================

// 打印启动日志（可在控制台查看应用程序状态）
print("应用程序启动...")

// 创建 NSApplication 单例实例
// NSApplication 是 macOS 桌面应用程序的核心类，负责管理应用程序生命周期
let app = NSApplication.shared

// 创建应用程序代理实例
// AppDelegate 负责处理应用程序的生命周期事件（启动、退出、激活等）
let delegate = AppDelegate()

// 设置应用程序的代理
// 应用程序会将重要事件（如启动完成、窗口关闭）通知给代理
app.delegate = delegate

// ================================
// 权限检查
// ================================

print("检查辅助功能权限...")

// 检查辅助功能权限
// 如果没有获得权限，应用程序无法正常工作，直接退出
if !MacVimSwitch.checkAccessibilityPermission() {
    // 打印错误日志
    print("没有获得辅助功能权限，应用程序退出...")

    // 退出程序，返回错误码 1
    // 错误码 1 表示因权限问题导致启动失败
    exit(1)
}

// ================================
// 应用程序激活设置
// ================================

print("设置应用程序激活策略...")

// 设置应用程序的激活策略为 .accessory（配件模式）
// .accessory 模式特点：
// 1. 应用程序不在 Dock 中显示图标
// 2. 应用程序在后台运行
// 3. 适合菜单栏应用程序
app.setActivationPolicy(.accessory)

// 激活应用程序，确保它能接收系统事件
// ignoringOtherApps: true 表示忽略其他应用程序的激活状态
// 这确保我们的应用程序能被系统识别为活动应用
NSApp.activate(ignoringOtherApps: true)

// ================================
// 启动应用程序主循环
// ================================

print("运行应用程序主循环...")

// 调用 run() 方法启动应用程序的主事件循环
// 主事件循环会持续运行，监听和分发系统事件（如键盘、鼠标事件）
// 直到应用程序收到退出命令
app.run()
