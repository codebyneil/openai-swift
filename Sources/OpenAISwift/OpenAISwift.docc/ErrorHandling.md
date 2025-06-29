# Error Handling

Handle errors gracefully when using the OpenAI API.

## Overview

OpenAISwift provides comprehensive error handling to help you build robust applications. This guide covers the different types of errors you might encounter and how to handle them effectively.

## Error Types

### OpenAIError

The main error type that encapsulates all API-related errors:

```swift
public enum OpenAIError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(ErrorResponse)
    case decodingError(Error)
    case invalidURL
    case missingAPIKey
    case rateLimitExceeded
    case networkError(Error)
}
```

### Common Error Scenarios

```swift
do {
    let response = try await openAI.createChatCompletion(request)
    // Handle success
} catch let error as OpenAIError {
    switch error {
    case .apiError(let errorResponse):
        handleAPIError(errorResponse)
    case .rateLimitExceeded:
        handleRateLimit()
    case .networkError(let underlyingError):
        handleNetworkError(underlyingError)
    case .httpError(let statusCode):
        handleHTTPError(statusCode)
    case .invalidResponse:
        print("Invalid response format")
    case .decodingError(let error):
        print("Failed to decode response: \(error)")
    case .missingAPIKey:
        print("API key is missing")
    case .invalidURL:
        print("Invalid URL configuration")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## API Error Responses

### Understanding API Errors

```swift
func handleAPIError(_ errorResponse: ErrorResponse) {
    print("Error type: \(errorResponse.error.type)")
    print("Error message: \(errorResponse.error.message)")
    
    switch errorResponse.error.type {
    case "invalid_request_error":
        // Invalid parameters were provided
        print("Check your request parameters")
    case "authentication_error":
        // Invalid API key
        print("Check your API key")
    case "permission_error":
        // You don't have access to this resource
        print("Permission denied for this operation")
    case "not_found_error":
        // Requested resource doesn't exist
        print("Resource not found")
    case "rate_limit_error":
        // Too many requests
        print("Rate limit exceeded")
    case "api_error":
        // OpenAI service error
        print("OpenAI service error")
    default:
        print("Unknown error type")
    }
}
```

## Rate Limiting

### Handling Rate Limits

```swift
class RateLimitHandler {
    private var retryAfter: TimeInterval = 60
    
    func handleRateLimitError(_ error: Error) async throws {
        if case OpenAIError.apiError(let response) = error,
           response.error.type == "rate_limit_error" {
            
            // Extract retry-after from error message if available
            if let retryAfterMatch = response.error.message.firstMatch(
                of: /Please retry after (\d+) seconds/
            ) {
                retryAfter = Double(retryAfterMatch.1) ?? 60
            }
            
            print("Rate limited. Waiting \(retryAfter) seconds...")
            try await Task.sleep(for: .seconds(retryAfter))
            
            // Retry the request
            throw RetryableError.retryAfter(retryAfter)
        }
    }
}
```

### Exponential Backoff

```swift
func performRequestWithBackoff<T>(
    operation: () async throws -> T,
    maxRetries: Int = 5
) async throws -> T {
    var lastError: Error?
    
    for attempt in 0..<maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error
            
            // Check if error is retryable
            if isRetryableError(error) && attempt < maxRetries - 1 {
                let delay = pow(2.0, Double(attempt)) * 1.0  // Exponential backoff
                print("Attempt \(attempt + 1) failed, retrying in \(delay)s...")
                try await Task.sleep(for: .seconds(delay))
            } else {
                throw error
            }
        }
    }
    
    throw lastError ?? OpenAIError.invalidResponse
}

func isRetryableError(_ error: Error) -> Bool {
    guard let openAIError = error as? OpenAIError else { return false }
    
    switch openAIError {
    case .rateLimitExceeded, .httpError(let code) where [429, 500, 502, 503, 504].contains(code):
        return true
    case .networkError:
        return true
    default:
        return false
    }
}
```

## Network Errors

### Handling Connectivity Issues

```swift
extension OpenAIError {
    var isNetworkRelated: Bool {
        switch self {
        case .networkError, .httpError(let code) where code >= 500:
            return true
        default:
            return false
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .apiError(let response) where response.error.type == "insufficient_quota":
            return "You've exceeded your API quota. Please check your OpenAI account."
        case .missingAPIKey:
            return "API key not configured. Please add your OpenAI API key."
        case .invalidResponse:
            return "Received an invalid response. Please try again."
        default:
            return "An error occurred. Please try again later."
        }
    }
}
```

## Validation Errors

### Input Validation

```swift
extension ChatRequest {
    func validate() throws {
        // Validate model
        let validModels = ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo-preview"]
        guard validModels.contains(model) else {
            throw ValidationError.invalidModel(model)
        }
        
        // Validate messages
        guard !messages.isEmpty else {
            throw ValidationError.emptyMessages
        }
        
        // Validate parameters
        if let temp = temperature, temp < 0 || temp > 2 {
            throw ValidationError.invalidTemperature(temp)
        }
        
        if let maxTokens = maxTokens, maxTokens < 1 {
            throw ValidationError.invalidMaxTokens(maxTokens)
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidModel(String)
    case emptyMessages
    case invalidTemperature(Double)
    case invalidMaxTokens(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidModel(let model):
            return "Invalid model: \(model)"
        case .emptyMessages:
            return "Messages array cannot be empty"
        case .invalidTemperature(let temp):
            return "Temperature must be between 0 and 2, got \(temp)"
        case .invalidMaxTokens(let tokens):
            return "Max tokens must be positive, got \(tokens)"
        }
    }
}
```

## Error Recovery Strategies

### Graceful Degradation

```swift
class ChatService {
    private let openAI: OpenAI
    private let fallbackModel = "gpt-3.5-turbo"
    
    func sendMessage(_ message: String, preferredModel: String) async -> ChatResponse? {
        // Try with preferred model
        do {
            let request = ChatRequest(
                model: preferredModel,
                messages: [ChatMessage(role: .user, content: .text(message))]
            )
            return try await openAI.createChatCompletion(request)
        } catch {
            print("Preferred model failed: \(error)")
        }
        
        // Fallback to cheaper model
        do {
            let request = ChatRequest(
                model: fallbackModel,
                messages: [ChatMessage(role: .user, content: .text(message))]
            )
            return try await openAI.createChatCompletion(request)
        } catch {
            print("Fallback also failed: \(error)")
            return nil
        }
    }
}
```

## Best Practices

1. **Always handle errors**: Never ignore potential errors
2. **Provide user feedback**: Show meaningful error messages to users
3. **Log errors**: Keep track of errors for debugging
4. **Implement retry logic**: Use exponential backoff for transient errors
5. **Validate inputs**: Check parameters before making API calls
6. **Monitor quotas**: Track API usage to avoid quota errors

## See Also

- ``OpenAIError``
- ``ErrorResponse``
- <doc:RateLimiting>