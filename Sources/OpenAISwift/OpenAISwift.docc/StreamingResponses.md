# Streaming Responses

Receive chat completions in real-time as they're generated.

## Overview

Streaming allows you to receive partial responses as they're generated, providing a better user experience for long responses. This guide covers how to implement streaming in your applications.

## Basic Streaming

### Using Async Streams

```swift
var request = ChatRequest(
    model: "gpt-3.5-turbo",
    messages: messages,
    stream: true  // Enable streaming
)

let stream = try await openAI.createChatCompletionStream(request)

var fullResponse = ""
for try await chunk in stream {
    if let delta = chunk.choices.first?.delta,
       let content = delta.content {
        fullResponse += content
        print(content, terminator: "")  // Print as it arrives
    }
}
```

### With SwiftUI

Using the Observable wrapper for streaming:

```swift
struct ChatView: View {
    @StateObject private var openAI = OpenAIObservable(apiKey: "your-key")
    @State private var message = ""
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(openAI.messages) { message in
                    MessageBubble(message: message)
                }
                
                if !openAI.streamedContent.isEmpty {
                    Text(openAI.streamedContent)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            
            HStack {
                TextField("Message", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    Task {
                        await openAI.sendStreamingMessage(message)
                        message = ""
                    }
                }
                .disabled(openAI.isLoading)
            }
            .padding()
        }
    }
}
```

## Advanced Streaming Patterns

### Progress Tracking

```swift
class StreamingManager {
    func streamWithProgress(
        request: ChatRequest,
        onProgress: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async throws {
        let stream = try await openAI.createChatCompletionStream(request)
        
        var fullResponse = ""
        var chunkCount = 0
        
        for try await chunk in stream {
            chunkCount += 1
            
            if let delta = chunk.choices.first?.delta,
               let content = delta.content {
                fullResponse += content
                onProgress(content)
            }
            
            // Optional: Track streaming metrics
            if let usage = chunk.usage {
                print("Tokens used: \(usage.totalTokens)")
            }
        }
        
        onComplete(fullResponse)
        print("Received \(chunkCount) chunks")
    }
}
```

### Cancellable Streaming

```swift
class CancellableStream {
    private var streamTask: Task<Void, Error>?
    
    func startStreaming(request: ChatRequest) {
        streamTask = Task {
            do {
                let stream = try await openAI.createChatCompletionStream(request)
                
                for try await chunk in stream {
                    try Task.checkCancellation()
                    
                    // Process chunk
                    if let content = chunk.choices.first?.delta.content {
                        await MainActor.run {
                            updateUI(with: content)
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Stream error: \(error)")
                }
            }
        }
    }
    
    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
    }
}
```

## Error Handling in Streams

### Graceful Error Recovery

```swift
func streamWithRetry(request: ChatRequest, maxRetries: Int = 3) async {
    for attempt in 0..<maxRetries {
        do {
            let stream = try await openAI.createChatCompletionStream(request)
            
            for try await chunk in stream {
                // Process chunk
            }
            
            break  // Success, exit retry loop
            
        } catch {
            print("Stream attempt \(attempt + 1) failed: \(error)")
            
            if attempt < maxRetries - 1 {
                // Wait before retry with exponential backoff
                try? await Task.sleep(for: .seconds(pow(2, Double(attempt))))
            } else {
                // Final attempt failed
                await handleStreamError(error)
            }
        }
    }
}
```

### Stream Timeout

```swift
func streamWithTimeout(request: ChatRequest, timeout: TimeInterval = 30) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        // Streaming task
        group.addTask {
            let stream = try await openAI.createChatCompletionStream(request)
            for try await chunk in stream {
                // Process chunk
            }
        }
        
        // Timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(timeout))
            throw StreamError.timeout
        }
        
        // First task to complete wins
        try await group.next()
        group.cancelAll()
    }
}
```

## Performance Optimization

### Buffering Responses

```swift
actor StreamBuffer {
    private var buffer: String = ""
    private let updateThreshold = 10  // Update UI every 10 characters
    
    func addContent(_ content: String) async -> String? {
        buffer += content
        
        if buffer.count >= updateThreshold {
            let result = buffer
            buffer = ""
            return result
        }
        
        return nil
    }
    
    func flush() -> String {
        let result = buffer
        buffer = ""
        return result
    }
}
```

## Best Practices

1. **UI Updates**: Batch UI updates to avoid excessive redraws
2. **Error Handling**: Always handle stream interruptions gracefully
3. **Memory Management**: Clear accumulated responses when done
4. **User Experience**: Show streaming indicators to users
5. **Cancellation**: Provide users a way to stop long streams

## Common Issues

### Incomplete Responses

```swift
// Ensure you capture the complete response
var fullResponse = ""
var finishReason: String?

for try await chunk in stream {
    if let delta = chunk.choices.first?.delta {
        if let content = delta.content {
            fullResponse += content
        }
    }
    
    if let reason = chunk.choices.first?.finishReason {
        finishReason = reason
    }
}

// Check if response was cut off
if finishReason == "length" {
    print("Response was truncated due to token limit")
}
```

## See Also

- <doc:ChatCompletions>
- ``ChatRequest``
- ``ChatCompletionStreamResponse``