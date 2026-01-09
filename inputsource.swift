/**
 * inputsource.swift
 *
 * 输入法管理模块
 *
 * 核心组件：
 * 1. InputSource - 输入法源类，封装单个输入法的属性和操作
 * 2. InputSourceManager - 输入法管理器，负责获取和切换输入法
 * 3. KeyboardManager - 键盘事件管理器，监听 ESC 和 Shift 键
 *
 * 技术实现：
 * - 使用 Carbon 框架的 TIS（Text Input Source）API
 * - 使用 CGEvent API 监听全局键盘事件
 * - 使用事件tap机制捕获系统级键盘输入
 */

import Cocoa
// Cocoa 框架提供基础类和数据类型

import Carbon
// Carbon 框架提供 TISInputSource API 和辅助功能

import Foundation
// Foundation 框架提供基础数据类型和操作

import ServiceManagement
// ServiceManagement 框架提供登录项管理功能

// ================================
// 输入法源类
// ================================

/**
 * InputSource 类
 *
 * 封装单个输入法的所有信息和操作
 *
 * 属性：
 * - tisInputSource: 底层 TISInputSource 对象
 * - id: 输入法的唯一标识符
 * - name: 输入法的显示名称
 * - isCJKV: 是否为中日韩越输入法
 *
 * 操作：
 * - select(): 切换到此输入法
 */
class InputSource: Equatable {

    // ================================
    // Equatable 协议实现
    // ================================

    /**
     * 等值比较操作符重载
     * 用于判断两个 InputSource 是否表示同一个输入法
     */
    static func == (lhs: InputSource, rhs: InputSource) -> Bool {
        // 通过比较 id 判断是否相同
        return lhs.id == rhs.id
    }

    // ================================
    // 属性定义
    // ================================

    /// 底层的 TISInputSource 对象
    /// 这是 Carbon 框架提供的输入源数据结构
    let tisInputSource: TISInputSource

    /**
     * 输入法的唯一标识符
     * 格式如：com.apple.keylayout.ABC
     */
    var id: String {
        return tisInputSource.id
    }

    /**
     * 输入法的显示名称
     * 如："ABC"、"搜狗拼音"、"日语"
     */
    var name: String {
        return tisInputSource.name
    }

    /**
     * 是否为 CJKV 输入法
     *
     * CJKV 指的是：
     * - C: Chinese（中文）
     * - J: Japanese（日语）
     * - K: Korean（韩语）
     * - V: Vietnamese（越南语）
     *
     * 判断逻辑：
     * - 检查输入法的语言列表
     * - 如果包含 zh（中文）、ko（韩语）、ja（日语）、vi（越南语）则为 CJKV
     *
     * @return Bool true 表示是 CJKV 输入法
     */
    var isCJKV: Bool {
        // 获取输入法的语言列表
        if let lang = tisInputSource.sourceLanguages.first {
            // 检查语言代码
            // zh 开头的包括：zh-CN、zh-TW、zh-HK 等
            // 还检查单独的 ko、ja、vi
            return lang == "ko" || lang == "ja" || lang == "vi" || lang.hasPrefix("zh")
        }
        // 如果没有语言信息，默认不是 CJKV
        return false
    }

    // ================================
    // 初始化方法
    // ================================

    /**
     * 初始化 InputSource
     *
     * @param tisInputSource 底层的 TISInputSource 对象
     */
    init(tisInputSource: TISInputSource) {
        self.tisInputSource = tisInputSource
    }

    // ================================
    // 输入法切换方法
    // ================================

    /**
     * 切换到此     * 根据输入法输入法
     *
类型选择不同的切换策略：
     * - CJKV 输入法：使用 switchCJKVSource 方法
     * - 非 CJKV 输入法：使用 selectWithRetry 方法
     */
    func select() {
        // 获取当前输入法
        let currentSource = InputSourceManager.getCurrentSource()

        // 如果已经是目标输入法，不做任何操作
        if currentSource.id == self.id { return }

        // 根据输入法类型选择切换策略
        if self.isCJKV {
            // CJKV 输入法需要特殊处理
            switchCJKVSource()
        } else {
            // 非 CJKV 输入法使用标准切换
            selectWithRetry()
        }
    }

