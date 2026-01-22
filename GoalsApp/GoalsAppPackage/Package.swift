// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "GoalsAppPackage",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "GoalsAppFeature",
            targets: ["GoalsAppFeature"]
        ),
        .library(
            name: "GoalsWidgetShared",
            targets: ["GoalsWidgetShared"]
        ),
    ],
    dependencies: [
        .package(path: "../../GoalsKit")
    ],
    targets: [
        .target(
            name: "GoalsWidgetShared",
            dependencies: [
                .product(name: "GoalsDomain", package: "GoalsKit"),
                .product(name: "GoalsData", package: "GoalsKit"),
            ]
        ),
        .target(
            name: "GoalsAppFeature",
            dependencies: [
                "GoalsWidgetShared",
                .product(name: "GoalsDomain", package: "GoalsKit"),
                .product(name: "GoalsData", package: "GoalsKit"),
                .product(name: "GoalsCore", package: "GoalsKit"),
            ]
        ),
        .testTarget(
            name: "GoalsAppFeatureTests",
            dependencies: [
                "GoalsAppFeature",
                .product(name: "GoalsDomain", package: "GoalsKit"),
            ]
        ),
    ]
)
