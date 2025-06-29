# Authentication

Configure authentication for the OpenAI API.

## Overview

OpenAISwift requires an API key to authenticate requests to the OpenAI API. This guide covers different approaches to managing your API credentials securely.

## Basic Authentication

The simplest way to authenticate is by providing your API key directly:

```swift
let openAI = OpenAI(apiKey: "your-api-key")
```

## Organization ID

If you're part of multiple organizations, you can specify which one to use:

```swift
let openAI = OpenAI(
    apiKey: "your-api-key",
    organization: "org-xxxxx"
)
```

## Security Best Practices

### Never Hard-code API Keys

```swift
// ❌ Don't do this
let openAI = OpenAI(apiKey: "sk-proj-xxxxx")

// ✅ Do this instead
let openAI = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "")
```

### Using Environment Variables

Store your API key in environment variables:

```swift
extension OpenAI {
    static func createFromEnvironment() throws -> OpenAI {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw OpenAIError.missingAPIKey
        }
        
        return OpenAI(
            apiKey: apiKey,
            organization: ProcessInfo.processInfo.environment["OPENAI_ORG_ID"]
        )
    }
}
```

### Using Keychain (iOS/macOS)

For production apps, store API keys in the Keychain:

```swift
import Security

class APIKeyManager {
    static func saveAPIKey(_ key: String) throws {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OpenAI-API-Key",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary) // Delete any existing
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
    
    static func getAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OpenAI-API-Key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.loadFailed
        }
        
        return key
    }
}
```

### Configuration Files

For development, use a configuration file that's excluded from version control:

1. Create `Config.xcconfig`:
```
OPENAI_API_KEY = your-api-key
```

2. Add to `.gitignore`:
```
Config.xcconfig
```

3. Load in your app:
```swift
struct Configuration {
    static let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
}
```

## Rate Limiting and Retry Configuration

Configure retry behavior and rate limiting when initializing:

```swift
let openAI = OpenAI(
    apiKey: apiKey,
    organization: nil,
    session: .shared,
    maxRetries: 3,
    retryDelay: 1.0
)

// Or with the actor-based client
let openAI = OpenAIActor(
    apiKey: apiKey,
    maxRetries: 3,
    retryDelay: 1.0,
    maxRequestsPerMinute: 60
)
```

## Custom URLSession

For advanced networking configurations:

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30
configuration.httpAdditionalHeaders = ["Custom-Header": "Value"]

let session = URLSession(configuration: configuration)
let openAI = OpenAI(apiKey: apiKey, session: session)
```