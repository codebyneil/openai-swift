# Type-Based Structured Output

Generate type-safe JSON responses using Swift types without creating instances.

## Overview

The type-based approach to structured output allows you to generate JSON schemas directly from Swift types, providing better ergonomics and eliminating the need for dummy instances with default values.

## Basic Usage

### Simple Type-Based Generation

```swift
struct WeatherInfo: Decodable {
    let temperature: Double
    let condition: String
    let humidity: Int
    let windSpeed: Double?
}

// Direct type-to-result conversion
let weather = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: [
        ChatMessage(role: .user, content: .text("What's the weather in San Francisco?"))
    ],
    responseType: WeatherInfo.self
)

print("Temperature: \(weather.temperature)°F")
print("Condition: \(weather.condition)")
```

## Schema Generation from Types

### Primitive Types

```swift
// Generate schemas for basic types
let stringSchema = StructuredOutputGenerator.generateSchema(for: String.self)
// → {"type": "string"}

let intSchema = StructuredOutputGenerator.generateSchema(for: Int.self)
// → {"type": "integer"}

let boolSchema = StructuredOutputGenerator.generateSchema(for: Bool.self)
// → {"type": "boolean"}
```

### Foundation Types

```swift
// Date with format
let dateSchema = StructuredOutputGenerator.generateSchema(for: Date.self)
// → {"type": "string", "format": "date-time"}

// URL with format
let urlSchema = StructuredOutputGenerator.generateSchema(for: URL.self)
// → {"type": "string", "format": "uri"}

// UUID with format
let uuidSchema = StructuredOutputGenerator.generateSchema(for: UUID.self)
// → {"type": "string", "format": "uuid"}
```

## Custom Schema Control

### Using StructuredOutputConvertible

```swift
struct ProductReview: Decodable, StructuredOutputConvertible {
    let productName: String
    let rating: Int
    let review: String
    let wouldRecommend: Bool
    
    static func generateStructuredOutput() -> [String: Any] {
        return [
            "type": "object",
            "properties": [
                "productName": [
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 100
                ],
                "rating": [
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 5
                ],
                "review": [
                    "type": "string",
                    "minLength": 10,
                    "maxLength": 500
                ],
                "wouldRecommend": ["type": "boolean"]
            ],
            "required": ["productName", "rating", "review", "wouldRecommend"],
            "additionalProperties": false
        ]
    }
}

// Use it the same way
let review = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: messages,
    responseType: ProductReview.self
)
```

## Custom Decoding Strategies

### Using StructuredResponse Wrapper

```swift
struct Event: Decodable {
    let name: String
    let date: Date
    let attendees: Int
}

// Get a structured response wrapper for custom decoding
let response = try await openAI.createChatCompletionStructured(
    model: "gpt-4",
    messages: messages,
    responseType: Event.self
)

// Configure custom decoder
let event = try response.decode { decoder in
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    decoder.dateDecodingStrategy = .formatted(formatter)
    decoder.keyDecodingStrategy = .convertFromSnakeCase
}
```

## Schema Builder DSL

### Declarative Schema Definition

```swift
@SchemaBuilder
func orderSchema() -> [PropertyDefinition] {
    string("orderId", pattern: "^ORD-[0-9]+$")
    number("totalAmount", minimum: 0)
    array("items", itemType: "object", minItems: 1)
    string("status", required: true)
    boolean("isPaid")
    integer("itemCount", minimum: 1, maximum: 100)
}

// Convert to response format
let properties = orderSchema()
let schema = SchemaBuilder.buildSchema(from: properties)
```

### Property Definition Helpers

```swift
// String with constraints
string("email", 
    minLength: 5, 
    maxLength: 100, 
    pattern: "^[^@]+@[^@]+\\.[^@]+$"
)

// Number with range
number("price", minimum: 0.01, maximum: 999999.99)

// Integer with bounds
integer("quantity", minimum: 1, maximum: 1000)

// Array with constraints
array("tags", itemType: "string", minItems: 1, maxItems: 10)

// Boolean (simple)
boolean("isActive")
```

