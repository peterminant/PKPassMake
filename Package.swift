// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PKPassMake",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(
            name: "PKPassMake",
            targets: ["PKPassMake"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.1.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.1"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.17.0")
    ],
    targets: [
        .target(
            name: "PKPassMake",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .product(name: "Subprocess", package: "swift-subprocess", condition: .when(platforms: [.macOS, .linux])),
                "ZIPFoundation"
            ]
        ),
        .testTarget(
            name: "PKPassMakeTests",
            dependencies: ["PKPassMake"],
            resources: [.copy("Example")]
        ),
        .executableTarget(
            name: "PKPassSignServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "PKPassMake"
            ]
        ),
    ]
)
