/**
 * AppDelegate.swift
 *
 * 应用程序委托类
 *
 * 职责：
 * 1. 管理应用程序生命周期事件（启动、激活、退出等）
 * 2. 加载和管理系统应用列表
 * 3. 协调状态栏管理和键盘事件处理
 * 4. 实现 KeyboardManagerDelegate 协议，处理输入法切换状态更新
 */

import Cocoa
// Cocoa 框架提供 NSApplication、NSAlert、NSWorkspace 等类

// ================================
// 类定义
// ================================

/**
 * AppDelegate 类
 *
 * 继承关系：
 * - NSObject：提供 Objective-C 基础功能
 * - NSApplicationDelegate：处理应用程序生命周期事件
 * - KeyboardManagerDelegate：处理键盘管理器状态更新
 */
class AppDelegate: NSObject, NSApplicationDelegate, KeyboardManagerDelegate {

    // ================================
    // 属性定义
    // ================================

    /// 状态栏管理器实例
    /// 负责管理菜单栏图标的显示和菜单的创建
    let statusBarManager = StatusBarManager()

    /**
     * 允许的应用集合（计算属性）
     *
     * 通过 UserPreferences 单例访问和修改
     * 这些应用在按下 ESC 键时会切换到英文输入法
     *
     * @return Set<String> 当前允许的应用 bundle identifier 集合
     */
    var allowedApps: Set<String> {
        get {
            // 从用户偏好设置中获取允许的应用列表
            UserPreferences.shared.allowedApps
        }
        set {
            // 将新的应用集合保存到用户偏好设置
            UserPreferences.shared.allowedApps = newValue
        }
    }

    /**
     * 系统应用列表
     *
     * 存储从 /Applications、~/Applications、/System/Applications 目录
     * 以及当前运行的应用中收集的所有应用
     *
     * 数组元素为元组，包含：
     * - name: 应用名称（如 "Visual Studio Code"）
     * - bundleId: 应用包标识符（如 "com.microsoft.VSCode"）
     */
    var systemApps: [(name: String, bundleId: String)] = []

    // ================================
    // 应用程序生命周期方法
    // ================================

    /**
     * 应用程序启动完成回调
     *
     * 当应用程序完成初始化、进入运行状态时调用
     * 这是进行初始化设置的主要入口点
     *
     * @param notification 通知对象，包含触发事件的相关信息
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 打印启动日志，便于调试
        print("应用程序开始初始化...")

        // 确保应用程序被激活
        // 这样应用程序可以正常接收系统事件
        NSApp.activate(ignoringOtherApps: true)
        print("应用程序已激活")

        // 启用突然终止机制
        // 防止应用程序随终端关闭而意外退出
        // enableSuddenTermination() 会禁用进程级别的信号处理
        ProcessInfo.processInfo.enableSuddenTermination()
        print("已启用突然终止")

        // 加载系统应用列表
        // 从系统目录和当前运行的应用中收集信息
        loadSystemApps()
        print("已加载系统应用列表，共 \(systemApps.count) 个应用")

        // 设置代理
        // 将 KeyboardManager 的代理设置为当前实例
        // 这样可以接收键盘事件状态变化的回调
        KeyboardManager.shared.delegate = self

        // 将状态栏管理器的 appDelegate 设置为当前实例
        // 这样状态栏菜单可以访问应用列表和偏好设置
        statusBarManager.appDelegate = self
        print("已设置键盘管理器代理")

        // 设置状态栏和菜单
        // 由于 UI 操作需要在主线程执行，使用 DispatchQueue.main.async
        print("开始设置状态栏和菜单...")
        DispatchQueue.main.async { [weak self] in
            // 使用 [weak self] 避免循环引用
            self?.statusBarManager.setupStatusBarItem()
            print("状态栏和菜单设置完成")
        }

        // 启动键盘管理器
        // 开始监听键盘事件（ESC 和 Shift 键）
        print("开始启动键盘管理器...")
        KeyboardManager.shared.start()
        print("键盘管理器启动完成")

        // 打印初始化完成日志
        print("应用程序初始化完成")
    }

    // ================================
    // 系统应用加载方法
    // ================================

    /**
     * 加载系统应用列表
     *
     * 从以下位置收集应用信息：
     * 1. /Applications - 系统标准应用目录
     * 2. ~/Applications - 用户主目录中的应用目录
     * 3. /System/Applications - macOS 系统应用目录
     * 4. 当前正在运行的应用
     *
     * 每个应用提取：
     * - CFBundleName：应用名称
     * - CFBundleIdentifier：应用的唯一标识符
     */
    private func loadSystemApps() {
        // 获取 NSWorkspace 单例，用于访问运行中的应用信息
        let workspace = NSWorkspace.shared

        // 定义要扫描的应用程序目录路径
        // 使用 NSString 的 expandingTildeInPath 将 ~ 展开为实际用户目录路径
        let appDirs = [
            "/Applications",           // 系统标准应用目录
            "~/Applications",          // 用户主目录中的应用
            "/System/Applications"     // macOS 系统应用（ventura 及以上）
        ].map { NSString(string: $0).expandingTildeInPath }

        // 临时数组，存储收集到的应用信息
        var apps: [(name: String, bundleId: String)] = []

        // 遍历所有应用目录
        for dir in appDirs {
            // 尝试获取目录内容
            // 如果目录不存在或无法访问，try? 会返回 nil，if let 会跳过
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                // 遍历目录中的每个项目
                for item in contents {
                    // 只处理 .app 后缀的应用包
                    if item.hasSuffix(".app") {
                        // 拼接完整路径
                        let path = (dir as NSString).appendingPathComponent(item)

                        // 尝试读取应用包的 Bundle 信息
                        if let bundle = Bundle(path: path),
                           // 获取应用的 bundle identifier（如 com.apple.Safari）
                           let bundleId = bundle.bundleIdentifier,
                           // 获取应用的显示名称
                           let appName = bundle.infoDictionary?["CFBundleName"] as? String {
                            // 将应用信息添加到数组
                            apps.append((name: appName, bundleId: bundleId))
                        }
                    }
                }
            }
        }

