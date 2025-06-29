# Getting Started

Learn how to set up and use OpenAISwift in your Swift applications.

## Overview

This guide walks you through the initial setup and basic usage of OpenAISwift. You'll learn how to authenticate with the OpenAI API and make your first API calls.

## Quick Start

### Step 1: Import the Framework

```swift
import OpenAISwift
```

### Step 2: Initialize the Client

```swift
let openAI = OpenAI(apiKey: "your-api-key")
```

### Step 3: Make Your First Request

```swift
let request = ChatRequest(
    model: "gpt-3.5-turbo",
    messages: [
        ChatMessage(role: .user, content: .text("Hello, OpenAI!"))
    ]
)

do {
    let response = try await openAI.createChatCompletion(request)
    if let message = response.choices.first?.message {
        print(message.content)
    }
} catch {
    print("Error: \(error)")
}
```

## Using with SwiftUI

OpenAISwift provides an Observable wrapper that integrates seamlessly with SwiftUI:

```swift
@StateObject private var openAI = OpenAIObservable(apiKey: "your-api-key")

var body: some View {
    VStack {
        ForEach(openAI.messages) { message in
            MessageView(message: message)
        }
        
        if openAI.isLoading {
            ProgressView()
        }
        
        TextField("Message", text: $messageText)
            .onSubmit {
                Task {
                    await openAI.sendMessage(messageText)
                    messageText = ""
                }
            }
    }
}
```

## Using the Actor-based Client

For thread-safe operations with automatic rate limiting:

```swift
let openAI = OpenAIActor(apiKey: "your-api-key", maxRequestsPerMinute: 60)

// Single request
let response = try await openAI.createChatCompletion(request)

// Batch requests
let results = try await openAI.batchCreateChatCompletions(requests, maxConcurrency: 3)
```

## Next Steps

- Learn about <doc:Authentication> options
- Explore <doc:ChatCompletions> in detail
- Understand <doc:ErrorHandling>
- Try <doc:StreamingResponses> for real-time updates