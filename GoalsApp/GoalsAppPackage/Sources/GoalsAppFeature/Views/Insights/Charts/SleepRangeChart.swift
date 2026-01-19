import SwiftUI
import Charts
import GoalsDomain

/// Sleep range chart showing bedtime to wake time as bars (similar to Apple Health)
struct SleepRangeChart: View {
    let data: [SleepRangeDataPoint]
    let showStages: Bool
    let goalBedtime: Double?  // Hour of day
    let goalWakeTime: Double? // Hour of day

    init(
        data: [SleepRangeDataPoint],
        showStages: Bool = false,
        goalBedtime: Double? = nil,
        goalWakeTime: Double? = nil
    ) {
        self.data = data
        self.showStages = showStages
        self.goalBedtime = goalBedtime
        self.goalWakeTime = goalWakeTime
    }

    var body: some View {
        Chart {
            ForEach(data) { point in
                if showStages && !point.stages.isEmpty {
                    // Show detailed stage breakdown
                    ForEach(point.stages) { stage in
                        RectangleMark(
                            x: .value("Date", point.date, unit: .day),
                            yStart: .value("Start", hourToChartValue(stage.startDate)),
                            yEnd: .value("End", hourToChartValue(stage.endDate))
                        )
                        .foregroundStyle(stage.color)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                } else if let bedtime = point.bedtimeChartValue,
                          let wakeTime = point.wakeTimeChartValue {
                    // Show simple sleep duration bar
                    RectangleMark(
                        x: .value("Date", point.date, unit: .day),
                        yStart: .value("Bedtime", bedtime),
                        yEnd: .value("Wake", wakeTime)
                    )
                    .foregroundStyle(.indigo.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Goal bedtime line
            if let bedtime = goalBedtime {
                let chartValue = bedtime < 12 ? bedtime : bedtime - 24
                RuleMark(y: .value("Goal Bedtime", chartValue))
                    .foregroundStyle(.red.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            // Goal wake time line
            if let wakeTime = goalWakeTime {
                RuleMark(y: .value("Goal Wake", wakeTime))
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartYAxis {
            AxisMarks(values: yAxisValues) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(formatHour(hour))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Helpers

    private var yAxisDomain: ClosedRange<Double> {
        // Show from evening (e.g., 8 PM = -4) to morning (e.g., 12 PM = 12)
        let minBedtime = data.compactMap(\.bedtimeChartValue).min() ?? -4
        let maxWakeTime = data.compactMap(\.wakeTimeChartValue).max() ?? 10

        // Add some padding
        let lowerBound = min(minBedtime - 1, -6)  // At least 6 PM
        let upperBound = max(maxWakeTime + 1, 12) // At least noon

        return lowerBound...upperBound
    }

    private var yAxisValues: [Double] {
        // Show marks every 2 hours
        let domain = yAxisDomain
        var values: [Double] = []
        var current = ceil(domain.lowerBound / 2) * 2
        while current <= domain.upperBound {
            values.append(current)
            current += 2
        }
        return values
    }

    private func hourToChartValue(_ date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return 0 }
        let hourValue = Double(hour) + Double(minute) / 60.0
        // Convert to chart coordinates: hours before midnight are negative
        return hourValue < 12 ? hourValue : hourValue - 24
    }

    private func formatHour(_ hour: Double) -> String {
        var h = Int(hour)
        if h < 0 {
            h += 24
        }
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(displayHour) \(period)"
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let sampleData = (0..<7).map { daysAgo -> SleepRangeDataPoint in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!

        // Create sample sleep session
        let bedtimeHour = 22 + Int.random(in: 0...2)
        let wakeHour = 6 + Int.random(in: 0...2)

        let bedtime = calendar.date(bySettingHour: bedtimeHour, minute: Int.random(in: 0...59), second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let wakeTime = calendar.date(bySettingHour: wakeHour, minute: Int.random(in: 0...59), second: 0, of: date)!

        let session = SleepSession(startDate: bedtime, endDate: wakeTime, stages: [])
        let summary = SleepDailySummary(date: date, sessions: [session])
        return SleepRangeDataPoint(from: summary)
    }.reversed()

    return SleepRangeChart(
        data: Array(sampleData),
        showStages: false,
        goalBedtime: 22,
        goalWakeTime: 7
    )
    .padding()
}
