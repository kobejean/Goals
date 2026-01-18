import Testing
import Foundation
@testable import GoalsCore

@Suite("GoalsCore Extensions Tests")
struct ExtensionsTests {

    // MARK: - Date Extensions

    @Test("Date startOfDay returns midnight")
    func dateStartOfDay() {
        let date = Date()
        let startOfDay = date.startOfDay

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: startOfDay)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("Date isToday returns true for today")
    func dateIsToday() {
        let today = Date()
        #expect(today.isToday)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        #expect(!yesterday.isToday)
    }

    @Test("Date daysSince calculates correctly")
    func dateDaysSince() {
        let today = Date()
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: today)!

        #expect(today.daysSince(fiveDaysAgo) == 5)
        #expect(fiveDaysAgo.daysSince(today) == -5)
    }

    // MARK: - Double Extensions

    @Test("Double rounds to specified places")
    func doubleRounding() {
        #expect(3.14159.rounded(toPlaces: 2) == 3.14)
        #expect(3.14159.rounded(toPlaces: 4) == 3.1416)
        #expect(3.14159.rounded(toPlaces: 0) == 3.0)
    }

    @Test("Double percentage string formats correctly")
    func doublePercentageString() {
        #expect(0.5.percentageString.contains("50"))
        #expect(1.0.percentageString.contains("100"))
        #expect(0.333.percentageString.contains("33"))
    }

    // MARK: - Collection Extensions

    @Test("Collection safe subscript returns element when in bounds")
    func collectionSafeSubscriptInBounds() {
        let array = [1, 2, 3, 4, 5]
        #expect(array[safe: 0] == 1)
        #expect(array[safe: 2] == 3)
        #expect(array[safe: 4] == 5)
    }

    @Test("Collection safe subscript returns nil when out of bounds")
    func collectionSafeSubscriptOutOfBounds() {
        let array = [1, 2, 3]
        #expect(array[safe: -1] == nil)
        #expect(array[safe: 3] == nil)
        #expect(array[safe: 100] == nil)
    }

    @Test("Collection safe subscript works with empty collection")
    func collectionSafeSubscriptEmpty() {
        let array: [Int] = []
        #expect(array[safe: 0] == nil)
    }
}