    /**
     * 带重试机制的输入法切换方法
     *
     * 原因：
     * - 某些输入法切换可能不会立即生效
     * - 需要多次尝试确保切换成功
     *
     * 策略：
     * - 最多重试 2 次
     * - 每次尝试后等待 20ms
     * - 验证切换是否成功
     * - 强制刷新输入上下文
     *
     * @param maxAttempts 最大尝试次数，默认 2 次
     */
    private func selectWithRetry(maxAttempts: Int = 2) {
        // 循环尝试切换
        for attempt in 1...maxAttempts {
            // 调用 Carbon API 切换输入法
            TISSelectInputSource(tisInputSource)

            // 等待系统处理切换
            // usleep 单位是微秒，20000 = 20ms
            usleep(InputSourceManager.uSeconds)

            // 验证切换是否成功
            if InputSourceManager.getCurrentSource().id == self.id {
                // 切换成功，强制刷新输入上下文确保立即生效
                InputSourceManager.forceRefreshInputContext()
                return
            }

            // 如果不是最后一次尝试，多等待一段时间再重试
            if attempt < maxAttempts {
                usleep(InputSourceManager.uSeconds)
            }
        }

        // 即使所有尝试都失败，也尝试刷新一次输入上下文
        InputSourceManager.forceRefreshInputContext()
    }

