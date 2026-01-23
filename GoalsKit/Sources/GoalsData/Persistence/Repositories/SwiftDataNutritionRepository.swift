import Foundation
import SwiftData
import GoalsDomain

/// SwiftData implementation of NutritionRepositoryProtocol
@MainActor
public final class SwiftDataNutritionRepository: NutritionRepositoryProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Entry Operations

    public func fetchAllEntries() async throws -> [NutritionEntry] {
        let descriptor = FetchDescriptor<NutritionEntryModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchEntries(from startDate: Date, to endDate: Date) async throws -> [NutritionEntry] {
        let descriptor = FetchDescriptor<NutritionEntryModel>(
            predicate: #Predicate { entry in
                entry.date >= startDate && entry.date <= endDate
            },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchEntries(for date: Date) async throws -> [NutritionEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let descriptor = FetchDescriptor<NutritionEntryModel>(
            predicate: #Predicate { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchEntry(id: UUID) async throws -> NutritionEntry? {
        let descriptor = FetchDescriptor<NutritionEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        return models.first?.toDomain()
    }

    @discardableResult
    public func createEntry(_ entry: NutritionEntry) async throws -> NutritionEntry {
        let model = NutritionEntryModel.from(entry)
        modelContext.insert(model)
        try modelContext.save()
        return model.toDomain()
    }

    @discardableResult
    public func updateEntry(_ entry: NutritionEntry) async throws -> NutritionEntry {
        let entryId = entry.id
        let descriptor = FetchDescriptor<NutritionEntryModel>(
            predicate: #Predicate { $0.id == entryId }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        model.update(from: entry)
        try modelContext.save()
        return model.toDomain()
    }

    public func deleteEntry(id: UUID) async throws {
        let descriptor = FetchDescriptor<NutritionEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    // MARK: - Summary Operations

    public func fetchDailySummaries(from startDate: Date, to endDate: Date) async throws -> [NutritionDailySummary] {
        let entries = try await fetchEntries(from: startDate, to: endDate)

        // Group entries by day
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        // Convert to summaries
        return grouped.map { date, dayEntries in
            NutritionDailySummary(date: date, entries: dayEntries)
        }.sorted { $0.date < $1.date }
    }

    public func fetchTodaySummary() async throws -> NutritionDailySummary? {
        let today = Date()
        let entries = try await fetchEntries(for: today)
        guard !entries.isEmpty else { return nil }
        return NutritionDailySummary(date: today, entries: entries)
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    nonisolated public static func == (lhs: SwiftDataNutritionRepository, rhs: SwiftDataNutritionRepository) -> Bool {
        lhs === rhs
    }
}
