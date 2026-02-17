// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nopad",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "nopad", targets: ["nopad"]),
    ],
    targets: [
        .executableTarget(
            name: "nopad"
        ),
    ]
)
