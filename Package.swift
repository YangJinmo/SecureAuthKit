// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SecureAuthKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SecureAuthKit", targets: ["SecureAuthKit"])
    ],
    targets: [
        .target(name: "SecureAuthKit"),
        .testTarget(name: "SecureAuthKitTests", dependencies: ["SecureAuthKit"])
    ]
)
