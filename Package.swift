// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PubChemKit",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "PubChemKit", targets: ["PubChemKit"]),
    ],
    targets: [
        .target(name: "PubChemKit"),
        .testTarget(name: "PubChemKitTests", dependencies: ["PubChemKit"], resources: [.copy("Fixtures")]),
    ]
)
