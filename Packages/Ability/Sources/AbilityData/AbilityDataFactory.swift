import AbilityDomain
import SwiftData

public enum AbilityDataFactory {
    public static var models: [any PersistentModel.Type] {
        [AbilityValueModel.self]
    }

    public static func makeAbilityValueRepository(container: ModelContainer) -> any AbilityValueRepository {
        SwiftDataAbilityValueRepository(modelContainer: container)
    }
}
