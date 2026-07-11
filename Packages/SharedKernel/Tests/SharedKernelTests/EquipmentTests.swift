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

    @Test func everyCaseHasANonEmptyDisplayName() {
        for equipment in Equipment.allCases {
            #expect(!equipment.displayName.isEmpty)
        }
    }

    @Test func displayNameMapsCorrectly() {
        #expect(Equipment.barbell.displayName == "槓鈴")
        #expect(Equipment.dumbbell.displayName == "啞鈴")
        #expect(Equipment.kettlebell.displayName == "壺鈴")
        #expect(Equipment.hexBar.displayName == "六角槓")
        #expect(Equipment.machine.displayName == "機械")
        #expect(Equipment.cable.displayName == "纜繩")
        #expect(Equipment.band.displayName == "彈力帶")
        #expect(Equipment.bodyweight.displayName == "自體重量")
        #expect(Equipment.other.displayName == "其他")
    }
}