        // 获取当前正在运行的应用
        let runningApps = workspace.runningApplications

        // 遍历运行中的应用
        for app in runningApps {
            // 检查应用是否有 bundle identifier
            if let bundleId = app.bundleIdentifier,
               // 获取应用本地化名称
               let appName = app.localizedName,
               // 检查是否已存在于列表中（避免重复）
               !apps.contains(where: { $0.bundleId == bundleId }) {
                // 添加到应用列表
                apps.append((name: appName, bundleId: bundleId))
            }
        }

        // 按应用名称排序，便于在菜单中显示
        systemApps = apps.sorted { $0.name < $1.name }
    }

    // ================================
    // 应用切换相关方法
    // ================================

    /**
     * 切换应用的启用状态
     *
     * 当用户在菜单中选择某个应用时调用
     * 如果应用已在允许列表中，则移除；否则添加
     *
     * @param sender NSMenuItem，包含应用信息
     */
    @objc func toggleApp(_ sender: NSMenuItem) {
        // 从菜单项的 representedObject 中获取 bundle identifier
        guard let bundleId = sender.representedObject as? String else {
            // 如果无法获取，直接返回
            return
        }

        // 检查应用是否已在允许列表中
        if allowedApps.contains(bundleId) {
            // 如果存在，移除它（禁用）
            allowedApps.remove(bundleId)
            // 更新菜单项的显示状态
            sender.state = .off
        } else {
            // 如果不存在，添加它（启用）
            allowedApps.insert(bundleId)
            // 更新菜单项的显示状态
            sender.state = .on
        }
    }

    /**
     * 刷新应用列表
     *
     * 当用户点击"刷新应用列表"菜单项时调用
     * 重新扫描系统目录，更新应用列表
     */
    @objc func refreshAppList() {
        // 重新加载系统应用
        loadSystemApps()
        // 重建并显示菜单
        statusBarManager.createAndShowMenu()
    }

    // ================================
    // 权限检查方法
    // ================================

    /**
     * 检查当前前台应用是否允许使用 ESC 切换输入法
     *
     * 通过 NSWorkspace 获取当前最前端的应用程序
     * 检查其 bundle identifier 是否在允许列表中
     *
     * @return Bool 如果当前应用允许切换返回 true，否则返回 false
     */
    private func isCurrentAppAllowed() -> Bool {
        // 获取当前前台应用
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            // 检查其 bundle identifier 是否在允许列表中
            // 使用空字符串作为默认值，避免可选类型问题
            return allowedApps.contains(frontmostApp.bundleIdentifier ?? "")
        }
        // 如果无法获取前台应用，返回 false
        return false
    }

    /**
     * 判断是否应该切换输入法
     *
     * 这是 KeyboardManagerDelegate 协议的方法
     * 在尝试切换输入法前调用，用于权限检查
     *
     * @return Bool 如果应该切换返回 true
     */
    func shouldSwitchInputSource() -> Bool {
        // 调用内部方法检查当前应用是否允许
        return isCurrentAppAllowed()
    }

    // ================================
    // 代理回调方法
    // ================================

    /**
     * 键盘管理器状态更新回调
     *
     * 当键盘管理器检测到状态变化（如输入法切换）时调用
     * 实现 KeyboardManagerDelegate 协议
     */
    func keyboardManagerDidUpdateState() {
        // 更新状态栏图标，显示当前输入法状态
        statusBarManager.updateStatusBarIcon()
    }

    // ================================
    // 使用说明方法
    // ================================

    /**
     * 显示使用说明对话框
     *
     * 在应用程序首次启动时向用户展示使用说明
     * 包含重要配置提示和功能说明
     */
    func showInstructions() {
        // 创建 NSAlert 实例
        let alert = NSAlert()

        // 设置警告对话框的标题
        alert.messageText = "MacVimSwitch 使用说明"

        // 设置详细说明文本
        // 使用多行字符串，格式清晰易读
        alert.informativeText = """
            重要提示：
            1. 先关闭输入法中的"使用 Shift 切换中英文"选项，否则会产生冲突
            2. 具体操作：打开输入法偏好设置 → 关闭"使用 Shift 切换中英文"

            功能说明：
            1. 按 ESC 键会自动切换到选定的英文输入法（仅在指定的应用中生效）
            2. 按 Shift 键可以在中英文输入法之间切换（可在菜单栏中关闭）
            3. 提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
            4. 现在您可以选择英文输入法（默认ABC）和中文输入法

            配置说明：
            1. 点击菜单栏图标 → 选择英文输入法，可以选择您优先的英文输入法
            2. 点击菜单栏图标 → 选择中文输入法，可以选择您优先的中文输入法
            3. 点击菜单栏图标 → 启用的应用，可以选择需要启用ESC切换功能的应用
            4. 如果没有看到某个应用，可以点击"刷新应用列表"更新
            """

        // 设置警告样式
        alert.alertStyle = .warning

        // 添加按钮
        alert.addButton(withTitle: "我已了解")

        // 在主线程上显示模态对话框
        // 使用 DispatchQueue.main.async 确保在主线程执行
        DispatchQueue.main.async {
            alert.runModal()
        }
    }
}
