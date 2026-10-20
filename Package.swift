// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PasswordProtect",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "PasswordProtect",
            targets: ["PasswordProtect"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PasswordProtect"
        )
    ]
)
