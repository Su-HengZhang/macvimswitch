import Cocoa
import ServiceManagement

class LaunchManager {
    static let shared = LaunchManager()

    private init() {
        UserPreferences.shared.launchAtLogin = isLaunchAtLoginEnabled()
    }

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // 对于旧版本的 macOS，使用 AppleScript 检查登录项
            let script = """
                tell application "System Events"
                    get the name of every login item
                end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                let result = scriptObject.executeAndReturnError(&error)
                if error == nil {
                    // 结果可能是字符串或列表
                    let loginItems: String
                    if result.descriptorType == typeUnicodeText {
                        loginItems = result.stringValue ?? ""
                    } else if result.descriptorType == typeAEList {
                        var items: [String] = []
                        for i in 0..<result.numberOfItems {
                            if let item = result.atIndex(i)?.stringValue {
                                items.append(item)
                            }
                        }
                        loginItems = items.joined(separator: ",")
                    } else {
                        loginItems = result.stringValue ?? ""
                    }
                    return loginItems.contains("MacVimSwitch")
                }
            }
            return false
        }
    }

    func toggleLaunchAtLogin() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    try service.register()
                }
                let newState = isLaunchAtLoginEnabled()
                UserPreferences.shared.launchAtLogin = newState
                return true
            } catch {
                return false
            }
        } else {
            // 对于旧版本的 macOS，使用 AppleScript
            let bundlePath = Bundle.main.bundlePath
            let currentState = isLaunchAtLoginEnabled()
            let script: String

            if currentState {
                script = """
                    tell application "System Events"
                        delete login item "MacVimSwitch"
                    end tell
                """
            } else {
                script = """
                    tell application "System Events"
                        make new login item at end with properties {path:"\(bundlePath)", hidden:false}
                    end tell
                """
            }

            var error: NSDictionary?
            var success = false
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                success = error == nil
            }

            let newState = isLaunchAtLoginEnabled()
            UserPreferences.shared.launchAtLogin = newState
            return success && (newState != currentState)
        }
    }
}
