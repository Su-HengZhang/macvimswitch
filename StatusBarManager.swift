/**
 * StatusBarManager.swift
 *
 * 状态栏管理器
 *
 * 职责：
 * 1. 管理菜单栏图标的显示和更新
 * 2. 创建和管理上下文菜单
 * 3. 处理用户的菜单交互操作
 *
 * 菜单结构：
 * - 使用说明（链接到 GitHub 项目主页）
 * - 分隔线
 * - 选择中文输入法子菜单
 * - 选择英文输入法子菜单
 * - 分隔线
 * - Esc生效的应用子菜单
 * - 分隔线
 * - 使用 Shift 切换输入法（开关）
 * - 分隔线
 * - 开机启动（开关）
 * - 分隔线
 * - 退出
 */

import Cocoa
// Cocoa 框架提供 NSStatusBar、NSMenu、NSMenuItem 等 UI 组件

// ================================
// 类定义
// ================================

/**
 * StatusBarManager 类
 *
 * 负责管理 macOS 菜单栏（状态栏）中的图标和弹出菜单
 * 使用 NSStatusBar 创建菜单栏项，使用 NSMenu 创建右键菜单
 */
class StatusBarManager {

    // ================================
    // 属性定义
    // ================================

    /// 状态栏项实例
    /// NSStatusBar.system 获取系统状态栏
    /// variableLength 表示状态栏宽度根据内容自动调整
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    /// 当前菜单的引用
    /// 用于后续更新菜单项状态而不重建整个菜单
    private var menu: NSMenu?

    /// 应用程序委托的弱引用
    /// 使用 weak 避免循环引用
    /// 用于访问应用列表和允许的应用列表
    weak var appDelegate: AppDelegate?

    // ================================
    // 状态栏初始化方法
    // ================================

    /**
     * 设置状态栏项
     *
     * 初始化状态栏图标和菜单
     * 这是创建菜单栏入口点的主要方法
     */
    func setupStatusBarItem() {
        // 获取状态栏按钮
        if let button = statusItem.button {
            // 更新状态栏图标
            updateStatusBarIcon()

            // 创建并显示菜单
            createAndShowMenu()

            // 确保按钮可用
            button.isEnabled = true
        } else {
            // 错误处理：无法创建状态栏按钮
            print("错误：无法创建状态栏按钮")
        }
    }

    /**
     * 更新状态栏图标
     *
     * 根据当前设置显示不同的图标：
     * - Shift 切换启用时：keyboard.badge.ellipsis（带省略号的键盘）
     * - Shift 切换禁用时：keyboard（普通键盘）
     */
    func updateStatusBarIcon() {
        // 安全检查：确保按钮存在
        guard let button = statusItem.button else {
            print("Status item button not found")
            return
        }

        // 根据 Shift 切换开关状态选择图标
        if KeyboardManager.shared.useShiftSwitch {
            // Shift 功能启用时显示的图标
            // 使用 SF Symbols 图标系统
            button.image = NSImage(
                systemSymbolName: "keyboard.badge.ellipsis",
                accessibilityDescription: "MacVimSwitch (Shift Enabled)"
            )
        } else {
            // Shift 功能禁用时显示的图标
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "MacVimSwitch"
            )
        }

