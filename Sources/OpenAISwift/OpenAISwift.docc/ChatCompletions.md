# Chat Completions

Generate text using OpenAI's chat models.

## Overview

Chat completions are the primary way to interact with OpenAI's language models. This guide covers how to create chat completions, manage conversations, and use advanced features.

## Basic Usage

### Simple Request

```swift
let request = ChatRequest(
    model: "gpt-3.5-turbo",
    messages: [
        ChatMessage(role: .user, content: .text("What is Swift?"))
    ]
)

let response = try await openAI.createChatCompletion(request)
print(response.choices.first?.message.content ?? "No response")
```

### Conversation Management

Maintain context across multiple interactions:

```swift
var messages: [ChatMessage] = [
    ChatMessage(role: .system, content: .text("You are a helpful assistant."))
]

// User message
messages.append(ChatMessage(role: .user, content: .text("What's the weather like?")))

// Get response
let request = ChatRequest(model: "gpt-3.5-turbo", messages: messages)
let response = try await openAI.createChatCompletion(request)

// Add assistant's response to conversation
if let assistantMessage = response.choices.first?.message {
    messages.append(assistantMessage)
}

// Continue conversation
messages.append(ChatMessage(role: .user, content: .text("What should I wear?")))
```

## Advanced Parameters

### Temperature and Creativity

```swift
let request = ChatRequest(
    model: "gpt-4",
    messages: messages,
    temperature: 0.7,  // 0.0 = deterministic, 2.0 = very creative
    topP: 0.9,         // Nucleus sampling
    maxTokens: 1000,   // Maximum response length
    presencePenalty: 0.6,  // Encourage diverse topics
    frequencyPenalty: 0.5  // Reduce repetition
)
```

### Multiple Choices

Generate multiple responses:

```swift
let request = ChatRequest(
    model: "gpt-3.5-turbo",
    messages: messages,
    n: 3  // Generate 3 different responses
)

let response = try await openAI.createChatCompletion(request)
for (index, choice) in response.choices.enumerated() {
    print("Option \(index + 1): \(choice.message.content ?? "")")
}
```

## Function Calling

Use function calling for structured interactions:

```swift
let function = ChatFunction(
    name: "get_weather",
    description: "Get the current weather for a location",
    parameters: [
        "type": "object",
        "properties": [
            "location": [
                "type": "string",
                "description": "The city and state"
            ],
            "unit": [
                "type": "string",
                "enum": ["celsius", "fahrenheit"]
            ]
        ],
        "required": ["location"]
    ]
)

let request = ChatRequest(
    model: "gpt-3.5-turbo",
    messages: messages,
    functions: [function],
    functionCall: .auto
)
```

## Multimodal Messages

Send images along with text (GPT-4 Vision):

```swift
let imageData = try Data(contentsOf: imageURL)
let base64Image = imageData.base64EncodedString()

let message = ChatMessage(
    role: .user,
    content: .array([
        .text("What's in this image?"),
        .imageURL(ChatMessage.ImageURL(
            url: "data:image/jpeg;base64,\(base64Image)"
        ))
    ])
)
```

## Response Format

Specify JSON response format:

```swift
let request = ChatRequest(
    model: "gpt-3.5-turbo",
    messages: messages,
    responseFormat: ResponseFormat(type: .jsonObject)
)
```

## Error Handling

Handle common errors gracefully:

```swift
do {
    let response = try await openAI.createChatCompletion(request)
    // Process response
} catch let error as OpenAIError {
    switch error {
    case .apiError(let errorResponse):
        print("API Error: \(errorResponse.error.message)")
    case .rateLimitExceeded:
        print("Rate limit exceeded, please wait")
    case .invalidResponse:
        print("Invalid response from API")
    default:
        print("Error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **System Messages**: Always include a system message to set the assistant's behavior
2. **Token Limits**: Monitor token usage to avoid hitting limits
3. **Context Management**: Trim old messages when conversations get long
4. **Error Recovery**: Implement retry logic for transient failures
5. **Response Validation**: Always validate responses before using them

## See Also

- <doc:StreamingResponses>
- <doc:StructuredOutput>
- ``ChatRequest``
- ``ChatResponse``
- ``ChatMessage``