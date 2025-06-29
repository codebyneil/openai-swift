# OpenAISwift Tests

## Running Tests

### Offline Tests
The offline tests don't require an API key and can be run directly:

```bash
swift test --filter OpenAIOfflineTests
```

### Online Tests (Live API Tests)
The online tests require a valid OpenAI API key. Set the `OPENAI_API_KEY` environment variable before running:

```bash
export OPENAI_API_KEY="your-api-key-here"
swift test --filter OpenAIOnlineTests
```

Or run with the environment variable inline:

```bash
OPENAI_API_KEY="your-api-key-here" swift test --filter OpenAIOnlineTests
```

### Running All Tests
To run all tests (both offline and online):

```bash
OPENAI_API_KEY="your-api-key-here" swift test
```

If you don't provide an API key, the online tests will be skipped automatically.

## Test Organization

- **OpenAIOfflineTests**: Tests that don't require API access
  - Mock API tests
  - Model type tests
  - Structured output tests
  - SwiftData integration tests (offline)
  
- **OpenAIOnlineTests**: Tests that make actual API calls
  - Chat completion tests
  - Image generation tests
  - Embedding tests
  - Error handling tests
  - Performance tests
  - Integration tests

## Troubleshooting

### API Key Not Working
If you're getting authentication errors:
1. Ensure your API key is valid
2. Check that the key has proper permissions
3. Verify you haven't exceeded rate limits

### Test Timeouts
Some tests may timeout on slow connections. You can adjust timeouts in `TestConstants.swift`:
- `testTimeout`: Default timeout for most tests (30 seconds)
- `streamTimeout`: Timeout for streaming operations (60 seconds)

### SwiftData Tests
SwiftData tests require iOS 17.0+ or macOS 14.0+. These tests use compile-time checks and will be automatically excluded on older platforms.