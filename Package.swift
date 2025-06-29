// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenAISwift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        // Main umbrella library that includes all modules
        .library(
            name: "OpenAISwift",
            targets: ["OpenAISwift"]),

        // Individual module libraries
        .library(
            name: "OpenAICore",
            targets: ["OpenAICore"]),
        .library(
            name: "OpenAIChat",
            targets: ["OpenAIChat"]),
        .library(
            name: "OpenAIImages",
            targets: ["OpenAIImages"]),
        .library(
            name: "OpenAIAudio",
            targets: ["OpenAIAudio"]),
        .library(
            name: "OpenAIEmbeddings",
            targets: ["OpenAIEmbeddings"]),
        .library(
            name: "OpenAIStructuredOutput",
            targets: ["OpenAIStructuredOutput"]),
    ],
    dependencies: [],
    targets: [
        // Core module with base types and utilities
        .target(
            name: "OpenAICore",
            dependencies: [],
            path: "Sources/OpenAICore"),

        // Feature-specific modules
        .target(
            name: "OpenAIChat",
            dependencies: ["OpenAICore"],
            path: "Sources/OpenAIChat"),
        .target(
            name: "OpenAIImages",
            dependencies: ["OpenAICore"],
            path: "Sources/OpenAIImages"),
        .target(
            name: "OpenAIAudio",
            dependencies: ["OpenAICore"],
            path: "Sources/OpenAIAudio"),
        .target(
            name: "OpenAIEmbeddings",
            dependencies: ["OpenAICore"],
            path: "Sources/OpenAIEmbeddings"),
        .target(
            name: "OpenAIStructuredOutput",
            dependencies: ["OpenAICore", "OpenAIChat"],
            path: "Sources/OpenAIStructuredOutput"),

        // Main umbrella module that re-exports all functionality
        .target(
            name: "OpenAISwift",
            dependencies: [
                "OpenAICore",
                "OpenAIChat",
                "OpenAIImages",
                "OpenAIAudio",
                "OpenAIEmbeddings",
                "OpenAIStructuredOutput",
            ],
            path: "Sources/OpenAISwift"),

        // Offline tests using mocked API responses
        .testTarget(
            name: "OpenAIOfflineTests",
            dependencies: ["OpenAISwift"],
            path: "Tests/OpenAIOfflineTests",
            resources: [.process("Fixtures")]
        ),

        // Online integration tests that hit real OpenAI endpoints
        .testTarget(
            name: "OpenAIOnlineTests",
            dependencies: ["OpenAISwift"],
            path: "Tests/OpenAIOnlineTests",
            exclude: ["README.md"]
        ),

        // Utility executable to capture real API responses and save as fixtures
        .executableTarget(
            name: "GenerateOpenAIMocks",
            dependencies: ["OpenAISwift"],
            path: "Scripts/GenerateOpenAIMocks"
        ),
    ]
)
