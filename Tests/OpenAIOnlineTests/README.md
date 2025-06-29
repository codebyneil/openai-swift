# OpenAISwift Tests

This directory contains comprehensive unit and integration tests for the OpenAISwift package using the Swift Testing framework.

## Test Structure

### Core Test Files

- **OpenAISwiftTests.swift** - Basic unit tests for fundamental types
- **ModelTests.swift** - Tests for all model types (Chat, Embeddings, Images, Audio, etc.)
- **OpenAIAPITests.swift** - Tests for the main API client functionality
- **OpenAIActorTests.swift** - Tests for the actor-based concurrent API
- **OpenAIObservableTests.swift** - Tests for the Observable wrapper

### Integration Tests

- **IntegrationTests.swift** - End-to-end tests with real API calls
- **ConcurrentOperationsTests.swift** - Tests for concurrent API operations
- **PerformanceTests.swift** - Performance benchmarks and measurements
- **ErrorHandlingTests.swift** - Error scenarios and edge cases

### Configuration

- **TestConstants.swift** - Contains API key and test configuration

## Running Tests

### Prerequisites

1. Add your OpenAI API key to `TestConstants.swift`:
```swift
enum TestConstants {
    static let apiKey = "YOUR_API_KEY_HERE"
}
```

2. Ensure you have sufficient API credits as tests make real API calls

### Running All Tests

```bash
swift test
```

### Running Specific Test Suites

```bash
swift test --filter OpenAIAPITests
swift test --filter IntegrationTests
```

### Running with Verbose Output

```bash
swift test --verbose
```

## Test Categories

### Unit Tests
- Model initialization and encoding/decoding
- Request/response structure validation
- Type safety checks
- Edge case handling

### Integration Tests
- Real API communication
- Multi-turn conversations
- Tool/function calling
- Streaming responses
- Embedding generation and similarity search

### Performance Tests
- Concurrent request handling
- Batch processing efficiency
- Memory usage tracking
- Token usage monitoring
- Streaming latency measurements

### Error Handling Tests
- Invalid API key handling
- Network error scenarios
- Rate limiting behavior
- Malformed response handling
- Token limit exceeded cases

## Important Notes

1. **API Costs**: These tests make real API calls and will incur costs on your OpenAI account
2. **Rate Limits**: Some tests may hit rate limits if run too frequently
3. **Network Dependency**: Tests require internet connectivity
4. **Platform Requirements**: iOS 17.0+ / macOS 14.0+ due to modern Swift concurrency features

## Test Patterns

### Async/Await Testing
```swift
@Test("Async operation")
func testAsyncOperation() async throws {
    let result = try await api.someAsyncMethod()
    #expect(result.success)
}
```

### Streaming Tests
```swift
@Test("Streaming response")
func testStreaming() async throws {
    let stream = try await api.createStream()
    for try await chunk in stream {
        // Process chunk
    }
}
```

### Error Expectation
```swift
@Test("Error handling")
func testErrorCase() async throws {
    do {
        _ = try await api.invalidOperation()
        Issue.record("Should have thrown")
    } catch {
        #expect(error is ExpectedError)
    }
}
```

## Contributing

When adding new tests:

1. Follow the existing naming conventions
2. Group related tests in appropriate suites
3. Use descriptive test names
4. Include both success and failure cases
5. Test edge cases and error conditions
6. Add performance tests for new features that might impact performance

## Debugging

To debug specific tests:

1. Use `print()` statements for quick debugging
2. Set breakpoints in Xcode
3. Use `--verbose` flag for detailed output
4. Check the `TestConstants.apiKey` is valid
5. Verify network connectivity

## CI/CD Considerations

For CI/CD pipelines:

1. Use environment variables for API keys
2. Consider using mock responses for some tests
3. Set appropriate timeouts for long-running tests
4. Monitor API usage and costs
5. Run performance tests separately from unit tests