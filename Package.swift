// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MBTiles",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "MBTiles",targets: ["MBTiles"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MBTiles",
            dependencies: [
                "Logging",
                "SQLite"
	    ]),
    ],
    swiftLanguageVersions: [
        SwiftVersion.v5
    ]
)
