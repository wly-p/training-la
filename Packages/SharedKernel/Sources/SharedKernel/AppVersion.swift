/// App 版號顯示字串（讀 Info.plist 的 `CFBundleShortVersionString` / `CFBundleVersion`，
/// 由 project.yml 的 MARKETING_VERSION / CURRENT_PROJECT_VERSION 注入）。
/// 純函式、不碰 Bundle，方便測試。
public enum AppVersion {
    /// 例：`"1.0.0 (1)"`；plist 沒帶 version 時回 nil（UI 直接不顯示該列）。
    public static func displayString(infoDictionary: [String: Any]) -> String? {
        guard let version = infoDictionary["CFBundleShortVersionString"] as? String else { return nil }
        guard let build = infoDictionary["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}
