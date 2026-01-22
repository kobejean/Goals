import Foundation
import SwiftData
import GoalsDomain
import GoalsData

/// Read-only SwiftData cache access for widgets
public actor WidgetDataCache {
    private let modelContainer: ModelContainer?

    public init() {
        // Initialize with shared container if available
        self.modelContainer = Self.createSharedModelContainer()
    }

    /// Creates a model container using the shared App Group storage
    private static func createSharedModelContainer() -> ModelContainer? {
        guard let containerURL = SharedStorage.sharedContainerURL else {
            return nil
        }

        do {
            let schema = Schema([CachedDataEntry.self])
            let supportDirectory = containerURL.appendingPathComponent("Library/Application Support")
            let storeURL = supportDirectory.appendingPathComponent("CacheStore.sqlite")

            // Ensure the directory exists
            try? FileManager.default.createDirectory(
                at: supportDirectory,
                withIntermediateDirectories: true
            )

            let configuration = ModelConfiguration(
                "CacheStore",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("WidgetDataCache: Failed to create model container: \(error)")
            return nil
        }
    }

    /// Fetches cached records within an optional date range
    public func fetch<T: CacheableRecord>(
        _ type: T.Type,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) async throws -> [T] {
        guard let modelContainer else {
            return []
        }

        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        var predicate: Predicate<CachedDataEntry>

        if let start = startDate, let end = endDate {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate >= start &&
                $0.recordDate <= end
            }
        } else if let start = startDate {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate >= start
            }
        } else if let end = endDate {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType &&
                $0.recordDate <= end
            }
        } else {
            predicate = #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        }

        var descriptor = FetchDescriptor<CachedDataEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.recordDate)]

        let entries = try context.fetch(descriptor)
        return try entries.map { try $0.decode(as: T.self) }
    }

    /// Check if cache has data available
    public func hasData<T: CacheableRecord>(for type: T.Type) async -> Bool {
        guard let modelContainer else {
            return false
        }

        let context = ModelContext(modelContainer)
        let dataSourceRaw = T.dataSource.rawValue
        let recordType = T.recordType

        var descriptor = FetchDescriptor<CachedDataEntry>(
            predicate: #Predicate {
                $0.dataSourceRaw == dataSourceRaw &&
                $0.recordType == recordType
            }
        )
        descriptor.fetchLimit = 1

        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            return false
        }
    }
}
