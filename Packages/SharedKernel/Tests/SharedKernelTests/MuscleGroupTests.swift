import Testing

@testable import SharedKernel

struct MuscleGroupTests {
    @Test func rawValueRoundTrips() {
        for group in MuscleGroup.allCases {
            #expect(MuscleGroup(rawValue: group.rawValue) == group)
        }
    }

    // 顯示名／圓章縮寫的翻譯是否齊備見 EnumLocalizationTests。
}
