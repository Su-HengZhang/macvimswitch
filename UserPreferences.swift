/**
 * UserPreferences.swift
 *
 * 用户偏好设置管理类
 *
 * 职责：
 * 1. 使用 UserDefaults 存储和读取用户偏好设置
 * 2. 提供类型安全的属性访问接口
 * 3. 管理应用列表、输入法选择、开关设置等配置
 *
 * 数据持久化：
 * - 使用 UserDefaults standard 进行数据存储
 * - 数据存储在 ~/Library/Preferences/com.jackiexiao.macvimswitch.plist
 */

import Foundation
// Foundation 框架提供 UserDefaults、Property List 等数据管理功能

// ================================
// 类定义
// ================================

/**
 * UserPreferences 类
 *
 * 设计模式：单例模式 (Singleton Pattern)
 * - 确保整个应用程序只有一个偏好设置实例
 * - 通过 shared 静态属性访问唯一实例
 *
 * 存储的配置项：
 * - allowedApps: 允许使用 ESC 切换的应用列表
 * - selectedInputMethod: 用户选择的中文输入法
 * - selectedEnglishInputMethod: 用户选择的英文输入法
 * - useShiftSwitch: 是否启用 Shift 切换功能
 * - launchAtLogin: 是否开机启动
 */
class UserPreferences {

    // ================================
    // 单例实现
    // ================================

    /// 单例实例
    /// 通过静态属性确保只有一个 UserPreferences 实例
    static let shared = UserPreferences()

    /// UserDefaults 实例
    /// 用于实际的数据读写操作
    private let defaults = UserDefaults.standard

    // ================================
    // 键名常量
    // ================================

    /**
     * 键名常量结构体
     *
     * 使用结构体组织键名常量，避免命名冲突
     * 所有键名统一管理，便于维护和修改
     */
    private struct Keys {

        /// 允许的应用列表键名
        static let allowedApps = "allowedApps"

        /// 选择的中文输入法键名
        static let selectedInputMethod = "selectedInputMethod"

        /// 选择的英文输入法键名
        static let selectedEnglishInputMethod = "selectedEnglishInputMethod"

        /// Shift 切换开关键名
        static let useShiftSwitch = "useShiftSwitch"

        /// 开机启动键名
        static let launchAtLogin = "launchAtLogin"
    }

    // ================================
    // 允许的应用列表属性
    // ================================

    /**
     * ESC 生效的应用列表
     *
     * 当用户按下 ESC 键时，只在这些应用中切换到英文输入法
     * 使用 Set 数据结构，支持快速的添加、删除、查找操作
     *
     * 数据转换：
     * - 存储时：Set -> Array（UserDefaults 不支持直接存储 Set）
     * - 读取时：Array -> Set
     *
     * @return Set<String> 当前允许的应用 bundle identifier 集合
     */
    var allowedApps: Set<String> {
        get {
            // 从 UserDefaults 读取数组
            let array = defaults.array(forKey: Keys.allowedApps) as? [String] ?? []

            // 将数组转换为 Set 并返回
            // 使用空数组默认值，避免返回 nil
            return Set(array)
        }
        set {
            // 将 Set 转换为数组后存储
            // UserDefaults 标准版只支持数组，不支持 Set
            defaults.set(Array(newValue), forKey: Keys.allowedApps)
        }
    }

    // ================================
    // 选择的输入法属性
    // ================================

    /**
     * 用户选择的中文输入法
     *
     * 当使用 Shift 切换时，从英文切换回的中文输入法
     * 可选类型，如果尚未设置则为 nil
     *
     * @return String? 输入法的 source ID，如 "com.apple.inputmethod.SCIM.ITABC"
     */
    var selectedInputMethod: String? {
        get {
            // 读取字符串类型的输入法 ID
            defaults.string(forKey: Keys.selectedInputMethod)
        }
        set {
            // 存储新的输入法 ID
            // 如果设置为 nil，会清除保存的值
            defaults.set(newValue, forKey: Keys.selectedInputMethod)
        }
    }

    /**
     * 用户选择的英文输入法
     *
     * 按 ESC 键时切换到的目标英文输入法
     * 默认值为 ABC 输入法（com.apple.keylayout.ABC）
     * 非可选类型，始终有值
     *
     * @return String 输入法的 source ID
     */
    var selectedEnglishInputMethod: String {
        get {
            // 读取存储的英文输入法 ID
            // 如果未设置，返回默认值 ABC 输入法
            defaults.string(forKey: Keys.selectedEnglishInputMethod)
                ?? "com.apple.keylayout.ABC"
        }
        set {
            // 存储新的英文输入法 ID
            defaults.set(newValue, forKey: Keys.selectedEnglishInputMethod)
        }
    }

    // ================================
    // 功能开关属性
    // ================================

    /**
     * 是否启用 Shift 切换输入法功能
     *
     * 当设置为 true 时：
     * - 按下 Shift 键（在 0.5 秒内释放）会在中英文输入法之间切换
     *
     * 当设置为 false 时：
     * - Shift 切换功能禁用
     * - 状态栏图标会从带省略号的键盘变为普通键盘
     *
     * @return Bool true 表示启用，false 表示禁用
     */
    var useShiftSwitch: Bool {
        get {
            // 读取布尔值
            // 如果未设置，默认返回 false
            defaults.bool(forKey: Keys.useShiftSwitch)
        }
        set {
            // 存储开关状态
            defaults.set(newValue, forKey: Keys.useShiftSwitch)
        }
    }

    /**
     * 是否开机启动
     *
     * 控制应用程序是否在用户登录时自动启动
     * 通过 LaunchManager 实际管理
     *
     * @return Bool true 表示开机启动，false 表示不启动
     */
    var launchAtLogin: Bool {
        get {
            // 读取布尔值
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            // 存储开关状态
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    // ================================
    // 初始化方法
    // ================================

    /**
     * 私有初始化方法
     *
     * 私有化 init 确保只能通过 shared 单例访问
     * 在初始化时设置默认值
     */
    private init() {
        // 检查并设置默认允许的应用列表
        // 如果键不存在（首次运行），设置默认值
        if defaults.object(forKey: Keys.allowedApps) == nil {
            // 默认启用的应用列表
            // 包含：Terminal、VSCode、MacVim、Windsurf、Obsidian、Warp、Cursor
            allowedApps = Set([
                "com.apple.Terminal",                    // 终端
                "com.microsoft.VSCode",                  // Visual Studio Code
                "com.vim.MacVim",                        // MacVim
                "com.exafunction.windsurf",              // Windsurf
                "md.obsidian",                           // Obsidian
                "dev.warp.Warp-Stable",                  // Warp
                "com.todesktop.230313mzl4w4u92"          // Cursor
            ])
        }

        // 检查并设置默认的 Shift 切换开关
        if defaults.object(forKey: Keys.useShiftSwitch) == nil {
            // 默认启用 Shift 切换功能
            useShiftSwitch = true
        }

        // 检查并设置默认的英文输入法
        if defaults.object(forKey: Keys.selectedEnglishInputMethod) == nil {
            // 默认使用 ABC 输入法（macOS 内置）
            selectedEnglishInputMethod = "com.apple.keylayout.ABC"
        }

        // 注意：selectedInputMethod 不设置默认值
        // 它会在用户首次使用 Shift 切换后自动保存当前输入法
    }
}