    /**
     * CJKV 输入法切换方法
     *
     * CJKV 输入法切换可能遇到的问题：
     * - macOS 对 CJKV 输入法有特殊的处理逻辑
     * - 直接切换可能失败或延迟
     *
     * 切换策略：
     * 1. 直接尝试切换
     * 2. 如果失败，通过非 CJKV 输入法中转
     * 3. 最后再次尝试并等待更长时间
     *
     * 中转原理：
     * - 先切换到非 CJKV 输入法作为桥梁
     * - 再切换到目标 CJKV 输入法
     */
    private func switchCJKVSource() {
        // 策略1：尝试直接切换到目标输入法
        TISSelectInputSource(tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 验证切换结果
        if InputSourceManager.getCurrentSource().id == self.id {
            // 即使切换成功，也强制刷新输入上下文
            InputSourceManager.forceRefreshInputContext()
            return
        }

        // 策略2：通过非 CJKV 输入法中转
        // 某些 CJKV 输入法需要先切换到英文再切换到目标
        if let nonCJKV = InputSourceManager.nonCJKVSource() {
            // 先切换到非 CJKV 输入法
            TISSelectInputSource(nonCJKV.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 再切换到目标 CJKV 输入法
            TISSelectInputSource(tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 再次验证
            if InputSourceManager.getCurrentSource().id == self.id {
                InputSourceManager.forceRefreshInputContext()
                return
            }

            // 策略3：等待更长时间后再次尝试
            usleep(InputSourceManager.uSeconds * 2)  // 等待 40ms
            TISSelectInputSource(tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 最后强制刷新一次
            InputSourceManager.forceRefreshInputContext()
        }
    }
}

// ================================
// 输入法管理器类
// ================================

/**
 * InputSourceManager 类
 *
 * 静态管理器类，负责：
 * 1. 初始化和获取所有可用输入法
 * 2. 获取当前输入法
 * 3. 切换输入法
 * 4. 获取输入法切换快捷键
 *
 * 设计模式：静态单例（通过静态属性实现）
 */
class InputSourceManager {

    // ================================
    // 静态属性
    // ================================

    /// 所有可用的输入法列表
    /// 在 initialize() 方法中初始化
    static var inputSources: [InputSource] = []

    /// 切换等待时间（微秒）
    /// 增加等待时间提高切换稳定性
    static var uSeconds: UInt32 = 20000  // 20ms

    /// 是否只获取键盘输入源
    /// 设为 true 时过滤掉非键盘输入源（如 Emoji 面板）
    static var keyboardOnly: Bool = true

    // ================================
    // 输入法初始化方法
    // ================================

    /**
     * 初始化输入法列表
     *
     * 从系统获取所有可用的输入源
     * 并根据设置过滤
     */
    static func initialize() {
        // 获取所有输入源列表
        // TISCreateInputSourceList 第一个参数为 filter，nil 表示不过滤
        // 第二个参数为 includeInputSources，true 表示包括已禁用
        let inputSourceNSArray = TISCreateInputSourceList(nil, false)
            .takeRetainedValue() as NSArray

        // 转换为 TISInputSource 数组
        var inputSourceList = inputSourceNSArray as! [TISInputSource]

        // 如果设置只获取键盘输入源，进行过滤
        if self.keyboardOnly {
            // 过滤条件：category 为 keyboardInputSource
            inputSourceList = inputSourceList.filter({
                $0.category == TISInputSource.Category.keyboardInputSource
            })
        }

        // 进一步过滤：只保留可选择的输入源
        // 某些输入源虽然存在但可能无法被选择
        inputSources = inputSourceList.filter({ $0.isSelectable })
            .map { InputSource(tisInputSource: $0) }
    }

    /**
     * 获取当前输入法
     *
     * @return InputSource 当前活动的输入法
     */
    static func getCurrentSource() -> InputSource {
        // 使用 TISCopyCurrentKeyboardInputSource 获取当前键盘输入法
        return InputSource(
            tisInputSource: TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        )
    }

    /**
     * 根据 ID 获取输入法
     *
     * @param name 输入法的 ID
     * @return InputSource? 找到返回输入法对象，否则返回 nil
     */
    static func getInputSource(name: String) -> InputSource? {
        // 在列表中查找匹配的输入法
        return inputSources.first(where: { $0.id == name })
    }

    /**
     * 获取非 CJKV 输入法
     *
     * 用于 CJKV 输入法切换时的中转
     *
     * @return InputSource? 找到返回第一个非 CJKV 输入法，否则返回 nil
     */
    static func nonCJKVSource() -> InputSource? {
        // 查找第一个非 CJKV 输入法
        return inputSources.first(where: { !$0.isCJKV })
    }

    // ================================
    // 快捷键相关方法
    // ================================

    /**
     * 模拟"选择上一个输入法"快捷键
     *
     * 使用 CGEvent API 模拟键盘事件
     * 这是 macOS 系统内置的输入法切换快捷键
     */
    static func selectPrevious() {
        // 获取系统设置的"选择上一个输入源"快捷键
        let shortcut = getSelectPreviousShortcut()
        guard shortcut != nil else { return }

        // 创建事件源
        // .hidSystemState 表示这是一个系统级别的 HID 事件
        let src = CGEventSource(stateID: .hidSystemState)

        // 获取虚拟键码和修饰键标志
        let key = CGKeyCode(shortcut!.0)
        let flag = CGEventFlags(rawValue: shortcut!.1)

        // 创建按键按下事件
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)!
        down.flags = flag
        down.post(tap: .cghidEventTap)  // 发送到系统事件tap

        // 创建按键释放事件
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)!
        up.post(tap: .cghidEventTap)

        // 等待系统处理
        usleep(uSeconds)
    }

    /**
     * 获取"选择上一个输入源"快捷键配置
     *
     * 从系统偏好设置中读取：
     * - com.apple.symbolichotkeys
     * - AppleSymbolicHotKeys
     * - key 60（"Select previous input source"）
     *
     * @return (Int, UInt64)? 返回 (keyCode, flags) 元组，失败返回 nil
     */
    static func getSelectPreviousShortcut() -> (Int, UInt64)? {
        // 读取符号热键的系统配置
        guard let dict = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys"),
              let symbolichotkeys = dict["AppleSymbolicHotKeys"] as? NSDictionary,
              // key 60 是"选择上一个输入源"的标识
              let symbolichotkey = symbolichotkeys["60"] as? NSDictionary,
              // 检查是否启用
              (symbolichotkey["enabled"] as? NSNumber)?.intValue == 1,
              let value = symbolichotkey["value"] as? NSDictionary,
              // 获取快捷键参数
              let parameters = value["parameters"] as? NSArray else {
            return nil
        }

        // 返回 (keyCode, flags)
        // parameters[1] 是虚拟键码
        // parameters[2] 是修饰键标志
        return (
            (parameters[1] as! NSNumber).intValue,
            (parameters[2] as! NSNumber).uint64Value
        )
    }

    /**
     * 判断输入是否为 CJKV
     *
     * @param source 输入源对象
     * @return Bool true 表示是 CJKV 输入法
     */
    static func isCJKVSource(_ source: InputSource) -> Bool {
        return source.isCJKV
    }

    /**
     * 获取输入源 ID
     *
     * @param source 输入源对象
     * @return String 输入源的 ID
     */
    static func getSourceID(_ source: InputSource) -> String {
        return source.id
    }

    /**
     * 获取非 CJKV 输入源
     *
     * @return InputSource? 非 CJKV 输入源
     */
    static func getNonCJKVSource() -> InputSource? {
        return nonCJKVSource()
    }

    /**
     * 强制刷新输入上下文
     *
     * 问题：
     * - 某些情况下输入法切换后，系统不会立即更新输入上下文
     * - 这会导致输入法的视觉状态与实际状态不一致
     *
     * 解决方案：
     * 1. 多次重新选择当前输入法
     * 2. 发送特殊的键盘事件触发刷新
     */
    static func forceRefreshInputContext() {
        // 策略1：通过多次重新选择输入法来触发刷新
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()

        // 第一次：立即重选
        TISSelectInputSource(current)
        usleep(3000)  // 3ms

        // 第二次：再次重选以确保生效
        TISSelectInputSource(current)
        usleep(3000)  // 3ms

        // 策略2：发送特殊的按键序列
        // 使用极短的 Fn 键脉冲，几乎不会被用户察觉
        sendRefreshKeySequence()
    }

    /**
     * 发送刷新按键序列
     *
     * 使用 Fn 键（0x3F）作为刷新键
     * 因为 Fn 键单独按下通常不会触发任何操作
     */
    private static func sendRefreshKeySequence() {
        // 创建事件源
        let source = CGEventSource(stateID: .hidSystemState)

        // 创建 Fn 键按下事件
        // 0x3F 是 Fn 键的虚拟键码
        if let fnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x3F, keyDown: true) {
            // 发送到系统事件tap
            fnDown.post(tap: .cghidEventTap)

            // 极短的延迟（0.5ms）
            usleep(500)

            // 创建 Fn 键释放事件
            if let fnUp = CGEvent(keyboardEventSource: source, virtualKey: 0x3F, keyDown: false) {
                fnUp.post(tap: .cghidEventTap)
            }
        }

        // 等待系统处理事件（2ms）
        usleep(2000)
    }
}

// ================================
// TISInputSource 扩展
// ================================

/**
 * TISInputSource 扩展
 *
 * 为 Carbon 框架的 TISInputSource 添加计算属性
 * 提供更便捷的访问方式
 */
extension TISInputSource {

