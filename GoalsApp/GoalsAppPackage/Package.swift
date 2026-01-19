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
    ],
    dependencies: [
        .package(path: "../../GoalsKit")
    ],
    targets: [
        .target(
            name: "GoalsAppFeature",
            dependencies: [
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
