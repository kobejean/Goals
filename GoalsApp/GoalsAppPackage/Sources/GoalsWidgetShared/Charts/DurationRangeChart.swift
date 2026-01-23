import SwiftUI
import Charts

/// Compact duration range chart for insight cards (40pt height, no axes)
/// - Note: Deprecated. Use `ScheduleChart(data:style:.compact)` directly for new code.
@available(*, deprecated, message: "Use ScheduleChart(data:style:.compact) instead")
public struct DurationRangeChart: View {
    let data: InsightDurationRangeData

    public init(data: InsightDurationRangeData) {
        self.data = data
    }

    public var body: some View {
        ScheduleChart(data: data, style: .compact)
    }
}
