import Foundation
import SwiftData
import GoalsDomain

/// SwiftData implementation of BadgeRepositoryProtocol
@MainActor
public final class SwiftDataBadgeRepository: BadgeRepositoryProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func fetchAll() async throws -> [EarnedBadge] {
        let descriptor = FetchDescriptor<EarnedBadgeModel>(
            sortBy: [SortDescriptor(\.earnedAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(category: BadgeCategory) async throws -> EarnedBadge? {
        let categoryRaw = category.rawValue
        let descriptor = FetchDescriptor<EarnedBadgeModel>(
            predicate: #Predicate { $0.categoryRawValue == categoryRaw }
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func fetch(relatedTo goalId: UUID) async throws -> [EarnedBadge] {
        let descriptor = FetchDescriptor<EarnedBadgeModel>(
            predicate: #Predicate { $0.relatedGoalId == goalId },
            sortBy: [SortDescriptor(\.earnedAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    @discardableResult
    public func upsert(_ badge: EarnedBadge) async throws -> EarnedBadge {
        let categoryRaw = badge.category.rawValue
        let descriptor = FetchDescriptor<EarnedBadgeModel>(
            predicate: #Predicate { $0.categoryRawValue == categoryRaw }
        )

        if let existingModel = try modelContext.fetch(descriptor).first {
            existingModel.update(from: badge)
            try modelContext.save()
            return existingModel.toDomain()
        } else {
            let model = EarnedBadgeModel.from(badge)
            modelContext.insert(model)
            try modelContext.save()
            return model.toDomain()
        }
    }

    public func deleteAll() async throws {
        let descriptor = FetchDescriptor<EarnedBadgeModel>()
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    nonisolated public static func == (lhs: SwiftDataBadgeRepository, rhs: SwiftDataBadgeRepository) -> Bool {
        lhs === rhs
    }
}
