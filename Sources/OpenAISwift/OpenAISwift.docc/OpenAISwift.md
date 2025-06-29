# ``OpenAISwift``

A modern, Swift-native SDK for interacting with the OpenAI API.

## Overview

OpenAISwift provides a comprehensive, type-safe interface to the OpenAI API, supporting all major features including chat completions, embeddings, images, and audio generation. The SDK is built with modern Swift concurrency features and is designed to work seamlessly with SwiftUI and UIKit applications.

### Key Features

- **Modern Swift Design**: Built with Swift 6.0, using async/await and structured concurrency
- **Type Safety**: Full type safety with comprehensive error handling
- **Modular Architecture**: Use only the features you need by importing specific modules
- **SwiftUI Ready**: Observable wrapper for easy integration with SwiftUI
- **Thread-Safe**: Actor-based implementation for concurrent operations
- **Streaming Support**: Real-time streaming responses for chat completions
- **Structured Output**: Type-safe JSON schema generation for reliable outputs

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Installation>
- <doc:Authentication>

### Essential Types

- ``OpenAI``
- ``OpenAIActor``
- ``OpenAIObservable``

### Chat Completions

- <doc:ChatCompletions>
- ``ChatRequest``
- ``ChatResponse``
- ``ChatMessage``

### Embeddings

- <doc:Embeddings>
- ``EmbeddingRequest``
- ``EmbeddingResponse``

### Images

- <doc:ImageGeneration>
- ``ImageRequest``
- ``ImageResponse``

### Audio

- <doc:AudioGeneration>
- ``AudioRequest``
- ``AudioResponse``

### Structured Output

- <doc:StructuredOutput>
- ``StructuredOutputConvertible``

### Error Handling

- ``OpenAIError``
- <doc:ErrorHandling>

### Advanced Usage

- <doc:StreamingResponses>
- <doc:BatchOperations>
- <doc:RateLimiting>