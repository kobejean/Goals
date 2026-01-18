import Foundation
import SwiftData
import GoalsDomain

/// SwiftData implementation of DataPointRepositoryProtocol
@MainActor
public final class SwiftDataDataPointRepository: DataPointRepositoryProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func fetchAll(goalId: UUID) async throws -> [DataPoint] {
        let descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate { $0.goalId == goalId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> [DataPoint] {
        let descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate {
                $0.goalId == goalId &&
                $0.timestamp >= startDate &&
                $0.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchLatest(goalId: UUID) async throws -> DataPoint? {
        var descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate { $0.goalId == goalId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func fetch(id: UUID) async throws -> DataPoint? {
        let descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    @discardableResult
    public func create(_ dataPoint: DataPoint) async throws -> DataPoint {
        let model = DataPointModel.from(dataPoint)

        // Link to goal if exists
        let dpGoalId = dataPoint.goalId
        let goalDescriptor = FetchDescriptor<GoalModel>(
            predicate: #Predicate { $0.id == dpGoalId }
        )
        if let goalModel = try modelContext.fetch(goalDescriptor).first {
            model.goal = goalModel
        }

        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func createBatch(_ dataPoints: [DataPoint]) async throws -> [DataPoint] {
        var created: [DataPoint] = []

        for dataPoint in dataPoints {
            let model = DataPointModel.from(dataPoint)

            // Link to goal if exists
            let dpGoalId = dataPoint.goalId
            let goalDescriptor = FetchDescriptor<GoalModel>(
                predicate: #Predicate { $0.id == dpGoalId }
            )
            if let goalModel = try modelContext.fetch(goalDescriptor).first {
                model.goal = goalModel
            }

            modelContext.insert(model)
            created.append(model.toDomain())
        }

        try modelContext.save()
        return created
    }

    @discardableResult
    public func update(_ dataPoint: DataPoint) async throws -> DataPoint {
        let dpId = dataPoint.id
        let descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate { $0.id == dpId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.update(from: dataPoint)
        try modelContext.save()
        return model.toDomain()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func deleteAll(goalId: UUID) async throws {
        let descriptor = FetchDescriptor<DataPointModel>(
            predicate: #Predicate { $0.goalId == goalId }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    public func sum(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> Double {
        let dataPoints = try await fetch(goalId: goalId, from: startDate, to: endDate)
        return dataPoints.reduce(0) { $0 + $1.value }
    }

    public func average(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> Double {
        let dataPoints = try await fetch(goalId: goalId, from: startDate, to: endDate)
        guard !dataPoints.isEmpty else { return 0 }
        return dataPoints.reduce(0) { $0 + $1.value } / Double(dataPoints.count)
    }

    public func count(goalId: UUID, from startDate: Date, to endDate: Date) async throws -> Int {
        let dataPoints = try await fetch(goalId: goalId, from: startDate, to: endDate)
        return dataPoints.count
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    nonisolated public static func == (lhs: SwiftDataDataPointRepository, rhs: SwiftDataDataPointRepository) -> Bool {
        lhs === rhs
    }
}
