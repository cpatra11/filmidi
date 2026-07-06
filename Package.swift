// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Filmidi",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Filmidi", targets: ["Filmidi"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.3"),
        .package(url: "https://github.com/airbnb/lottie-spm", from: "4.6.1"),
    ],
    targets: [
        .executableTarget(
            name: "Filmidi",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "Lottie", package: "lottie-spm"),
            ],
            path: "Sources/Filmidi",
            exclude: [
                "Resources/Info.plist",
                "Resources/AppIcon.icon",
                "Resources/AppIcon.icns",
                "Resources/AppIcon.png",
            ],
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/MCPB/filmidi-pro.mcpb"),
                .copy("Resources/Images"),
                .copy("Resources/Changelog"),
                .copy("Resources/Localization"),
            ],
            plugins: ["MetalCIKernelPlugin"]
        ),
        .plugin(name: "MetalCIKernelPlugin", capability: .buildTool()),
        .testTarget(
            name: "FilmidiTests",
            dependencies: ["Filmidi"],
            path: "Tests/FilmidiTests"
        ),
    ]
)
