import SwiftUI

/// GitHub-style contribution grid showing activity over time
public struct ActivityChart: View {
    let activityData: InsightActivityData

    private let cellSpacing: CGFloat = 2
    private let cornerRadius: CGFloat = 2
    private let targetCellSize: CGFloat = 10

    public init(activityData: InsightActivityData) {
        self.activityData = activityData
    }

    public var body: some View {
        GeometryReader { geometry in
            // Calculate optimal number of weeks based on available width
            let availableWidth = geometry.size.width
            let weeks = max(1, Int((availableWidth + cellSpacing) / (targetCellSize + cellSpacing)))
            let grid = buildGrid(weeks: weeks)
            let weekCount = max(grid.count, 1)
            // Calculate actual cell size to fill available width exactly
            let totalSpacing = cellSpacing * CGFloat(weekCount - 1)
            let cellSize = (availableWidth - totalSpacing) / CGFloat(weekCount)

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            cellView(for: day, size: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func cellView(for day: ActivityDay?, size: CGFloat) -> some View {
        if let day = day {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(day.color.opacity(0.2 + 0.8 * day.intensity))
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(activityData.emptyColor)
                .frame(width: size, height: size)
        }
    }

    /// Build grid of weeks × days
    /// Grid[column][row] where column = week (0 = oldest), row = day of week (0 = Sunday)
    private func buildGrid(weeks: Int) -> [[ActivityDay?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate total days to show
        let totalDays = weeks * 7

        // Create date lookup from activity data
        var activityByDate: [Date: InsightActivityDay] = [:]
        for activity in activityData.days {
            let normalizedDate = calendar.startOfDay(for: activity.date)
            activityByDate[normalizedDate] = activity
        }

        // Build grid from right to left (most recent on right)
        var grid: [[ActivityDay?]] = []

        // Start from the beginning of the period
        let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today)!
        let startWeekday = calendar.component(.weekday, from: startDate)

        var currentDate = startDate
        var currentWeek: [ActivityDay?] = []

        // Fill in empty cells for first week if needed
        let startRow = startWeekday - 1
        for _ in 0..<startRow {
            currentWeek.append(nil)
        }

        // Fill in the grid
        while currentDate <= today {
            let activity = activityByDate[currentDate]
            let activityDay = activity.map { ActivityDay(color: $0.color, intensity: $0.intensity) }
            currentWeek.append(activityDay)

            // Check if we need to start a new week
            if currentWeek.count == 7 {
                grid.append(currentWeek)
                currentWeek = []
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Add remaining days of the current week (no padding for future days)
        if !currentWeek.isEmpty {
            grid.append(currentWeek)
        }

        return grid
    }
}

/// Internal representation of a day in the grid
struct ActivityDay {
    let color: Color
    let intensity: Double
}
