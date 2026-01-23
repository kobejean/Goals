import Foundation

/// Protocol defining the contract for Nutrition persistence operations
public protocol NutritionRepositoryProtocol: Sendable {
    // MARK: - Entry Operations

    /// Fetches all nutrition entries
    func fetchAllEntries() async throws -> [NutritionEntry]

    /// Fetches entries within a date range
    func fetchEntries(from startDate: Date, to endDate: Date) async throws -> [NutritionEntry]

    /// Fetches entries for a specific date (entire day)
    func fetchEntries(for date: Date) async throws -> [NutritionEntry]

    /// Fetches a single entry by its ID
    func fetchEntry(id: UUID) async throws -> NutritionEntry?

    /// Creates a new nutrition entry
    @discardableResult
    func createEntry(_ entry: NutritionEntry) async throws -> NutritionEntry

    /// Updates an existing entry
    @discardableResult
    func updateEntry(_ entry: NutritionEntry) async throws -> NutritionEntry

    /// Deletes an entry by its ID
    func deleteEntry(id: UUID) async throws

    // MARK: - Summary Operations

    /// Fetches daily summaries within a date range
    func fetchDailySummaries(from startDate: Date, to endDate: Date) async throws -> [NutritionDailySummary]

    /// Fetches today's summary
    func fetchTodaySummary() async throws -> NutritionDailySummary?
}
