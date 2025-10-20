import Foundation
import Testing

@testable import OpenAIStructuredOutput
@testable import OpenAISwift

#if canImport(SwiftData)
    import SwiftData
#endif

#if canImport(SwiftData)

    // MARK: - Test Models for Live Tests

    @Model
    class LiveTestProduct {
        var name: String
        var price: Double
        var inStock: Bool
        var category: String?
        var productDescription: String?

        init(name: String = "", price: Double = 0.0, inStock: Bool = true) {
            self.name = name
            self.price = price
            self.inStock = inStock
        }
    }

    @Model
    class LiveTestRecipe: SwiftDataStructuredOutput {
        var title: String
        var servings: Int
        var prepTime: Int  // in minutes
        var ingredients: [String]
        var instructions: [String]
        var difficulty: String

        init(title: String = "", servings: Int = 1, prepTime: Int = 0) {
            self.title = title
            self.servings = servings
            self.prepTime = prepTime
            self.ingredients = []
            self.instructions = []
            self.difficulty = "medium"
        }

        static func generateStructuredOutput() -> [String: Any] {
            return [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 100,
                    ],
                    "servings": [
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 20,
                    ],
                    "prepTime": [
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 480,
                        "description": "Preparation time in minutes",
                    ],
                    "ingredients": [
                        "type": "array",
                        "items": ["type": "string"],
                        "minItems": 1,
                        "maxItems": 20,
                    ],
                    "instructions": [
                        "type": "array",
                        "items": ["type": "string"],
                        "minItems": 1,
                        "maxItems": 15,
                    ],
                    "difficulty": [
                        "type": "string",
                        "enum": ["easy", "medium", "hard"],
                    ],
                ],
                "required": [
                    "title", "servings", "prepTime", "ingredients", "instructions", "difficulty",
                ],
            ]
        }

        static var structuredOutputDescription: String? {
            "A cooking recipe with ingredients and instructions"
        }
    }

    @Model
    class Event {
        var name: String
        var startDate: String  // We'll get ISO8601 string from API
        var endDate: String
        var location: String
        var attendeeCount: Int

        init(
            name: String = "", startDate: String = "", endDate: String = "", location: String = "",
            attendeeCount: Int = 0
        ) {
            self.name = name
            self.startDate = startDate
            self.endDate = endDate
            self.location = location
            self.attendeeCount = attendeeCount
        }
    }

    @Model
    class InvalidModel {
        var value: String

        init(value: String = "") {
            self.value = value
        }
    }

    @Model
    class TaskWithStatus {
        var title: String
        var status: String  // Store as string, convert to enum in app
        var priority: Int

        init(title: String = "", status: String = "pending", priority: Int = 0) {
            self.title = title
            self.status = status
            self.priority = priority
        }
    }

    // MARK: - Live Tests

    @Suite("SwiftData Structured Output Live Tests")
    struct SwiftDataStructuredOutputLiveTests {
        let api: OpenAI

        init() {
            self.api = OpenAI(apiKey: TestConstants.apiKey)
        }

        @Test("Generate data for simple SwiftData model")
        func testSimpleSwiftDataModel() async throws {
            try requireLiveTests()
            let messages = [
                ChatMessage(
                    role: .system,
                    content: .text(
                        "You are a product data generator. Always respond with JSON containing name (string), price (number with decimals), inStock (boolean), category (optional string), and description (optional string)."
                    )
                ),
                ChatMessage(
                    role: .user,
                    content: .text("Generate data for a high-end laptop computer.")
                ),
            ]

            let productData = try await api.createChatCompletion(
                model: "gpt-4o-mini",
                messages: messages,
                swiftDataModel: LiveTestProduct.self,
                temperature: 0.0
            )

            #expect(productData["name"] as? String != nil)
            #expect(productData["price"] as? Double != nil || productData["price"] as? Int != nil)
            #expect(productData["inStock"] as? Bool != nil)

            if let price = productData["price"] as? Double {
                #expect(price > 0)
            } else if let price = productData["price"] as? Int {
                #expect(price > 0)
            }

            if let name = productData["name"] as? String {
                #expect(
                    name.lowercased().contains("laptop") || name.lowercased().contains("computer"))
            }
        }

        @Test("Generate data for SwiftData model with custom schema")
        func testSwiftDataModelWithCustomSchema() async throws {
            try requireLiveTests()
            let messages = [
                ChatMessage(
                    role: .user,
                    content: .text("Create a recipe for chocolate chip cookies.")
                )
            ]

            let recipeData = try await api.createChatCompletion(
                model: "gpt-4o-mini",
                messages: messages,
                swiftDataModel: LiveTestRecipe.self,
                temperature: 0.0
            )

            // Verify required fields
            #expect(recipeData["title"] as? String != nil)
            #expect(recipeData["servings"] as? Int != nil)
            #expect(recipeData["prepTime"] as? Int != nil)
            #expect(recipeData["ingredients"] as? [String] != nil)
            #expect(recipeData["instructions"] as? [String] != nil)
            #expect(recipeData["difficulty"] as? String != nil)

            // Verify constraints
            if let servings = recipeData["servings"] as? Int {
                #expect(servings >= 1 && servings <= 20)
            }

            if let prepTime = recipeData["prepTime"] as? Int {
                #expect(prepTime >= 1 && prepTime <= 480)
            }

            if let ingredients = recipeData["ingredients"] as? [String] {
                #expect(ingredients.count >= 1 && ingredients.count <= 20)
                #expect(
                    ingredients.contains {
                        $0.lowercased().contains("chocolate") || $0.lowercased().contains("chip")
                    })
            }

            if let difficulty = recipeData["difficulty"] as? String {
                #expect(["easy", "medium", "hard"].contains(difficulty))
            }
        }

        @Test("Generate array of SwiftData models")
        func testArrayOfSwiftDataModels() async throws {
            try requireLiveTests()
            struct ProductList: Decodable {
                let products: [[String: Any]]

                enum CodingKeys: String, CodingKey {
                    case products
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    // Decode as array of Any and cast
                    if let array = try? container.decode([AnyCodable].self, forKey: .products) {
                        self.products = array.compactMap { $0.value as? [String: Any] }
                    } else {
                        self.products = []
                    }
                }
            }

            let messages = [
                ChatMessage(
                    role: .user,
                    content: .text(
                        "Generate a JSON object with a 'products' array containing 3 different electronic products. Each product should have name (string), price (number), inStock (boolean), and category (string)."
                    )
                )
            ]

            // Use regular structured output since we need a wrapper object
            let listData = try await api.createChatCompletion(
                model: "gpt-4o-mini",
                messages: messages,
                responseType: ProductList.self,
                temperature: 0.0
            )

            #expect(listData.products.count == 3)

            for product in listData.products {
                #expect(product["name"] as? String != nil)
                #expect(product["price"] != nil)
                #expect(product["inStock"] as? Bool != nil)
                #expect(product["category"] as? String != nil)
            }
        }

        @Test("SwiftData model with date handling")
        func testSwiftDataModelWithDates() async throws {
            try requireLiveTests()

            let messages = [
                ChatMessage(
                    role: .user,
                    content: .text(
                        "Create an event JSON for a tech conference happening next month. Include name, startDate (ISO8601), endDate (ISO8601), location, and attendeeCount (integer)."
                    )
                )
            ]

            let eventData = try await api.createChatCompletion(
                model: "gpt-4o-mini",
                messages: messages,
                swiftDataModel: Event.self,
                temperature: 0.0
            )

            #expect(eventData["name"] as? String != nil)
            #expect(eventData["location"] as? String != nil)
            #expect(eventData["attendeeCount"] as? Int != nil)

            // Verify date format
            if let startDate = eventData["startDate"] as? String {
                #expect(startDate.contains("T"))  // Basic ISO8601 check
                #expect(ISO8601DateFormatter().date(from: startDate) != nil)
            }

            if let endDate = eventData["endDate"] as? String {
                #expect(endDate.contains("T"))
                #expect(ISO8601DateFormatter().date(from: endDate) != nil)
            }
        }

        @Test("Error handling for invalid SwiftData schema")
        func testInvalidSwiftDataSchema() async throws {
            try requireLiveTests()

            let messages = [
                ChatMessage(
                    role: .user,
                    content: .text("Return the number 42")
                )
            ]

            do {
                _ = try await api.createChatCompletion(
                    model: "gpt-4o-mini",
                    messages: messages,
                    swiftDataModel: InvalidModel.self,
                    temperature: 0.0
                )
                Issue.record("Expected error for type mismatch")
            } catch {
                // Expected to fail when API returns a number but model expects object
                #expect(error is OpenAIError)
            }
        }

        @Test("SwiftData model with enum property")
        func testSwiftDataModelWithEnum() async throws {
            try requireLiveTests()
            enum Status: String {
                case pending
                case active
                case completed
                case cancelled
            }

            let messages = [
                ChatMessage(
                    role: .user,
                    content: .text(
                        "Create a task JSON with title (string), status (one of: pending, active, completed, cancelled), and priority (integer 1-5). Make it a completed high-priority task."
                    )
                )
            ]

            let taskData = try await api.createChatCompletion(
                model: "gpt-4o-mini",
                messages: messages,
                swiftDataModel: TaskWithStatus.self,
                temperature: 0.0
            )

            #expect(taskData["title"] as? String != nil)

            if let status = taskData["status"] as? String {
                #expect(["pending", "active", "completed", "cancelled"].contains(status))
                #expect(status == "completed")  // Based on prompt
            }

            if let priority = taskData["priority"] as? Int {
                #expect(priority >= 1 && priority <= 5)
                #expect(priority >= 4)  // High priority
            }
        }
    }

    // MARK: - Helper for Any Codable

    private struct AnyCodable: Codable {
        let value: Any

        init(_ value: Any) {
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let dict = try? container.decode([String: AnyCodable].self) {
                self.value = dict.mapValues { $0.value }
            } else if let array = try? container.decode([AnyCodable].self) {
                self.value = array.map { $0.value }
            } else if let string = try? container.decode(String.self) {
                self.value = string
            } else if let int = try? container.decode(Int.self) {
                self.value = int
            } else if let double = try? container.decode(Double.self) {
                self.value = double
            } else if let bool = try? container.decode(Bool.self) {
                self.value = bool
            } else if container.decodeNil() {
                self.value = NSNull()
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Cannot decode value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch value {
            case let dict as [String: Any]:
                try container.encode(dict.mapValues { AnyCodable($0) })
            case let array as [Any]:
                try container.encode(array.map { AnyCodable($0) })
            case let string as String:
                try container.encode(string)
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let bool as Bool:
                try container.encode(bool)
            case is NSNull:
                try container.encodeNil()
            default:
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "Cannot encode value of type \(type(of: value))"
                    ))
            }
        }
    }

#else

    @Suite("SwiftData Structured Output Live Tests - Unavailable")
    struct SwiftDataStructuredOutputLiveTestsUnavailable {
        @Test("SwiftData not available")
        func testSwiftDataNotAvailable() {
            #expect(true, "SwiftData live tests skipped - iOS 17.0+ required")
        }
    }

#endif  // canImport(SwiftData)
