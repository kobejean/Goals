import Testing
import Foundation
@testable import GoalsAppFeature
@testable import GoalsDomain

@Suite("GoalsAppFeature Tests")
struct GoalsAppFeatureTests {

    @Test("AppTab has correct titles")
    func appTabTitles() {
        #expect(AppTab.dashboard.title == "Dashboard")
        #expect(AppTab.goals.title == "Goals")
        #expect(AppTab.insights.title == "Insights")
        #expect(AppTab.settings.title == "Settings")
    }

    @Test("AppTab has correct icons")
    func appTabIcons() {
        #expect(AppTab.dashboard.iconName == "square.grid.2x2")
        #expect(AppTab.goals.iconName == "target")
        #expect(AppTab.insights.iconName == "chart.line.uptrend.xyaxis")
        #expect(AppTab.settings.iconName == "gearshape")
    }

    @Test("AppTab is identifiable")
    func appTabIdentifiable() {
        for tab in AppTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }

    @Test("GoalColor converts to SwiftUI color")
    func goalColorSwiftUI() {
        // Verify all colors have SwiftUI representations
        for color in GoalColor.allCases {
            // This just verifies the property exists and doesn't crash
            _ = color.swiftUIColor
        }
    }
}
