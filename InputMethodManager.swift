/**
 * InputMethodManager.swift
 *
 * 输入法管理模块
 *
 * 职责：
 * 1. 获取系统中所有可用的输入法
 * 2. 过滤和分类输入法（英文 vs CJKV）
 * 3. 提供输入法列表供菜单选择
 *
 * 技术实现：
 * - 使用 Carbon 框架的 TIS（Text Input Source）API
 * - 通过语言代码过滤输入法类型
 */

import Cocoa
// Cocoa 框架提供基础类和数据类型

import Carbon
// Carbon 框架提供 TISInputSource API

// ================================
// 类定义
// ================================

/**
 * InputMethodManager 类
 *
 * 输入法管理器，负责枚举和过滤系统输入法
 *
 * 设计模式：单例模式
 * - 通过 shared 属性访问唯一实例
 *
 * 功能：
 * - getAvailableEnglishInputMethods(): 获取所有英文输入法
 * - getAvailableCJKVInputMethods(): 获取所有 CJKV（中日韩越）输入法
 */
class InputMethodManager {

    // ================================
    // 单例实现
    // ================================

    /// 单例实例
    static let shared = InputMethodManager()

    // ================================
    // 初始化方法
    // ================================

    /**
     * 私有初始化方法
     *
     * 私有化 init 确保只能通过 shared 单例访问
     * 单例模式的标准实现
     */
    private init() {}

    // ================================
    // 公共接口方法
    // ================================

    /**
     * 获取所有可用的英文输入法
     *
     * 英文输入法的定义：
     * - 不包含中文（zh）、韩语（ko）、日语（ja）、越南语（vi）的输入法
     * - 常见的英文输入法包括：ABC、Unicode Hex Input、Solarized Dark 等
     *
     * @return [(String, String)]? 数组元素为 (输入法ID, 输入法名称) 元组，返回 nil 表示获取失败
     */
    func getAvailableEnglishInputMethods() -> [(String, String)]? {
        // 使用语言过滤器筛选非 CJKV 输入法
        filterInputSources(languageFilter: { languages in
            // 检查是否包含任何 CJKV 语言
            !languages.contains { lang in
                // lang.hasPrefix("zh") 匹配所有中文变体（zh-CN、zh-TW、zh-HK 等）
                lang.hasPrefix("zh") || lang == "ko" || lang == "ja" || lang == "vi"
            }
        })
    }

    /**
     * 获取所有可用的 CJKV 输入法
     *
     * CJKV 输入法包括：
     * - 中文输入法：搜狗拼音、百度输入法、微信输入法等
     * - 日语输入法：Japanese、MS Japanese 等
     * - 韩语输入法：Korean、2-Set Korean 等
     * - 越南语输入法：Vietnamese 等
     *
     * @return [(String, String)]? 数组元素为 (输入法ID, 输入法名称) 元组，返回 nil 表示获取失败
     */
    func getAvailableCJKVInputMethods() -> [(String, String)]? {
        // 使用语言过滤器筛选 CJKV 输入法
        filterInputSources(languageFilter: { languages in
            // 检查是否包含任何 CJKV 语言
            languages.contains { lang in
                lang.hasPrefix("zh") || lang == "ko" || lang == "ja" || lang == "vi"
            }
        })
    }

    // ================================
    // 内部过滤方法
    // ================================

    /**
     * 过滤输入源
     *
     * 核心方法，负责：
     * 1. 获取系统所有输入法
     * 2. 根据条件过滤
     * 3. 去除重复项
     * 4. 返回排序后的列表
     *
     * @param languageFilter 语言过滤闭包
     *                      - 参数：语言列表 [String]
     *                      - 返回值：Bool，true 表示保留该输入法
     * @return [(String, String)]? 过滤后的输入法列表
     */
    private func filterInputSources(languageFilter: (([String]) -> Bool)?) -> [(String, String)]? {
        // 获取所有可用的输入源列表
        // 第一个参数为 filter（nil 不过滤）
        // 第二个参数为 includeInputSources，true 表示包括已禁用
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            // 获取失败，返回 nil
            return nil
        }

        // 存储结果的数组，元素为 (sourceId, name) 元组
        var methods: [(String, String)] = []

        // 用于去重，记录已处理过的输入法名称
        var seenNames = Set<String>()

        // 遍历所有输入源
        for source in inputSources {
            // ================================
            // 步骤1：检查输入法类别
            // ================================

            // 获取输入法类别属性
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  // 将 CFTypeRef 转换为 String
                  let category = (Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as NSString) as String?,
                  // 只处理键盘输入源
                  category == kTISCategoryKeyboardInputSource as String else {
                continue  // 跳过非键盘输入源
            }

            // ================================
            // 步骤2：检查输入法是否启用
            // ================================

            // 获取启用状态属性
            guard let enabledRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
                continue  // 无法获取，跳过
            }

            // 将 CFBoolean 转换为 Bool
            let enabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(enabledRef).takeUnretainedValue())

            // 如果未启用，跳过
            guard enabled else { continue }

            // ================================
            // 步骤3：检查是否是主要输入源
            // ================================

            // 获取选择能力属性
            guard let isPrimaryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
                continue  // 无法获取，跳过
            }

            // 将 CFBoolean 转换为 Bool
            let isPrimary = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(isPrimaryRef).takeUnretainedValue())

            // 如果不可选择，跳过
            guard isPrimary else { continue }

            // ================================
            // 步骤4：获取输入法 ID
            // ================================

            // 获取输入源 ID 属性
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = (Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as NSString) as String? else {
                continue  // 无法获取，跳过
            }

            // ================================
            // 步骤5：获取输入法名称
            // ================================

            // 获取本地化名称属性
            guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                  let name = (Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as NSString) as String? else {
                continue  // 无法获取，跳过
            }

            // ================================
            // 步骤6：语言过滤
            // ================================

            if let languageFilter = languageFilter {
                // 获取输入法的语言列表
                guard let languagesRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages),
                      let languages = (Unmanaged<CFArray>.fromOpaque(languagesRef).takeUnretainedValue() as NSArray) as? [String] else {
                    continue  // 无法获取语言，跳过
                }

                // 检查是否满足过滤条件
                // 同时检查是否已存在（去重）
                guard languageFilter(languages), !seenNames.contains(name) else { continue }
            } else {
                // 没有过滤条件，只检查是否已存在
                guard !seenNames.contains(name) else { continue }
            }

            // ================================
            // 步骤7：添加到结果列表
            // ================================

            // 添加到结果数组
            methods.append((sourceId, name))

            // 记录已处理的名称，用于去重
            seenNames.insert(name)
        }

        // 按输入法名称排序后返回
        return methods.sorted { $0.1 < $1.1 }
    }
}
