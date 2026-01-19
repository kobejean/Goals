// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "GoalsKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "GoalsDomain",
            targets: ["GoalsDomain"]
        ),
        .library(
            name: "GoalsData",
            targets: ["GoalsData"]
        ),
        .library(
            name: "GoalsCore",
            targets: ["GoalsCore"]
        ),
    ],
    targets: [
        // Domain Layer - Pure business logic, no external dependencies
        .target(
            name: "GoalsDomain",
            dependencies: ["GoalsCore"]
        ),
        .testTarget(
            name: "GoalsDomainTests",
            dependencies: ["GoalsDomain"]
        ),

        // Data Layer - Repository implementations, persistence, networking
        .target(
            name: "GoalsData",
            dependencies: ["GoalsDomain", "GoalsCore"]
        ),
        .testTarget(
            name: "GoalsDataTests",
            dependencies: ["GoalsData"]
        ),

        // Core Layer - Shared utilities and extensions
        .target(
            name: "GoalsCore",
            dependencies: []
        ),
        .testTarget(
            name: "GoalsCoreTests",
            dependencies: ["GoalsCore"]
        ),
    ]
)
