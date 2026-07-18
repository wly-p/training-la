/// App 版號顯示字串（讀 Info.plist 的 `CFBundleShortVersionString` / `CFBundleVersion`，
/// 由 project.yml 的 MARKETING_VERSION / CURRENT_PROJECT_VERSION 注入）。
/// 純函式、不碰 Bundle，方便測試。
public enum AppVersion {
    /// 例：dev「`1.0.0 (1)`」、prod「`1.0.0`」；plist 沒帶 version 時回 nil（UI 直接不顯示該列）。
    /// build number 是 TestFlight 測試迭代的識別，只給非 prod 環境看；環境判斷沿用
    /// 同一份 infoDictionary 裡的 `AppEnv`（見 ``AppEnvironment``）。
    public static func displayString(infoDictionary: [String: Any]) -> String? {
        guard let version = infoDictionary["CFBundleShortVersionString"] as? String else { return nil }
        let isProd = AppEnvironment.resolve(infoDictionary: infoDictionary).name == .prod
        guard !isProd, let build = infoDictionary["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}
