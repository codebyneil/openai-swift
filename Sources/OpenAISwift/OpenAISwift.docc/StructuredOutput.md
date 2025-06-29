# Structured Output

Generate reliable, type-safe JSON output from language models.

## Overview

Structured Output ensures that model responses conform to your specified JSON schema. This feature is essential for building reliable applications that need to parse model outputs programmatically.

## Basic Usage

### Define Your Output Structure

```swift
struct WeatherResponse: StructuredOutputConvertible {
    let temperature: Double
    let conditions: String
    let humidity: Int
    let windSpeed: Double
    
    @Required
    let location: String
    
    @StringEnum(["sunny", "cloudy", "rainy", "snowy"])
    let forecast: String
}
```

### Generate Structured Output

```swift
let request = ChatRequest(
    model: "gpt-4-turbo-preview",
    messages: [
        ChatMessage(
            role: .user,
            content: .text("What's the weather in San Francisco?")
        )
    ],
    responseFormat: try WeatherResponse.responseFormat()
)

let response = try await openAI.createChatCompletion(request)
if let content = response.choices.first?.message.content,
   let data = content.data(using: .utf8) {
    let weather = try JSONDecoder().decode(WeatherResponse.self, from: data)
    print("Temperature: \(weather.temperature)°F")
    print("Conditions: \(weather.conditions)")
}
```

## Property Wrappers

### @Required

Mark properties that must always be present:

```swift
struct UserProfile: StructuredOutputConvertible {
    @Required
    let id: String
    
    @Required
    let email: String
    
    let nickname: String?  // Optional
}
```

### @StringEnum

Constrain string values to specific options:

```swift
struct Task: StructuredOutputConvertible {
    @Required
    let title: String
    
    @StringEnum(["low", "medium", "high"])
    let priority: String
    
    @StringEnum(["todo", "in-progress", "done"])
    let status: String
}
```

### @Description

Add descriptions to help the model understand fields:

```swift
struct Product: StructuredOutputConvertible {
    @Required
    @Description("Unique product identifier")
    let id: String
    
    @Required
    @Description("Product name as shown to customers")
    let name: String
    
    @Description("Price in USD, including cents (e.g., 19.99)")
    let price: Double
    
    @Description("Whether the product is currently available for purchase")
    let inStock: Bool
}
```

## Complex Structures

### Nested Objects

```swift
struct Address: StructuredOutputConvertible {
    let street: String
    let city: String
    let state: String
    let zipCode: String
}

struct Customer: StructuredOutputConvertible {
    @Required
    let name: String
    
    @Required
    let email: String
    
    let shippingAddress: Address
    let billingAddress: Address?
}
```

### Arrays and Collections

```swift
struct ShoppingCart: StructuredOutputConvertible {
    struct Item: StructuredOutputConvertible {
        let productId: String
        let quantity: Int
        let price: Double
    }
    
    @Required
    let items: [Item]
    
    @Required
    let subtotal: Double
    
    let taxAmount: Double
    let shippingCost: Double
    
    @Required
    let total: Double
}
```

## Advanced Usage

### Custom Validation

```swift
struct EmailList: StructuredOutputConvertible {
    @Required
    let emails: [String]
    
    static func responseFormat() throws -> ResponseFormat {
        var schema = try defaultResponseFormat()
        
        // Add pattern validation for emails
        if var properties = schema.jsonSchema["properties"] as? [String: Any],
           var emailsSchema = properties["emails"] as? [String: Any],
           var items = emailsSchema["items"] as? [String: Any] {
            items["pattern"] = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
            emailsSchema["items"] = items
            properties["emails"] = emailsSchema
            schema.jsonSchema["properties"] = properties
        }
        
        return schema
    }
}
```

### Dynamic Schemas

```swift
class DynamicStructuredOutput {
    static func createSchema(for fields: [(name: String, type: String, required: Bool)]) -> ResponseFormat {
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for field in fields {
            let schema: [String: Any] = ["type": field.type]
            properties[field.name] = schema
            
            if field.required {
                required.append(field.name)
            }
        }
        
        return ResponseFormat(
            type: .jsonObject,
            jsonSchema: [
                "type": "object",
                "properties": properties,
                "required": required
            ]
        )
    }
}
```

## Error Handling

### Validation Errors

```swift
do {
    let responseFormat = try MyStruct.responseFormat()
    // Use the format
} catch {
    print("Schema generation failed: \(error)")
}
```

### Parsing Errors

```swift
func parseStructuredResponse<T: StructuredOutputConvertible>(
    _ type: T.Type,
    from response: ChatResponse
) throws -> T {
    guard let content = response.choices.first?.message.content else {
        throw StructuredOutputError.noContent
    }
    
    guard let data = content.data(using: .utf8) else {
        throw StructuredOutputError.invalidEncoding
    }
    
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        // Log the raw content for debugging
        print("Failed to parse: \(content)")
        throw StructuredOutputError.decodingFailed(error)
    }
}
```

## Best Practices

1. **Clear Descriptions**: Use `@Description` to provide clear field descriptions
2. **Required Fields**: Mark essential fields with `@Required`
3. **Enums for Constraints**: Use `@StringEnum` for fields with limited options
4. **Validation**: Add custom validation in `responseFormat()` when needed
5. **Error Handling**: Always handle potential parsing errors
6. **Model Selection**: Use models that support JSON mode (e.g., gpt-4-turbo-preview)

## Real-World Example

```swift
// Define a structured output for a recipe
struct Recipe: StructuredOutputConvertible {
    @Required
    @Description("Name of the dish")
    let name: String
    
    @Required
    @Description("Total time in minutes")
    let cookingTime: Int
    
    @Required
    @StringEnum(["easy", "medium", "hard"])
    let difficulty: String
    
    struct Ingredient: StructuredOutputConvertible {
        @Required
        let name: String
        
        @Required
        let amount: String
        
        let unit: String?
    }
    
    @Required
    let ingredients: [Ingredient]
    
    @Required
    @Description("Step-by-step cooking instructions")
    let instructions: [String]
    
    @Description("Nutritional information per serving")
    let nutrition: Nutrition?
    
    struct Nutrition: StructuredOutputConvertible {
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
    }
}

// Use it
let request = ChatRequest(
    model: "gpt-4-turbo-preview",
    messages: [
        ChatMessage(
            role: .user,
            content: .text("Give me a recipe for chocolate chip cookies")
        )
    ],
    responseFormat: try Recipe.responseFormat()
)

let response = try await openAI.createChatCompletion(request)
let recipe = try parseStructuredResponse(Recipe.self, from: response)
print("Recipe: \(recipe.name)")
print("Difficulty: \(recipe.difficulty)")
print("Time: \(recipe.cookingTime) minutes")
```

## See Also

- ``StructuredOutputConvertible``
- ``ResponseFormat``
- <doc:ChatCompletions>
- <doc:StructuredOutputTypeBased>
- <doc:StructuredOutputSwiftData>