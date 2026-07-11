import Testing

@testable import SharedKernel

struct MuscleGroupTests {
    @Test func everyCaseHasANonEmptyDisplayName() {
        for group in MuscleGroup.allCases {
            #expect(!group.displayName.isEmpty)
        }
    }

    @Test func displayNameMapsCorrectly() {
        #expect(MuscleGroup.chest.displayName == "胸")
        #expect(MuscleGroup.back.displayName == "背")
        #expect(MuscleGroup.legs.displayName == "腿")
        #expect(MuscleGroup.shoulders.displayName == "肩")
        #expect(MuscleGroup.arms.displayName == "手臂")
        #expect(MuscleGroup.core.displayName == "核心")
        #expect(MuscleGroup.functional.displayName == "功能性訓練")
        #expect(MuscleGroup.other.displayName == "其他")
    }

    @Test func rawValueRoundTrips() {
        for group in MuscleGroup.allCases {
            #expect(MuscleGroup(rawValue: group.rawValue) == group)
        }
    }
}
