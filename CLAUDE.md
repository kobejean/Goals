# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Goals is an iOS app for tracking personal goals linked to external data sources (TypeQuicker for typing metrics, AtCoder for competitive programming stats, Anki for spaced repetition, Tasks for time tracking, Sleep for health). Built with Swift 6.1+, SwiftUI, and SwiftData. Targets iOS 18.0+. Includes home screen widgets.

## Build & Test Commands

```bash
# Build for iOS Simulator (use XcodeBuildMCP tools when available)
xcodebuild -workspace GoalsApp/GoalsApp.xcworkspace -scheme GoalsApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -workspace GoalsApp/GoalsApp.xcworkspace -scheme GoalsApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test

# Test GoalsKit package only
swift test --package-path GoalsKit

# Test GoalsAppPackage only
swift test --package-path GoalsApp/GoalsAppPackage

# Run a single test (Swift Testing)
swift test --package-path GoalsKit --filter "TestName"
```

When XcodeBuildMCP tools are available, prefer using `session-set-defaults` then `build_sim`/`test_sim` over raw xcodebuild commands.

## Architecture

### Project Structure
```
Goals/
├── GoalsKit/                    # Shared business logic (reusable across platforms)
│   ├── GoalsCore/              # Extensions, utilities
│   ├── GoalsDomain/            # Entities, repository protocols, use cases
│   └── GoalsData/              # Repository implementations, networking, caching
│
└── GoalsApp/                    # iOS app
    ├── GoalsApp/               # App entry point only (@main)
    ├── GoalsAppPackage/        # Feature code
    │   ├── GoalsAppFeature/    # Views, ViewModels, DI
    │   └── GoalsWidgetShared/  # Shared code between app and widget
    ├── GoalsWidget/            # Widget extension target
    └── Config/                 # XCConfig files and entitlements
```

### Layer Boundaries (GoalsKit)
- **GoalsCore**: No dependencies, shared utilities
- **GoalsDomain**: Depends on GoalsCore. Pure business logic—entities, repository protocols, use cases. No SwiftData/networking.
- **GoalsData**: Depends on GoalsDomain + GoalsCore. Repository implementations with SwiftData, HTTP networking, caching wrappers.

### GoalsAppPackage Modules
- **GoalsWidgetShared**: Shared code between app and widget. Contains `InsightBuilders` (single source of truth for building insight summaries), shared models (`InsightSummary`, `InsightType`), reusable chart components, and `InsightCard` UI component.
- **GoalsAppFeature**: Main app features. Depends on GoalsWidgetShared. Contains Views, ViewModels, and DI container.

### Widget Architecture
The widget extension (`GoalsWidget/`) imports `GoalsWidgetShared` to share:
- **InsightBuilders**: Converts raw data (stats, history) into `InsightSummary` for display
- **InsightType**: Enum defining all insight types with colors, icons, titles
- **Chart components**: `SparklineChart`, `ActivityChart`, `DurationRangeChart`, etc.
- **InsightCard**: Reusable card component used by both app and widget

Data flow: `WidgetDataProvider` fetches cached data → `InsightBuilders.build*()` → `InsightSummary` → Widget views

### Dependency Injection
`AppContainer` (in GoalsAppFeature) manages all dependencies:
- Creates ModelContainer with SwiftData schema
- Instantiates repositories, data sources, use cases
- Provides `makeInsightsViewModels()` factory for view models
- Use `AppContainer.preview()` for tests and SwiftUI previews

### Data Sources
External data sources with transparent caching:
- `TypeQuickerDataSource` → `CachedTypeQuickerDataSource`
- `AtCoderDataSource` → `CachedAtCoderDataSource`
- `AnkiDataSource` → `CachedAnkiDataSource`

All use `DataCache` backed by SwiftData's `CachedDataEntry` model.

For comprehensive documentation on data flow, caching, persistence, and concurrency, see [`docs/DATA_ARCHITECTURE.md`](docs/DATA_ARCHITECTURE.md).

## Key Patterns

### State Management (MV Pattern)
- No ViewModels for simple views—use `@State`, `@Observable`, `@Environment`
- ViewModels only for complex views with computed data (charts, multiple sources)
- ViewModels live in `ViewModels/` and are created via `AppContainer` factories

### Concurrency
- Swift 6 strict concurrency mode enabled
- `@MainActor` for all UI code
- async/await only, no GCD
- Use `.task { }` modifier for view lifecycle async work

### Testing
- Swift Testing framework (`@Test`, `#expect`, `#require`)
- Not XCTest

## File Locations

| What | Where |
|------|-------|
| App entry point | `GoalsApp/GoalsApp/GoalsAppApp.swift` |
| Main views | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/Views/` |
| ViewModels | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/ViewModels/` |
| DI Container | `GoalsApp/GoalsAppPackage/Sources/GoalsAppFeature/DI/AppContainer.swift` |
| Domain entities | `GoalsKit/Sources/GoalsDomain/Entities/` |
| Repository protocols | `GoalsKit/Sources/GoalsDomain/Repositories/` |
| SwiftData models | `GoalsKit/Sources/GoalsData/Persistence/Models/` |
| Data sources | `GoalsKit/Sources/GoalsData/DataSources/` |
| Build config | `GoalsApp/Config/*.xcconfig` |
| Entitlements | `GoalsApp/Config/GoalsApp.entitlements` |
| Widget extension | `GoalsApp/GoalsWidget/` |
| Shared widget code | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/` |
| Insight builders | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Data/InsightBuilders.swift` |
| Insight types | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Models/InsightType.swift` |
| Shared charts | `GoalsApp/GoalsAppPackage/Sources/GoalsWidgetShared/Charts/` |

## Adding Features

1. **New entity**: Add to `GoalsKit/Sources/GoalsDomain/Entities/`
2. **New data source**: Create in `GoalsKit/Sources/GoalsData/DataSources/`, add caching wrapper, register in `AppContainer`
3. **New view**: Add to `GoalsAppPackage/Sources/GoalsAppFeature/Views/`, mark `public` for app shell access
4. **New capability**: Edit `GoalsApp/Config/GoalsApp.entitlements` XML directly
5. **New insight type**:
   - Add case to `InsightType` enum in `GoalsWidgetShared/Models/InsightType.swift`
   - Add builder method in `InsightBuilders.swift` (e.g., `buildNewInsight(from:goals:)`)
   - Update `WidgetDataProvider` to fetch and build the new insight
   - Create ViewModel in `GoalsAppFeature/ViewModels/` if needed for detail view

## Code Style

- Types: `UpperCamelCase`, properties/functions: `lowerCamelCase`
- Prefer `struct` over `class`, `let` over `var`
- Early returns with `guard`
- No force unwrapping
- All SwiftData models use `@Model` macro
- All observable classes use `@Observable` macro (not `ObservableObject`)
