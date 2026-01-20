import Foundation

// MARK: - Date Extensions

public extension Date {
    /// Returns the start of the day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the end of the day for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Returns the start of the week for this date
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Returns the start of the month for this date
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Returns true if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns true if this date is in the current week
    var isInCurrentWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Returns true if this date is in the current month
    var isInCurrentMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Returns the number of days between this date and another date
    func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date.startOfDay, to: self.startOfDay)
        return components.day ?? 0
    }
}

// MARK: - Double Extensions

public extension Double {
    /// Rounds to specified decimal places
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    /// Returns a percentage string representation
    var percentageString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "\(self * 100)%"
    }
}

// MARK: - Collection Extensions

public extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Array Trend Extensions

public extension Array {
    /// Calculate percentage change between first and last values
    /// Formula: ((last - first) / first) * 100
    /// - Parameter valueExtractor: Closure to extract the numeric value from each element
    /// - Returns: Percentage change, or nil if insufficient data or first value is zero
    func trendPercentage(using valueExtractor: (Element) -> Double) -> Double? {
        guard count >= 2 else { return nil }
        let first = valueExtractor(self[0])
        let last = valueExtractor(self[count - 1])
        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    /// Calculate percentage change between average of first half and second half
    /// Useful for smoothing out daily variations in data like sleep
    /// - Parameter valueExtractor: Closure to extract the numeric value from each element
    /// - Returns: Percentage change between halves, or nil if insufficient data
    func halfTrendPercentage(using valueExtractor: (Element) -> Double) -> Double? {
        guard count >= 4 else { return nil }
        let midpoint = count / 2
        let firstHalf = prefix(midpoint)
        let secondHalf = suffix(midpoint)

        let firstAvg = firstHalf.reduce(0.0) { $0 + valueExtractor($1) } / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0.0) { $0 + valueExtractor($1) } / Double(secondHalf.count)

        guard firstAvg > 0 else { return nil }
        return ((secondAvg - firstAvg) / firstAvg) * 100
    }
}
