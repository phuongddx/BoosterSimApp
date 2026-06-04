// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "boostersim-cli",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "boostersim", targets: ["boostersim"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "boostersim",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/boostersim"
        )
    ]
)