        // 确保按钮可用
        button.isEnabled = true
    }

    // ================================
    // 菜单创建方法
    // ================================

    /**
     * 创建并显示菜单
     *
     * 构建完整的上下文菜单
     * 包括：
     * - 使用说明链接
     * - 中文输入法选择子菜单
     * - 英文输入法选择子菜单
     * - 应用列表子菜单
     * - 功能开关（Shift 切换、开机启动）
     * - 退出选项
     */
    func createAndShowMenu() {
        // 创建新的菜单实例
        let newMenu = NSMenu()

        // ================================
        // 使用说明菜单项
        // ================================

        // 创建"使用说明"菜单项，点击后打开 GitHub 项目主页
        let homepageItem = NSMenuItem(
            title: "使用说明",              // 菜单显示文本
            action: #selector(openHomepage), // 点击时调用的方法
            keyEquivalent: ""                // 无快捷键
        )
        homepageItem.target = self          // 设置目标为当前实例
        newMenu.addItem(homepageItem)       // 添加到菜单

        // 添加分隔线
        newMenu.addItem(NSMenuItem.separator())

        // ================================
        // 中文输入法选择子菜单
        // ================================

        // 创建子菜单
        let inputMethodMenu = NSMenu()

        // 创建父菜单项，其 submenu 指向子菜单
        let inputMethodItem = NSMenuItem(
            title: "选择中文输入法",
            action: nil,
            keyEquivalent: ""
        )
        inputMethodItem.submenu = inputMethodMenu

        // 获取所有可用的 CJKV（中日韩越）输入法
        if let inputMethods = InputMethodManager.shared.getAvailableCJKVInputMethods() {
            // 遍历所有输入法，创建对应的菜单项
            for (sourceId, name) in inputMethods {
                // 创建菜单项，显示输入法名称
                let item = NSMenuItem(
                    title: name,
                    action: #selector(selectCJKVInputMethod(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                // 将输入法 ID 存储在 representedObject 中
                item.representedObject = sourceId

                // 检查是否是当前选中的输入法
                // 如果是，设置状态为 on（显示勾选标记）
                if sourceId == KeyboardManager.shared.lastInputSource {
                    item.state = .on
                }

                // 添加到子菜单
                inputMethodMenu.addItem(item)
            }
        }

        // 将子菜单添加到主菜单
        newMenu.addItem(inputMethodItem)

        // ================================
        // 英文输入法选择子菜单
        // ================================

        // 创建英文输入法子菜单
        let englishInputMethodMenu = NSMenu()
        let englishInputMethodItem = NSMenuItem(
            title: "选择英文输入法",
            action: nil,
            keyEquivalent: ""
        )
        englishInputMethodItem.submenu = englishInputMethodMenu

        // 获取所有可用的英文输入法
        if let englishInputMethods = InputMethodManager.shared.getAvailableEnglishInputMethods() {
            for (sourceId, name) in englishInputMethods {
                let item = NSMenuItem(
                    title: name,
                    action: #selector(selectEnglishInputMethod(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = sourceId

                // 检查是否是当前选中的英文输入法
                if sourceId == KeyboardManager.shared.englishInputSource {
                    item.state = .on
                }

                englishInputMethodMenu.addItem(item)
            }
        }

        // 添加英文输入法菜单到主菜单
        newMenu.addItem(englishInputMethodItem)

        // 添加分隔线
        newMenu.addItem(NSMenuItem.separator())

        // ================================
        // 应用列表子菜单
        // ================================

        // 检查是否有可用的应用委托
        if let delegate = appDelegate {
            // 创建应用列表子菜单
            let appsMenu = NSMenu()
            let appsMenuItem = NSMenuItem(
                title: "Esc生效的应用",
                action: nil,
                keyEquivalent: ""
            )
            appsMenuItem.submenu = appsMenu

            // 遍历所有系统应用，添加到子菜单
            for app in delegate.systemApps {
                // 创建应用菜单项
                let item = NSMenuItem(
                    title: app.name,
                    action: #selector(AppDelegate.toggleApp(_:)),
                    keyEquivalent: ""
                )

                // 设置选中状态：如果在允许列表中，显示勾选
                item.state = delegate.allowedApps.contains(app.bundleId) ? .on : .off

                // 存储应用的 bundle identifier
                item.representedObject = app.bundleId
                item.target = delegate  // 目标设置为应用委托

                // 添加到子菜单
                appsMenu.addItem(item)
            }

            // 在应用列表后添加分隔线
            appsMenu.addItem(NSMenuItem.separator())

            // 创建"刷新应用列表"菜单项
            let refreshItem = NSMenuItem(
                title: "刷新应用列表",
                action: #selector(AppDelegate.refreshAppList),
                keyEquivalent: "r"  // 设置快捷键 R
            )
            refreshItem.target = delegate
            appsMenu.addItem(refreshItem)

            // 将应用列表菜单添加到主菜单
            newMenu.addItem(appsMenuItem)

            // 添加分隔线
            newMenu.addItem(NSMenuItem.separator())
        }

        // ================================
        // Shift 切换开关
        // ================================

        // 创建"使用 Shift 切换输入法"菜单项
        let shiftSwitchItem = NSMenuItem(
            title: "使用 Shift 切换输入法",
            action: #selector(toggleShiftSwitch),
            keyEquivalent: ""
        )
        shiftSwitchItem.target = self

        // 根据当前状态设置选中状态
        shiftSwitchItem.state = KeyboardManager.shared.useShiftSwitch ? .on : .off

        // 添加到菜单
        newMenu.addItem(shiftSwitchItem)

        // 添加分隔线
        newMenu.addItem(NSMenuItem.separator())

        // ================================
        // 开机启动开关
        // ================================

        // 创建"开机启动"菜单项
        let launchAtLoginItem = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self

        // 根据当前状态设置选中状态
        launchAtLoginItem.state = UserPreferences.shared.launchAtLogin ? .on : .off

        newMenu.addItem(launchAtLoginItem)

        // 添加分隔线
        newMenu.addItem(NSMenuItem.separator())

        // ================================
        // 退出菜单项
        // ================================

        // 创建"退出"菜单项
        // 使用 NSApplication.terminate 作为 action，会终止整个应用程序
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"  // Command + Q 快捷键
        )
        quitItem.target = NSApp  // 目标设置为 NSApplication
        newMenu.addItem(quitItem)

        // ================================
        // 完成菜单设置
        // ================================

        // 将菜单设置到状态栏项
        statusItem.menu = newMenu

        // 保存菜单引用，用于后续更新
        self.menu = newMenu
    }

    // ================================
    // 菜单操作方法
    // ================================

    /**
     * 打开项目主页
     *
     * 使用系统默认浏览器打开 GitHub 项目页面
     */
    @objc private func openHomepage() {
        // 检查 URL 是否有效
        if let url = URL(string: "https://github.com/Jackiexiao/macvimswitch") {
            // 使用 NSWorkspace 打开 URL（系统默认浏览器）
            NSWorkspace.shared.open(url)
        }
    }

    /**
     * 切换 Shift 切换功能
     *
     * 切换 useShiftSwitch 的状态
     * 更新状态栏图标和菜单项状态
     */
    @objc private func toggleShiftSwitch() {
        // 取反当前状态
        KeyboardManager.shared.useShiftSwitch = !KeyboardManager.shared.useShiftSwitch

        // 保存到用户偏好设置
        UserPreferences.shared.useShiftSwitch = KeyboardManager.shared.useShiftSwitch

        // 更新状态栏图标
        updateStatusBarIcon()

        // 更新菜单项状态
        updateMenuItemStates()
    }

    /**
     * 选择中文输入法
     *
     * @param sender 触发此方法的菜单项，包含输入法 ID
     */
    @objc private func selectCJKVInputMethod(_ sender: NSMenuItem) {
        // 从菜单项获取输入法 ID
        guard let sourceId = sender.representedObject as? String else {
            return
        }

        // 设置最后使用的输入法并切换到该输入法
        KeyboardManager.shared.setLastInputSource(sourceId)

        // 更新菜单项状态
        updateMenuItemStates()
    }

    /**
     * 选择英文输入法
     *
     * @param sender 触发此方法的菜单项，包含输入法 ID
     */
    @objc private func selectEnglishInputMethod(_ sender: NSMenuItem) {
        // 从菜单项获取输入法 ID
        guard let sourceId = sender.representedObject as? String else {
            return
        }

        // 设置英文输入法
        KeyboardManager.shared.englishInputSource = sourceId

        // 更新菜单项状态
        updateMenuItemStates()
    }

    /**
     * 更新菜单项状态
     *
     * 只更新选中状态，不重建整个菜单
     * 提高性能和用户体验
     *
     * 更新的项目：
     * - Shift 切换开关状态
     * - 开机启动状态
     * - 中文输入法选中状态
     * - 英文输入法选中状态
     */
    private func updateMenuItemStates() {
        // 检查菜单是否存在
        guard let menu = menu else {
            // 如果菜单不存在，重新创建
            createAndShowMenu()
            return
        }

        // 更新 Shift 切换状态
        // 查找 action 为 toggleShiftSwitch 的菜单项
        if let shiftItem = menu.items.first(where: { $0.action == #selector(toggleShiftSwitch) }) {
            shiftItem.state = KeyboardManager.shared.useShiftSwitch ? .on : .off
        }

        // 更新开机启动状态
        // 查找 action 为 toggleLaunchAtLogin 的菜单项
        if let launchItem = menu.items.first(where: { $0.action == #selector(toggleLaunchAtLogin) }) {
            launchItem.state = UserPreferences.shared.launchAtLogin ? .on : .off
        }

        // 更新中文输入法选中状态
        // 查找标题为"选择中文输入法"的子菜单
        if let cjkvSubmenu = menu.items.first(where: { $0.title == "选择中文输入法" })?.submenu {
            // 遍历子菜单中的所有项
            for item in cjkvSubmenu.items {
                if let sourceId = item.representedObject as? String {
                    // 如果是当前选中的输入法，设置为选中状态
                    item.state = sourceId == KeyboardManager.shared.lastInputSource ? .on : .off
                }
            }
        }

        // 更新英文输入法选中状态
        // 查找标题为"选择英文输入法"的子菜单
        if let englishSubmenu = menu.items.first(where: { $0.title == "选择英文输入法" })?.submenu {
            for item in englishSubmenu.items {
                if let sourceId = item.representedObject as? String {
                    item.state = sourceId == KeyboardManager.shared.englishInputSource ? .on : .off
                }
            }
        }
    }

    /**
     * 切换开机启动状态
     *
     * 通过 LaunchManager 切换开机启动设置
     * 成功后更新菜单状态，失败时显示错误提示
     */
    @objc private func toggleLaunchAtLogin() {
        // 调用 LaunchManager 切换开机启动状态
        if LaunchManager.shared.toggleLaunchAtLogin() {
            // 操作成功，只更新菜单状态
            updateMenuItemStates()
        } else {
            // 操作失败，显示错误提示
            let alert = NSAlert()
            alert.messageText = "设置失败"
            alert.informativeText = "无法修改开机启动设置，请检查系统权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    /**
     * 退出应用程序
     *
     * 清理资源后终止应用程序
     */
    @objc private func quitApp() {
        // 禁用键盘事件监听
        KeyboardManager.shared.disableEventTap()

        // 终止应用程序
        NSApplication.shared.terminate(self)
    }
}