    /**
     * 输入法类别枚举
     */
    enum Category {
        /// 键盘输入源类别
        static var keyboardInputSource: String {
            return kTISCategoryKeyboardInputSource as String
        }
    }

    /**
     * 获取输入源属性的私有方法
     *
     * @param key 属性键
     * @return AnyObject? 属性值
     */
    private func getProperty(_ key: CFString) -> AnyObject? {
        // 调用 Carbon API 获取属性
        let cfType = TISGetInputSourceProperty(self, key)

        if cfType != nil {
            // 将 C 指针转换为 Swift 对象
            return Unmanaged<AnyObject>.fromOpaque(cfType!).takeUnretainedValue()
        }
        return nil
    }

    /// 输入法的唯一标识符
    var id: String {
        return getProperty(kTISPropertyInputSourceID) as! String
    }

    /// 输入法的本地化名称
    var name: String {
        return getProperty(kTISPropertyLocalizedName) as! String
    }

    /// 输入法的类别
    var category: String {
        return getProperty(kTISPropertyInputSourceCategory) as! String
    }

    /// 是否可选择
    var isSelectable: Bool {
        return getProperty(kTISPropertyInputSourceIsSelectCapable) as! Bool
    }

    /// 输入法支持的语言列表
    var sourceLanguages: [String] {
        return getProperty(kTISPropertyInputSourceLanguages) as! [String]
    }
}

// ================================
// 代理协议定义
// ================================

/**
 * KeyboardManagerDelegate 协议
 *
 * 定义键盘管理器与应用程序之间的通信接口
 */
protocol KeyboardManagerDelegate: AnyObject {

