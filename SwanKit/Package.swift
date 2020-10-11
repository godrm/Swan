//
//  Package.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//
import PackageDescription

let package = Package(
    name: "Swan",
    products: [
        .executable(name: "swan", targets: ["SwanKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", .branch("release/5.3")),
        .package(url: "https://github.com/apple/indexstore-db.git", .branch("release/5.3")),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch("release/5.3")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Pecker",
            dependencies: [
                "PeckerKit",
                "SwiftToolsSupport-auto"]
        ),
        .target(
            name: "PeckerKit",
            dependencies: [
                "SwiftSyntax",
                "IndexStoreDB",
                "SwiftToolsSupport-auto",
                "Yams"
            ]
        ),
        .testTarget(
            name: "PeckerTests",
            dependencies: ["Pecker"]),
    ]
)
