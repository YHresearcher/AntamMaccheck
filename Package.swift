// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnTamMacCheck",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AnTamMacCheck", targets: ["AnTamMacCheck"])
    ],
    targets: [
        .executableTarget(name: "AnTamMacCheck", path: "Sources/AnTamMacCheck")
    ]
)
