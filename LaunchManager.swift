/**
 * LaunchManager.swift
 *
 * 开机启动管理器
 *
 * 职责：
 * 1. 检查应用程序是否设置为开机启动
 * 2. 启用/禁用开机启动功能
 *
 * 技术实现：
 * - macOS 13.0+：使用 SMAppService API
 * - macOS 12 及更早：使用 AppleScript 操作 login item
 *
 * 注意：
 * - 需要在系统偏好设置中授予完全磁盘访问权限（某些情况下）
 * - 需要用户管理员权限
 */

import Cocoa
// Cocoa 框架提供基础类

import ServiceManagement
// ServiceManagement 框架提供登录项管理 API（macOS 13.0+）

// ================================
// 类定义
// ================================

/**
 * LaunchManager 类
 *
 * 开机启动管理器
 *
 * 设计模式：单例模式
 * - 通过 shared 属性访问唯一实例
 *
 * 功能：
 * - isLaunchAtLoginEnabled(): 检查是否开机启动
 * - toggleLaunchAtLogin(): 切换开机启动状态
 */
class LaunchManager {

    // ================================
    // 单例实现
    // ================================

    /// 单例实例
    static let shared = LaunchManager()

    // ================================
    // 初始化方法
    // ================================

    /**
     * 初始化方法
     *
     * 在初始化时同步当前开机启动状态
     * 从系统读取实际状态，更新 UserPreferences
     */
    private init() {
        // 从系统读取开机启动状态
        UserPreferences.shared.launchAtLogin = isLaunchAtLoginEnabled()
    }

    // ================================
    // 状态查询方法
    // ================================

    /**
     * 检查是否已启用开机启动
     *
     * 实现方式根据 macOS 版本不同：
     * - macOS 13.0+：使用 SMAppService.mainApp.status
     * - 旧版本：使用 AppleScript 查询 login item 列表
     *
     * @return Bool true 表示已启用开机启动
     */
    func isLaunchAtLoginEnabled() -> Bool {
        // 检查 macOS 版本
        if #available(macOS 13.0, *) {
            // macOS 13.0+ 使用 SMAppService API
            // .status 返回 .enabled、.disabled 或 .notFound
            return SMAppService.mainApp.status == .enabled
        } else {
            // 旧版本使用 AppleScript
            return checkLaunchAtLoginWithAppleScript()
        }
    }

    /**
     * 使用 AppleScript 检查开机启动状态（旧版 macOS）
     *
     * 通过 System Events 的 login item 查询
     * 需要辅助功能权限才能访问
     *
     * @return Bool true 表示已启用开机启动
     */
    private func checkLaunchAtLoginWithAppleScript() -> Bool {
        // 构建 AppleScript 代码
        // 获取所有 login item 的名称
        let script = """
            tell application "System Events"
                get the name of every login item
            end tell
        """

        var error: NSDictionary?

        // 执行 AppleScript
        if let scriptObject = NSAppleScript(source: script) {
            // executeAndReturnError 返回执行结果
            let result = scriptObject.executeAndReturnError(&error)

            // 检查是否有错误
            if error == nil {
                // 解析结果
                let loginItems: String

                // AppleScript 可能返回字符串或列表
                if result.descriptorType == typeUnicodeText {
                    // 字符串类型
                    loginItems = result.stringValue ?? ""
                } else if result.descriptorType == typeAEList {
                    // 列表类型，遍历获取所有项
                    var items: [String] = []
                    for i in 0..<result.numberOfItems {
                        if let item = result.atIndex(i)?.stringValue {
                            items.append(item)
                        }
                    }
                    loginItems = items.joined(separator: ",")
                } else {
                    // 其他类型
                    loginItems = result.stringValue ?? ""
                }

                // 检查结果中是否包含 "MacVimSwitch"
                return loginItems.contains("MacVimSwitch")
            }
        }

        // 执行失败或出错，返回 false
        return false
    }

    // ================================
    // 状态切换方法
    // ================================

    /**
     * 切换开机启动状态
     *
     * 启用/禁用开机启动功能
     *
     * 实现方式：
     * - macOS 13.0+：使用 SMAppService.register()/unregister()
     * - 旧版本：使用 AppleScript 添加/删除 login item
     *
     * @return Bool true 表示操作成功，false 表示操作失败
     */
    func toggleLaunchAtLogin() -> Bool {
        // 根据 macOS 版本选择实现方式
        if #available(macOS 13.0, *) {
            // macOS 13.0+ 使用 SMAppService API
            do {
                let service = SMAppService.mainApp

                // 根据当前状态决定是注册还是注销
                if service.status == .enabled {
                    // 当前已启用，需要禁用
                    try service.unregister()
                } else {
                    // 当前未启用，需要启用
                    try service.register()
                }

                // 更新本地状态
                let newState = isLaunchAtLoginEnabled()
                UserPreferences.shared.launchAtLogin = newState

                // 操作成功
                return true
            } catch {
                // 操作失败
                return false
            }
        } else {
            // 旧版本使用 AppleScript
            return toggleLaunchAtLoginWithAppleScript()
        }
    }

    /**
     * 使用 AppleScript 切换开机启动状态（旧版 macOS）
     *
     * @return Bool true 表示操作成功
     */
    private func toggleLaunchAtLoginWithAppleScript() -> Bool {
        // 获取应用程序的 bundle 路径
        let bundlePath = Bundle.main.bundlePath

        // 获取当前状态
        let currentState = isLaunchAtLoginEnabled()

        // 根据当前状态构建不同的 AppleScript
        let script: String

        if currentState {
            // 当前已启用，需要禁用
            // 删除名为 "MacVimSwitch" 的 login item
            script = """
                tell application "System Events"
                    delete login item "MacVimSwitch"
                end tell
            """
        } else {
            // 当前未启用，需要启用
            // 创建新的 login item
            script = """
                tell application "System Events"
                    make new login item at end with properties {path:"\(bundlePath)", hidden:false}
                end tell
            """
        }

        // 执行 AppleScript
        var error: NSDictionary?
        var success = false

        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            success = error == nil
        }

        // 验证操作结果
        let newState = isLaunchAtLoginEnabled()
        UserPreferences.shared.launchAtLogin = newState

        // 返回成功标志
        // 成功且状态确实发生了变化
        return success && (newState != currentState)
    }
}
