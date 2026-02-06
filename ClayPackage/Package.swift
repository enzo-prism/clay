// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClayFeature",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ClayFeature",
            targets: ["ClayFeature"]
        ),
        .executable(
            name: "BalanceSim",
            targets: ["BalanceSim"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ClayFeature",
            dependencies: [],
            exclude: [
                "Resources/Kenney/BuildingKit",
                "Resources/Kenney/CityKitCommercial",
                "Resources/Kenney/CityKitIndustrial",
                "Resources/Kenney/CityKitRoads",
                "Resources/Kenney/CityKitSuburban",
                "Resources/Kenney/GameIcons/PNG/Black",
                "Resources/Kenney/GameIcons/PNG/White/1x",
                "Resources/Kenney/UIPackSciFi"
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ClayFeatureTests",
            dependencies: [
                "ClayFeature"
            ]
        ),
        .executableTarget(
            name: "BalanceSim",
            dependencies: [
                "ClayFeature"
            ]
        ),
    ]
)
