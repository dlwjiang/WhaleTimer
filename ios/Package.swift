// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BankeCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BankeCore", targets: ["BankeCore"])],
    targets: [
        .target(name: "BankeCore", path: "Banke/Core"),
        .testTarget(name: "BankeCoreTests", dependencies: ["BankeCore"], path: "Tests")
    ]
)