    /**
     * 键盘管理器状态更新通知
     *
     * 当键盘事件状态发生变化时调用
     * 用于更新 UI（如状态栏图标）
     */
    func keyboardManagerDidUpdateState()

    /**
     * 询问是否应该切换输入法
     *
     * 在尝试切换输入法前调用
     * 用于检查当前应用是否允许切换
     *
     * @return Bool true 表示应该切换，false 表示不应该
     */
    func shouldSwitchInputSource() -> Bool
}

// ================================
// 键盘事件管理器类
// ================================

/**
 * KeyboardManager 类
 *
 * 核心键盘事件管理器
 *
 * 功能：
 * 1. 监听全局键盘事件（使用 CGEventTap）
 * 2. 检测 ESC 键和 Shift 键
 * 3. 根据配置自动切换输入法
 *
 * 设计模式：单例模式
 */
class KeyboardManager {

    // ================================
    // 单例实现
    // ================================

    /// 单例实例
    static let shared = KeyboardManager()

    // ================================
    // 代理和事件tap
    // ================================

    /// 弱引用代理
    weak var delegate: KeyboardManagerDelegate?

    /// 键盘事件tap的引用
    /// 用于启用/禁用事件监听
    private var eventTap: CFMachPort?

    // ================================
    // 键码常量
    // ================================

    /**
     * 键码枚举
     * 定义常用键的虚拟键码
     */
    private enum KeyCode {
        /// ESC 键的键码
        static let esc: Int64 = 0x35

        /// 左方括号 [ 键的键码（Ctrl + [ 组合）
        static let leftBracket: Int64 = 0x21
    }

    // ================================
    // 计算属性
    // ================================

    /**
     * 英文输入法 ID
     * 通过 UserPreferences 持久化
     */
    var englishInputSource: String {
        get { UserPreferences.shared.selectedEnglishInputMethod }
        set { UserPreferences.shared.selectedEnglishInputMethod = newValue }
    }

    /**
     * Shift 切换开关
     * 通过 UserPreferences 持久化
     * 设置时通知代理更新 UI
     */
    var useShiftSwitch: Bool {
        get { UserPreferences.shared.useShiftSwitch }
        set {
            UserPreferences.shared.useShiftSwitch = newValue
            // 通知代理状态已更新
            delegate?.keyboardManagerDidUpdateState()
        }
    }

    /**
     * Shift 键最后按下时间
     * 用于检测短按 vs 长按
     */
    var lastShiftPressTime: TimeInterval = 0

    // ================================
    // 内部状态跟踪
    // ================================

    /// 上一个使用的输入法 ID
    /// 用于 Shift 切换时记录中文输入法
    private(set) var lastInputSource: String? {
        get { UserPreferences.shared.selectedInputMethod }
        set { UserPreferences.shared.selectedInputMethod = newValue }
    }

    /// Shift 键是否处于按下状态
    private var isShiftPressed = false

    /// 最后一次按键时间
    private var lastKeyDownTime: TimeInterval = 0

    /// 是否有按键处于按下状态
    private var isKeyDown = false

    /// 最后一次按键事件时间
    private var lastKeyEventTime: TimeInterval = 0

    /// 按键序列时间戳数组
    private var keySequence: [TimeInterval] = []

    /// 按键序列时间窗口（秒）
    /// 在此时间窗口内的多个按键事件会被视为组合键
    private static let KEY_SEQUENCE_WINDOW: TimeInterval = 0.3

    /// Shift 按下开始时间
    private var shiftPressStartTime: TimeInterval = 0

    /// Shift 按下期间是否有其他键按下
    private var hasOtherKeysDuringShift = false

    /// 最后一次修饰键状态
    private var lastFlags: CGEventFlags = CGEventFlags(rawValue: 0)

    // ================================
    // 初始化方法
    // ================================

    /**
     * 私有初始化方法
     * 只通过单例访问
     */
    private init() {
        // 从 UserPreferences 加载配置
        useShiftSwitch = UserPreferences.shared.useShiftSwitch
        lastInputSource = UserPreferences.shared.selectedInputMethod
    }

