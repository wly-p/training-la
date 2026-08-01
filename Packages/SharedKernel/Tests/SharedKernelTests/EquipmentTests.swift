import Testing

@testable import SharedKernel

struct EquipmentTests {
    @Test func hexBarRawValueIsSnakeCaseToken() {
        #expect(Equipment.hexBar.rawValue == "hex_bar")
    }

    @Test func everyCaseHasARawValueMatchingCaseName() {
        for equipment in Equipment.allCases where equipment != .hexBar {
            #expect(Equipment(rawValue: equipment.rawValue) == equipment)
        }
    }

    // 顯示名的翻譯是否齊備見 EnumLocalizationTests：`displayName(_:)` 現在查 String Catalog，
    // 而 SwiftPM 不編譯 catalog，在這裡斷言字面值只會測到 key 本身。
}
