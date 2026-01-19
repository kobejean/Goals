import SwiftUI
import Charts
import GoalsDomain

/// Horizontal stacked bar chart showing sleep stage breakdown
struct SleepStagesChart: View {
    let summary: SleepDailySummary?

    var body: some View {
        if let summary = summary, let session = summary.primarySession {
            VStack(alignment: .leading, spacing: 8) {
                // Stacked bar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(stageData(from: session), id: \.type) { stage in
                            Rectangle()
                                .fill(stage.type.color)
                                .frame(width: stageWidth(stage, totalWidth: geometry.size.width, session: session))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 24)

                // Legend with durations
                stageLegend(for: session)
            }
        } else {
            emptyStateView
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 4) {
            Image(systemName: "moon.zzz")
                .foregroundStyle(.secondary)
            Text("No sleep stage data")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func stageLegend(for session: SleepSession) -> some View {
        let stages = stageData(from: session)

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 6) {
            ForEach(stages, id: \.type) { stage in
                HStack(spacing: 4) {
                    Circle()
                        .fill(stage.type.color)
                        .frame(width: 8, height: 8)
                    Text(stage.type.displayName)
                        .font(.caption)
                    Spacer()
                    Text(formatDuration(stage.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private struct StageInfo {
        let type: SleepStageType
        let duration: TimeInterval
    }

    private func stageData(from session: SleepSession) -> [StageInfo] {
        // Aggregate durations by stage type
        var stageDurations: [SleepStageType: TimeInterval] = [:]

        for stage in session.stages {
            stageDurations[stage.type, default: 0] += stage.duration
        }

        // Order: Deep, Core, REM, Awake (most to least restful sleep)
        let orderedTypes: [SleepStageType] = [.deep, .core, .rem, .asleep, .awake]

        return orderedTypes.compactMap { type in
            guard let duration = stageDurations[type], duration > 0 else { return nil }
            return StageInfo(type: type, duration: duration)
        }
    }

    private func stageWidth(_ stage: StageInfo, totalWidth: CGFloat, session: SleepSession) -> CGFloat {
        let totalDuration = session.totalTimeInBed
        guard totalDuration > 0 else { return 0 }
        return (stage.duration / totalDuration) * totalWidth
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let bedtime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: -1, to: today)!)!
    let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!

    // Create sample stages
    var stages: [SleepStage] = []
    var currentTime = bedtime

    // Simulate a typical sleep pattern
    let stagePattern: [(SleepStageType, Int)] = [
        (.core, 90),    // 90 min core
        (.rem, 20),     // 20 min REM
        (.awake, 5),    // brief wake
        (.core, 60),    // 60 min core
        (.deep, 45),    // 45 min deep
        (.rem, 30),     // 30 min REM
        (.awake, 3),    // brief wake
        (.deep, 30),    // 30 min deep
        (.core, 60),    // 60 min core
        (.rem, 40),     // 40 min REM
    ]

    for (type, minutes) in stagePattern {
        let endTime = currentTime.addingTimeInterval(Double(minutes * 60))
        stages.append(SleepStage(type: type, startDate: currentTime, endDate: endTime))
        currentTime = endTime
    }

    let session = SleepSession(startDate: bedtime, endDate: wakeTime, stages: stages, source: "Apple Watch")
    let summary = SleepDailySummary(date: today, sessions: [session])

    return VStack {
        SleepStagesChart(summary: summary)
            .padding()
    }
}
