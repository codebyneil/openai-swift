# Installation

Add OpenAISwift to your Swift project using Swift Package Manager.

## Requirements

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Swift 6.0+
- Xcode 15.0+

## Swift Package Manager

### Using Xcode

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the package URL: `https://github.com/your-repo/OpenAISwift`
3. Select the version you want to use
4. Choose the products you want to add to your target

### Using Package.swift

Add OpenAISwift to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/OpenAISwift", from: "1.0.0")
]
```

Then add the products you need to your target:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            // Use the umbrella framework for all features
            .product(name: "OpenAISwift", package: "OpenAISwift"),
            
            // Or import only specific modules
            .product(name: "OpenAICore", package: "OpenAISwift"),
            .product(name: "OpenAIChat", package: "OpenAISwift"),
            // ... other modules as needed
        ]
    )
]
```

## Available Modules

OpenAISwift is modular, allowing you to import only the features you need:

- **OpenAISwift**: Umbrella framework that includes all modules
- **OpenAICore**: Core types and base functionality
- **OpenAIChat**: Chat completion APIs
- **OpenAIImages**: Image generation APIs
- **OpenAIAudio**: Audio transcription and generation
- **OpenAIEmbeddings**: Text embeddings
- **OpenAIStructuredOutput**: Type-safe structured output generation

## Minimal Installation

If you only need specific features, you can reduce your app's binary size by importing only the required modules:

```swift
// Only chat functionality
import OpenAICore
import OpenAIChat

// Only embeddings
import OpenAICore
import OpenAIEmbeddings
```

## Verification

After installation, verify everything is working:

```swift
import OpenAISwift

let openAI = OpenAI(apiKey: "test-key")
print("OpenAISwift successfully imported!")
```