# Rate Limiting

Manage API rate limits to ensure reliable operation.

## Overview

OpenAI enforces rate limits to ensure fair usage. OpenAISwift provides built-in mechanisms to handle these limits gracefully.

## Automatic Rate Limiting

The `OpenAIActor` class provides automatic rate limiting:

```swift
let openAI = OpenAIActor(
    apiKey: "your-key",
    maxRequestsPerMinute: 60  // Adjust based on your tier
)

// Requests are automatically throttled
for i in 1...100 {
    Task {
        let response = try await openAI.createChatCompletion(request)
        // Process response
    }
}
```

## Manual Rate Limiting

```swift
class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    private let lock = NSLock()
    
    init(maxRequests: Int, timeWindow: TimeInterval = 60) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func waitIfNeeded() async throws {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        requestTimes = requestTimes.filter { 
            now.timeIntervalSince($0) < timeWindow 
        }
        
        if requestTimes.count >= maxRequests {
            let oldestRequest = requestTimes[0]
            let waitTime = timeWindow - now.timeIntervalSince(oldestRequest)
            
            if waitTime > 0 {
                try await Task.sleep(for: .seconds(waitTime))
            }
        }
        
        requestTimes.append(Date())
    }
}
```

## Handling Rate Limit Errors

```swift
func handleRateLimitError(_ error: Error) async throws {
    guard case OpenAIError.apiError(let response) = error,
          response.error.type == "rate_limit_error" else {
        throw error
    }
    
    // Extract retry-after if available
    if let retryAfter = extractRetryAfter(from: response.error.message) {
        print("Rate limited. Waiting \(retryAfter) seconds...")
        try await Task.sleep(for: .seconds(retryAfter))
    } else {
        // Default wait time
        try await Task.sleep(for: .seconds(60))
    }
}
```

## Best Practices

1. **Know Your Limits**: Check your account's rate limits
2. **Use OpenAIActor**: It handles rate limiting automatically
3. **Implement Backoff**: Use exponential backoff for retries
4. **Monitor Usage**: Track your API usage to avoid surprises
5. **Queue Requests**: Use a queue system for high-volume applications

## See Also

- ``OpenAIActor``
- <doc:ErrorHandling>
- <doc:BatchOperations>