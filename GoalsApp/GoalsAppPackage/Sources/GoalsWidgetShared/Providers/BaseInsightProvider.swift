import Foundation
import SwiftData
import SwiftUI

/// Base class for insight providers that handles common boilerplate.
/// Subclasses only need to implement:
/// - `insightType`: The type of insight this provider handles
/// - `loadData()`: Load data from cache and call `buildInsight(from:)`
/// - `build(from:goals:)`: Static method to build insight from data
open class BaseInsightProvider<DataType>: InsightProvider, @unchecked Sendable {
    /// The insight type - must be overridden by subclasses
    open class var insightType: InsightType {
        fatalError("Subclasses must override insightType")
    }

    // MARK: - Protected Properties

    /// The model container for cache access
    public let container: ModelContainer

    // MARK: - Private State

    private var _summary: InsightSummary?
    private var _activityData: InsightActivityData?

    // MARK: - Initialization

    public required init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - InsightProvider Protocol

    public var summary: InsightSummary? { _summary }
    public var activityData: InsightActivityData? { _activityData }

    /// Loads data from cache and builds the insight.
    /// Subclasses should override this to fetch their specific data.
    open func load() {
        fatalError("Subclasses must override load()")
    }

    // MARK: - Protected Methods

    /// Sets the insight data. Call this from subclass load() implementations.
    public func setInsight(summary: InsightSummary?, activityData: InsightActivityData?) {
        _summary = summary
        _activityData = activityData
    }
}