    /**
     * 启动键盘管理器
     *
     * 初始化输入法列表
     * 设置当前输入法状态
     * 创建事件tap监听键盘事件
     */
    func start() {
        // 初始化输入法管理器
        InputSourceManager.initialize()

        // 初始化输入法设置
        initializeInputSources()

        // 设置键盘事件监听
        setupEventTap()

        // 检查当前输入法状态
        let currentSource = InputSourceManager.getCurrentSource()

        // 如果当前是英文输入法，恢复 lastInputSource
        if currentSource.id == englishInputSource,
           let savedSource = UserPreferences.shared.selectedInputMethod {
            lastInputSource = savedSource
        } else if currentSource.id != englishInputSource {
            // 如果当前不是英文，保存当前输入法
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id
        }
    }

    /**
     * 初始化输入法设置
     *
     * 如果还没有保存的输入法设置
     * 自动检测并设置默认的中文输入法
     */
    private func initializeInputSources() {
        // 如果已经有保存的输入法设置，跳过初始化
        if UserPreferences.shared.selectedInputMethod != nil {
            return
        }

        // 获取所有可用的输入源
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            print("Failed to get input sources")
            return
        }

        // 过滤出键盘输入源
        let keyboardSources = inputSources.filter { source in
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = (Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as NSString) as String? else {
                return false
            }
            return category == kTISCategoryKeyboardInputSource as String
        }

        // 查找第一个非 ABC 的中文输入法
        for source in keyboardSources {
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = (Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as NSString) as String? else {
                continue
            }

            // 跳过英文输入法
            if sourceId != englishInputSource {
                lastInputSource = sourceId
                print("Found Chinese input source: \(sourceId)")
                break
            }
        }

        print("Initialized with input source: \(lastInputSource ?? "none")")
    }

    // ================================
    // 事件tap设置
    // ================================

    /**
     * 设置键盘事件监听tap
     *
     * 使用 CGEventTap API 监听系统级键盘事件
     * 可以捕获所有应用程序的键盘输入
     *
     * 监听的事件类型：
     * - keyDown：按键按下
     * - keyUp：按键释放
     * - flagsChanged：修饰键状态变化（如 Shift）
     */
    func setupEventTap() {
        // 定义要监听的事件掩码
        let eventMask = (1 << CGEventType.keyDown.rawValue) |     // 按键按下
                       (1 << CGEventType.keyUp.rawValue) |       // 按键释放
                       (1 << CGEventType.flagsChanged.rawValue)  // 修饰键变化

        // 创建事件tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,          // 在会话级别创建tap
            place: .headInsertEventTap,       // 插入到事件流的头部
            options: .defaultTap,             // 默认tap类型
            eventsOfInterest: CGEventMask(eventMask),  // 感兴趣的事件
            callback: eventCallback,          // 事件回调函数
            userInfo: UnsafeMutableRawPointer(  // 传递给回调的用户数据
                Unmanaged.passUnretained(self).toOpaque()
            )
        ) else {
            print("Failed to create event tap")
            exit(1)  // 创建失败，退出程序
        }

        // 保存tap引用
        eventTap = tap

        // 将tap添加到运行循环
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // 启用tap
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /**
     * 键盘事件回调函数
     *
     * 这是 C 风格的回调函数
     * 用于处理捕获的键盘事件
     *
     * @param proxy 事件tap的代理
     * @param type 事件类型
     * @param event 事件对象
     * @param refcon 用户数据（KeyboardManager 实例）
     */
    private let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        // 从用户数据获取 KeyboardManager 实例
        guard let refcon = refcon else { return nil }
        let manager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()

        // 根据事件类型处理
        switch type {
        case .keyDown:
            // 处理按键按下事件
            manager.handleKeyDown(true)

            // 获取键码和修饰键状态
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let isControlPressed = flags.contains(.maskControl)

            // 检查是否为 ESC 键或 Ctrl + [
            if keyCode == KeyboardManager.KeyCode.esc || (isControlPressed && keyCode == KeyboardManager.KeyCode.leftBracket) {
                // 检查代理是否允许切换
                if let delegate = manager.delegate,
                   delegate.shouldSwitchInputSource() {
                    // 切换到英文输入法
                    manager.switchToEnglish()
                }
                // 如果不允许，不做任何处理，事件继续传递
            }

        case .keyUp:
            // 处理按键释放事件
            manager.handleKeyDown(false)

        case .flagsChanged:
            // 处理修饰键状态变化
            let flags = event.flags
            manager.handleModifierFlags(flags)

        default:
            // 其他事件不做处理
            break
        }

