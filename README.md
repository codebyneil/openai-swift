# OpenAISwift

A comprehensive Swift package for the OpenAI API, providing easy-to-use methods for chat completions, embeddings, image generation, audio transcription, and more.

## Features

- ✅ Chat Completions (including streaming)
- ✅ Function Calling and Tool Use
- ✅ Models listing
- ✅ Embeddings
- ✅ Image Generation, Editing, and Variations
- ✅ Audio Transcription and Translation
- ✅ Error handling with automatic retry logic
- ✅ Async/await support
- ✅ Cross-platform (iOS, macOS, tvOS, watchOS)

## Installation

### Swift Package Manager

Add this package to your project by adding the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/OpenAISwift.git", from: "1.0.0")
]
```

Or in Xcode, go to File → Add Package Dependencies and enter the repository URL.

## Quick Start

```swift
import OpenAISwift

// Initialize the API client
let openAI = OpenAIAPI(apiKey: "your-api-key")

// Create a simple chat completion
let request = ChatRequest(
    model: "gpt-4",
    messages: [
        ChatMessage(role: .system, content: .text("You are a helpful assistant.")),
        ChatMessage(role: .user, content: .text("Hello, how are you?"))
    ]
)

do {
    let response = try await openAI.createChatCompletion(request)
    if let message = response.choices.first?.message.content {
        print(message)
    }
} catch {
    print("Error: \(error)")
}
```

## Usage Examples

### Chat Completions

```swift
// Basic chat completion
let request = ChatRequest(
    model: "gpt-4",
    messages: [
        ChatMessage(role: .user, content: .text("What is the capital of France?"))
    ],
    temperature: 0.7,
    maxTokens: 150
)

let response = try await openAI.createChatCompletion(request)
```

### Streaming Chat Completions

```swift
let request = ChatRequest(
    model: "gpt-4",
    messages: [
        ChatMessage(role: .user, content: .text("Tell me a story"))
    ]
)

let stream = try await openAI.createChatCompletionStream(request)
for try await chunk in stream {
    if let content = chunk.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### Function Calling

```swift
let function = FunctionDefinition(
    name: "get_weather",
    description: "Get the current weather in a location",
    parameters: [
        "type": "object",
        "properties": [
            "location": [
                "type": "string",
                "description": "The city and state"
            ]
        ],
        "required": ["location"]
    ]
)

let request = ChatRequest(
    model: "gpt-4",
    messages: [
        ChatMessage(role: .user, content: .text("What's the weather in New York?"))
    ],
    tools: [ChatTool(function: function)],
    toolChoice: .auto
)
```

### Image Generation

```swift
let imageRequest = ImageGenerationRequest(
    prompt: "A beautiful sunset over mountains",
    model: "dall-e-3",
    size: .size1024x1024,
    quality: .hd,
    n: 1
)

let imageResponse = try await openAI.createImage(imageRequest)
if let imageURL = imageResponse.data.first?.url {
    print("Generated image URL: \(imageURL)")
}
```

### Audio Transcription

```swift
let audioData = try Data(contentsOf: audioFileURL)
let transcriptionRequest = TranscriptionRequest(
    file: audioData,
    model: "whisper-1",
    language: "en"
)

let transcription = try await openAI.createTranscription(transcriptionRequest)
print("Transcription: \(transcription.text)")
```

### Embeddings

```swift
let embeddingRequest = EmbeddingRequest(
    input: .text("Hello, world!"),
    model: "text-embedding-ada-002"
)

let embeddingResponse = try await openAI.createEmbedding(embeddingRequest)
let embedding = embeddingResponse.data.first?.embedding
```

### List Available Models

```swift
let models = try await openAI.listModels()
for model in models.data {
    print("Model: \(model.id)")
}
```

## Advanced Configuration

### Custom Session and Retry Logic

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30

let openAI = OpenAIAPI(
    apiKey: "your-api-key",
    organization: "your-org-id", // Optional
    session: URLSession(configuration: configuration),
    maxRetries: 5,
    retryDelay: 2.0
)
```

## Error Handling

The package provides comprehensive error handling:

```swift
do {
    let response = try await openAI.createChatCompletion(request)
} catch OpenAIError.apiError(let errorResponse) {
    print("API Error: \(errorResponse.error.message)")
} catch OpenAIError.httpError(let statusCode) {
    print("HTTP Error: \(statusCode)")
} catch OpenAIError.decodingError(let error) {
    print("Decoding Error: \(error)")
} catch {
    print("Unknown Error: \(error)")
}
```

## Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.9+

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Generating Mock Fixtures for Tests

This package provides an executable utility that hits the live OpenAI endpoints and records their JSON responses to disk.  These fixtures can then be loaded by the `OpenAISwiftMockTests` target so your unit tests can run completely offline.

### 1. Prerequisites

• A valid `OPENAI_API_KEY` with access to the models you plan to hit.  
• (Optional) If your account uses multiple organisations, set `OPENAI_ORGANIZATION` as well.

### 2. Running the script

From the `OpenAISwift` package directory:

```bash
export OPENAI_API_KEY="sk-..."            # and optionally OPENAI_ORGANIZATION

# Build & run the utility
swift run GenerateOpenAIMocks
```

### 3. What it does

The script will:

1. Call several representative API endpoints (chat completions, chat completions with function calling, embeddings, image generation, model listing).
2. Capture the raw JSON responses.
3. Write them to:

OpenAISwift/Tests/OpenAISwiftMockTests/Fixtures/<endpoint>.json

Each file name corresponds to the logical endpoint (`chat_completion.json`, `embedding.json`, etc.).  You can freely open/edit these files to trim down unneeded fields or add additional examples.

### 4. Extending the script

`Scripts/GenerateOpenAIMocks/main.swift` is straightforward Swift code—add more `case` values to the `Endpoint` enum and expand the `switch` to capture additional endpoints (e.g. audio, image edits, moderation).

### 5. Using the fixtures in tests

In `OpenAISwiftMockTests`, load the JSON fixture and decode it into the appropriate response type, e.g.

```swift
let data = try Data(contentsOf: fixtureURL("chat_completion"))
let response = try JSONDecoder().decode(ChatResponse.self, from: data)
// Assert on `response` as usual
```

Helper functions to locate fixtures can be added to your mock test suite according to your project style.