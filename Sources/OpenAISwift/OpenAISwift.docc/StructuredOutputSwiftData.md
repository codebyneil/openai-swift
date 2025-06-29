# SwiftData Structured Output Integration

Generate structured output for SwiftData models with OpenAI's API.

## Overview

The SwiftData integration allows you to use your SwiftData models as structured output schemas, enabling seamless integration between AI-generated content and your persistent data layer.

## Basic SwiftData Support

### Using SwiftData Models

```swift
import SwiftData

@Model
class Task {
    var title: String
    var completed: Bool
    var priority: Int
    var dueDate: Date?
    
    init(title: String = "", completed: Bool = false, priority: Int = 0) {
        self.title = title
        self.completed = completed
        self.priority = priority
    }
}

// Generate structured output for SwiftData model
let taskData = try await openAI.createChatCompletion(
    model: "gpt-4",
    messages: [
        .user("Create a task to review the quarterly report by next Friday")
    ],
    swiftDataModel: Task.self
)

// Use the data to populate your SwiftData model
// Note: You'll need to handle the actual model creation in your ModelContext
```

## Custom Schema Generation

### SwiftDataStructuredOutput Protocol

For better control over schema generation, implement the `SwiftDataStructuredOutput` protocol:

```swift
@Model
class Product: SwiftDataStructuredOutput {
    var name: String
    var price: Double
    var inStock: Bool
    var category: String
    
    init(name: String = "", price: Double = 0, inStock: Bool = true, category: String = "") {
        self.name = name
        self.price = price
        self.inStock = inStock
        self.category = category
    }
    
    static func generateStructuredOutput() -> [String: Any] {
        return [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 200,
                    "description": "Product display name"
                ],
                "price": [
                    "type": "number",
                    "minimum": 0,
                    "maximum": 999999.99,
                    "description": "Price in USD"
                ],
                "inStock": [
                    "type": "boolean",
                    "description": "Whether the product is available"
                ],
                "category": [
                    "type": "string",
                    "enum": ["electronics", "clothing", "food", "books", "other"]
                ]
            ],
            "required": ["name", "price", "inStock", "category"]
        ]
    }
    
    static var structuredOutputDescription: String? {
        "E-commerce product information"
    }
}
```

## Data Conversion

### Converting API Responses to SwiftData

```swift
// Configure conversion for API responses
let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
    dateDecodingStrategy: .iso8601,
    keyDecodingStrategy: .convertFromSnakeCase
)

// Convert the response
let convertedData = StructuredOutputToSwiftData.convert(
    taskData,
    using: configuration
)

// Use with your ModelContext
let task = Task()
task.title = convertedData["title"] as? String ?? ""
task.completed = convertedData["completed"] as? Bool ?? false
task.priority = convertedData["priority"] as? Int ?? 0
task.dueDate = convertedData["dueDate"] as? Date
```

### Property Mapping

```swift
let mappings = [
    StructuredOutputToSwiftData.PropertyMapping(
        jsonKey: "task_name",
        modelProperty: "title"
    ),
    StructuredOutputToSwiftData.PropertyMapping(
        jsonKey: "is_complete",
        modelProperty: "completed",
        transformer: { value in
            // Convert string to boolean
            return (value as? String)?.lowercased() == "yes"
        }
    ),
    StructuredOutputToSwiftData.PropertyMapping(
        jsonKey: "importance_level",
        modelProperty: "priority",
        transformer: { value in
            // Convert string to numeric priority
            switch value as? String {
            case "low": return 1
            case "medium": return 3
            case "high": return 5
            default: return 0
            }
        }
    )
]

let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
    propertyMappings: mappings
)
```

## Handling Relationships

### Models with Relationships

```swift
@Model
class Author: SwiftDataStructuredOutput {
    var name: String
    var email: String
    
    @Relationship(deleteRule: .cascade)
    var books: [Book]
    
    init(name: String = "", email: String = "") {
        self.name = name
        self.email = email
        self.books = []
    }
    
    static func generateStructuredOutput() -> [String: Any] {
        return [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "email": ["type": "string", "format": "email"],
                "books": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "isbn": ["type": "string"],
                            "publishedYear": ["type": "integer"]
                        ]
                    ]
                ]
            ],
            "required": ["name", "email"]
        ]
    }
}

@Model
class Book {
    var title: String
    var isbn: String
    var publishedYear: Int
    
    @Relationship(inverse: \Author.books)
    var author: Author?
    
    init(title: String = "", isbn: String = "", publishedYear: Int = 0) {
        self.title = title
        self.isbn = isbn
        self.publishedYear = publishedYear
    }
}
```

## Real-World Example