## Common Patterns

### Text Analysis

```swift
struct TextAnalysis: Decodable {
    let sentiment: String
    let confidence: Double
    let keywords: [String]
    let summary: String
}

let analysis = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: [
        .user("Analyze this customer feedback: '\(feedbackText)'")
    ],
    responseType: TextAnalysis.self
)
```

### Data Extraction

```swift
struct CompanyInfo: Decodable {
    let name: String
    let revenue: Double?
    let employeeCount: Int?
    let headquarters: String
    let foundedYear: Int
}

let info = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: [
        .user("Extract company information from: '\(articleText)'")
    ],
    responseType: CompanyInfo.self
)
```

### Classification

```swift
struct Classification: Decodable {
    let category: String
    let confidence: Double
    let reasoning: String
}

let result = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: [
        .system("Classify support tickets: technical, billing, feature-request, other"),
        .user("Ticket: '\(ticketContent)'")
    ],
    responseType: Classification.self
)
```

## Error Handling

### Type-Safe Error Handling

```swift
do {
    let result = try await openAI.createChatCompletionTyped(
        model: "gpt-4",
        messages: messages,
        responseType: MyType.self
    )
    // Use result
} catch let error as OpenAIError {
    switch error {
    case .apiError(let apiError, _):
        print("API Error: \(apiError.error.message)")
    case .decodingError(let decodingError, _):
        print("Failed to decode: \(decodingError)")
    case .missingData:
        print("No data in response")
    default:
        print("Error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Advanced Features

### Nested Structures

```swift
struct Order: Decodable {
    struct Customer: Decodable {
        let name: String
        let email: String
    }
    
    struct Item: Decodable {
        let productId: String
        let quantity: Int
        let price: Double
    }
    
    let orderId: String
    let customer: Customer
    let items: [Item]
    let total: Double
}

let order = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: messages,
    responseType: Order.self
)
```

### Generic Response Handling

```swift
func getStructuredResponse<T: Decodable>(
    for prompt: String,
    responseType: T.Type
) async throws -> T {
    return try await openAI.createChatCompletionTyped(
        model: "gpt-4",
        messages: [.user(prompt)],
        responseType: responseType,
        temperature: 0.7
    )
}

// Use with any Decodable type
let weather = try await getStructuredResponse(
    for: "What's the weather?",
    responseType: WeatherInfo.self
)
```

## Migration Guide

### From Instance-Based to Type-Based

```swift
// Old approach (required instance)
let instance = MyType()
let schema = StructuredOutputGenerator.generateStructuredOutput(for: instance)

// New approach (type-based)
let schema = StructuredOutputGenerator.generateSchema(for: MyType.self)

// Old approach (manual decoding)
let response = try await openAI.createChatCompletion(request)
guard let content = response.choices.first?.message.content,
      let data = content.data(using: .utf8) else { throw error }
let result = try JSONDecoder().decode(MyType.self, from: data)

// New approach (automatic)
let result = try await openAI.createChatCompletionTyped(
    model: "gpt-4",
    messages: messages,
    responseType: MyType.self
)
```

## Best Practices

1. **Keep Types Simple**: Use flat structures when possible for better reliability
2. **Use Optional Properties**: Make properties optional when the API might not always provide them
3. **Add Constraints**: Use `StructuredOutputConvertible` to add validation constraints
4. **Handle Errors Gracefully**: Always handle potential decoding errors
5. **Test Your Schemas**: Verify that your schemas produce the expected JSON structure

## Performance Tips

1. **Reuse Types**: Define common response types once and reuse them
2. **Cache Schemas**: Store generated schemas if making many similar requests
3. **Use Appropriate Models**: Faster models like gpt-3.5-turbo work well for structured output
4. **Batch When Possible**: Process multiple items in a single request when feasible

## See Also

- ``StructuredOutputGenerator``
- ``StructuredResponse``
- ``SchemaBuilder``
- <doc:StructuredOutput>
- <doc:StructuredOutputSwiftData>