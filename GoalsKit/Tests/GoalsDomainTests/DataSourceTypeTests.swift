import Testing
import Foundation
@testable import GoalsDomain

@Suite("DataSourceType Tests")
struct DataSourceTypeTests {

    @Test("DataSourceType has correct display names")
    func dataSourceDisplayNames() {
        #expect(DataSourceType.manual.displayName == "Manual Entry")
        #expect(DataSourceType.typeQuicker.displayName == "TypeQuicker")
        #expect(DataSourceType.atCoder.displayName == "AtCoder")
        #expect(DataSourceType.finance.displayName == "Finance")
        #expect(DataSourceType.location.displayName == "Location")
    }

    @Test("DataSourceType has correct icon names")
    func dataSourceIconNames() {
        #expect(DataSourceType.manual.iconName == "pencil.circle")
        #expect(DataSourceType.typeQuicker.iconName == "keyboard")
        #expect(DataSourceType.atCoder.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(DataSourceType.finance.iconName == "dollarsign.circle")
        #expect(DataSourceType.location.iconName == "location.circle")
    }

    @Test("DataSourceType has descriptions")
    func dataSourceDescriptions() {
        for source in DataSourceType.allCases {
            #expect(!source.description.isEmpty)
        }
    }

    @Test("DataSourceType is Codable")
    func dataSourceCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for source in DataSourceType.allCases {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(DataSourceType.self, from: data)
            #expect(decoded == source)
        }
    }
}