### Recipe Management System

```swift
@Model
class Recipe: SwiftDataStructuredOutput {
    var name: String
    var cookingTime: Int // minutes
    var difficulty: String
    var servings: Int
    
    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]
    
    @Relationship(deleteRule: .cascade)
    var instructions: [Instruction]
    
    init(name: String = "", cookingTime: Int = 0, difficulty: String = "medium", servings: Int = 4) {
        self.name = name
        self.cookingTime = cookingTime
        self.difficulty = difficulty
        self.servings = servings
        self.ingredients = []
        self.instructions = []
    }
    
    static func generateStructuredOutput() -> [String: Any] {
        return [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Name of the recipe"
                ],
                "cookingTime": [
                    "type": "integer",
                    "minimum": 1,
                    "description": "Total cooking time in minutes"
                ],
                "difficulty": [
                    "type": "string",
                    "enum": ["easy", "medium", "hard"]
                ],
                "servings": [
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 20
                ],
                "ingredients": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "amount": ["type": "string"],
                            "unit": ["type": "string"]
                        ],
                        "required": ["name", "amount"]
                    ]
                ],
                "instructions": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "step": ["type": "integer"],
                            "description": ["type": "string"]
                        ],
                        "required": ["step", "description"]
                    ]
                ]
            ],
            "required": ["name", "cookingTime", "difficulty", "ingredients", "instructions"]
        ]
    }
}

// Usage
let recipeData = try await openAI.createChatCompletion(
    model: "gpt-4",
    messages: [
        .user("Give me a recipe for chocolate chip cookies")
    ],
    swiftDataModel: Recipe.self
)

// Process the response
let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
    keyDecodingStrategy: .convertFromSnakeCase
)
let convertedData = StructuredOutputToSwiftData.convert(recipeData, using: configuration)
```

## Date Handling

### Custom Date Decoding

```swift
// ISO8601 (default)
let iso8601Config = StructuredOutputToSwiftData.ConversionConfiguration(
    dateDecodingStrategy: .iso8601
)

// Unix timestamp
let timestampConfig = StructuredOutputToSwiftData.ConversionConfiguration(
    dateDecodingStrategy: .secondsSince1970
)

// Custom format
let customConfig = StructuredOutputToSwiftData.ConversionConfiguration(
    dateDecodingStrategy: .custom { dateString in
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: dateString)
    }
)
```

## Best Practices

### 1. Use Protocol Conformance

Always implement `SwiftDataStructuredOutput` for better schema control:

```swift
@Model
class MyModel: SwiftDataStructuredOutput {
    // ... properties ...
    
    static func generateStructuredOutput() -> [String: Any] {
        // Custom schema definition
    }
}
```

### 2. Handle Optional Properties

Make properties optional when they might not always be provided:

```swift
@Model
class Event {
    var name: String
    var date: Date
    var location: String?
    var description: String?
    var attendeeCount: Int?
}
```

### 3. Validate Data Before Saving

Always validate the converted data before creating SwiftData models:

```swift
func createTask(from data: [String: Any], in context: ModelContext) throws -> Task {
    guard let title = data["title"] as? String, !title.isEmpty else {
        throw ValidationError.missingRequiredField("title")
    }
    
    let task = Task()
    task.title = title
    task.completed = data["completed"] as? Bool ?? false
    task.priority = data["priority"] as? Int ?? 0
    
    context.insert(task)
    return task
}
```

## Limitations

### Current Limitations

1. **Schema Introspection**: Cannot automatically introspect SwiftData model properties due to BackingData requirements
2. **Property Wrappers**: SwiftData property wrappers (@Attribute, @Relationship) require manual schema definition
3. **Model Creation**: Cannot directly create SwiftData models from JSON; requires manual property setting

### Workarounds

1. Use `SwiftDataStructuredOutput` protocol for explicit schema definition
2. Create factory methods for model creation from dictionaries
3. Use property mapping for complex transformations

## Error Handling

```swift
enum SwiftDataConversionError: Error {
    case missingRequiredField(String)
    case invalidFieldType(field: String, expected: String, actual: String)
    case relationshipCreationFailed(String)
}

func handleStructuredOutput<T: PersistentModel>(
    _ data: [String: Any],
    modelType: T.Type,
    context: ModelContext
) throws -> T {
    // Validate required fields
    // Convert data types
    // Create model instance
    // Handle relationships
    // Insert into context
}
```

## See Also

- ``SwiftDataStructuredOutput``
- ``StructuredOutputToSwiftData``
- ``SwiftDataModelBuilder``
- <doc:StructuredOutput>
- <doc:StructuredOutputTypeBased>