        // 返回事件，允许它继续传递到下一个监听者
        return Unmanaged.passUnretained(event)
    }

    // ================================
    // 输入法切换方法
    // ================================

    /**
     * 切换输入法
     *
     * 在英文输入法和上次使用的中文输入法之间切换
     */
    func switchInputMethod() {
        // 获取当前输入法
        let currentSource = InputSourceManager.getCurrentSource()

        if currentSource.id == englishInputSource {
            // 如果当前是英文，切换到上次使用的中文输入法
            if let lastSource = lastInputSource,
               let targetSource = InputSourceManager.getInputSource(name: lastSource) {
                targetSource.select()
            }
        } else {
            // 如果当前是中文，保存并切换到英文
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id

            if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
                englishSource.select()
            }
        }

        // 通知代理状态已更新
        delegate?.keyboardManagerDidUpdateState()
    }

    /**
     * 更新上一个输入法
     *
     * @param currentSource 当前输入法
     */
    private func updateLastInputSource(_ currentSource: InputSource) {
        // 只保存非英文输入法
        if currentSource.id != englishInputSource {
            lastInputSource = currentSource.id
        }
        // 重新初始化输入法列表
        InputSourceManager.initialize()
    }

    /**
     * 切换到英文输入法
     *
     * 专门用于 ESC 键触发的切换
     * 与 switchInputMethod 的区别：
     * - 始终切换到英文
     * - 保存当前输入法为 lastInputSource
     */
    func switchToEnglish() {
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            let currentSource = InputSourceManager.getCurrentSource()

            // 如果当前不是英文，才切换
            if currentSource.id != englishInputSource {
                // 保存当前输入法
                lastInputSource = currentSource.id

                // 切换到英文
                InputSource(tisInputSource: englishSource.tisInputSource).select()

                // 通知代理
                delegate?.keyboardManagerDidUpdateState()
            }
        }
    }

    // ================================
    // 修饰键处理方法
    // ================================

    /**
     * 处理修饰键状态变化
     *
     * 主要处理 Shift 键的按下和释放
     *
     * Shift 键处理逻辑：
     * 1. 检测 Shift 键按下
     * 2. 记录按下时间和是否有其他键同时按下
     * 3. 检测 Shift 键释放
     * 4. 如果按下时间 < 0.5秒且没有其他键，则触发输入法切换
     *
     * @param flags 当前的修饰键状态
     */
    func handleModifierFlags(_ flags: CGEventFlags) {
        let currentTime = Date().timeIntervalSince1970

        // 检测 Shift 键状态
        // 左 Shift: 0x20102, 右 Shift: 0x20104
        let currentHasShift = flags.contains(.maskShift)
        let previousHasShift = lastFlags.contains(.maskShift)

        // Shift 键按下：当前有 Shift 但之前没有
        let isShiftKey = currentHasShift && !previousHasShift

        // Shift 键释放：之前有 Shift 但当前没有
        let isShiftRelease = !currentHasShift && previousHasShift

        // 检查是否有其他修饰键同时按下
        // 包括：Command、Control、Option、Fn
        let hasOtherModifiers =
            flags.contains(.maskCommand) || flags.contains(.maskControl) ||
            flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn) ||
            lastFlags.contains(.maskCommand) || lastFlags.contains(.maskControl) ||
            lastFlags.contains(.maskAlternate) || lastFlags.contains(.maskSecondaryFn)

        // 如果有其他修饰键，忽略此次 Shift 事件
        if hasOtherModifiers {
            isShiftPressed = false
            hasOtherKeysDuringShift = true
            lastFlags = flags
            return
        }

        // 更新上一次的修饰键状态
        lastFlags = flags

        // 处理 Shift 按下
        if isShiftKey {
            handleShiftPress(currentTime)
        }
        // 处理 Shift 释放
        else if isShiftRelease {
            handleShiftRelease(currentTime)
        }
    }

    /**
     * 处理 Shift 键按下
     *
     * @param time 按下时间戳
     */
    private func handleShiftPress(_ time: TimeInterval) {
        if !isShiftPressed {
            isShiftPressed = true
            shiftPressStartTime = time
            hasOtherKeysDuringShift = false
        }
    }

    /**
     * 处理 Shift 键释放
     *
     * 判断是否为短按（< 0.5秒）
     * 如果是且没有其他键按下，触发输入法切换
     *
     * @param time 释放时间戳
     */
    private func handleShiftRelease(_ time: TimeInterval) {
        if isShiftPressed {
            // 计算按下持续时间
            let pressDuration = time - shiftPressStartTime

            // 判断是否触发切换
            // 条件：
            // 1. Shift 切换功能启用
            // 2. 没有其他键同时按下
            // 3. 按下时间 < 0.5秒（短按）
            if useShiftSwitch && !hasOtherKeysDuringShift && pressDuration < 0.5 {
                switchInputMethod()
            }
        }

        // 重置状态
        isShiftPressed = false
        hasOtherKeysDuringShift = false
    }

    // ================================
    // 按键序列处理
    // ================================

    /**
     * 清理过期的按键记录
     *
     * 移除超过时间窗口的按键记录
     *
     * @param currentTime 当前时间
     */
    private func cleanupKeySequence(_ currentTime: TimeInterval) {
        // 只保留时间窗口内的按键记录
        keySequence = keySequence.filter {
            currentTime - $0 < KeyboardManager.KEY_SEQUENCE_WINDOW
        }
    }

    /**
     * 判断是否应该触发切换
     *
     * 检查是否有组合键操作
     *
     * @param currentTime 当前时间
     * @return Bool true 表示应该触发切换
     */
    private func shouldTriggerSwitch(_ currentTime: TimeInterval) -> Bool {
        // 如果在时间窗口内有多个按键事件，视为组合键，不触发切换
        if keySequence.count > 1 {
            return false
        }

        // 如果最近有其他按键事件，不触发切换
        if currentTime - lastKeyDownTime < 0.1 {
            return false
        }

        return true
    }

    /**
     * 处理按键事件
     *
     * @param down true 表示按下，false 表示释放
     */
    func handleKeyDown(_ down: Bool) {
        // 如果 Shift 键按下期间有其他键按下，记录状态
        if down && isShiftPressed {
            hasOtherKeysDuringShift = true
        }
    }

    /**
     * 设置上一个输入法
     *
     * @param sourceId 输入法 ID
     */
    func setLastInputSource(_ sourceId: String) {
        lastInputSource = sourceId

        if let source = InputSourceManager.getInputSource(name: sourceId) {
            source.select()
        }

        // 保存到 UserPreferences
        UserPreferences.shared.selectedInputMethod = sourceId
    }

    // ================================
    // CJKV 输入法切换（备用方法）
    // ================================

    /**
     * 切换到 CJKV 输入法
     *
     * 备用切换策略
     * 通过多次切换确保 CJKV 输入法生效
     *
     * @param source 目标输入法
     */
    private func switchToCJKV(_ source: InputSource) {
        // 第一步：切换到目标输入法
        TISSelectInputSource(source.tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 第二步：切换到英文
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            TISSelectInputSource(englishSource.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 第三步：再切回目标输入法
            TISSelectInputSource(source.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 第四步：验证切换结果
            let finalSource = InputSourceManager.getCurrentSource()
            if finalSource.id != source.id {
                // 如果失败，尝试使用另一种序列
                if let nonCJKV = InputSourceManager.nonCJKVSource() {
                    TISSelectInputSource(nonCJKV.tisInputSource)
                    usleep(InputSourceManager.uSeconds)
                    TISSelectInputSource(source.tisInputSource)
                    usleep(InputSourceManager.uSeconds)
                }
            }
        }
    }

    // ================================
    // 资源清理方法
    // ================================

    /**
     * 禁用事件tap
     *
     * 在应用程序退出时调用
     * 清理系统资源
     */
    func disableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
