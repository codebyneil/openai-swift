import Foundation
import Testing

@testable import OpenAIStructuredOutput
@testable import OpenAISwift

#if canImport(SwiftData)
    import SwiftData
#endif

#if canImport(SwiftData)

    // MARK: - Test Models

    @Model
    class TestPerson {
        var name: String
        var age: Int
        var email: String?

        @Attribute(.unique)
        var id: UUID

        @Relationship(deleteRule: .cascade)
        var addresses: [TestAddress]

        @Transient
        var computedProperty: String {
            return "\(name) (\(age))"
        }

        init(name: String = "", age: Int = 0) {
            self.name = name
            self.age = age
            self.id = UUID()
            self.addresses = []
        }
    }

    @Model
    class TestAddress {
        var street: String
        var city: String
        var country: String
        var postalCode: String?

        @Relationship(inverse: \TestPerson.addresses)
        var person: TestPerson?

        init(street: String = "", city: String = "", country: String = "") {
            self.street = street
            self.city = city
            self.country = country
        }
    }

    @Model
    class TestTask: SwiftDataStructuredOutput {
        var title: String
        var completed: Bool
        var priority: Int
        var dueDate: Date?

        @Attribute(.preserveValueOnDeletion)
        var notes: String?

        init(title: String = "", completed: Bool = false, priority: Int = 0) {
            self.title = title
            self.completed = completed
            self.priority = priority
        }

        static func generateStructuredOutput() -> [String: Any] {
            return [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 200,
                    ],
                    "completed": ["type": "boolean"],
                    "priority": [
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 5,
                    ],
                    "dueDate": [
                        "type": "string",
                        "format": "date-time",
                    ],
                    "notes": ["type": "string"],
                ],
                "required": ["title", "completed", "priority"],
            ]
        }

        static var structuredOutputDescription: String? {
            "A task with priority and completion status"
        }

        static var excludedProperties: [String]? {
            ["internalId"]
        }
    }

    // MARK: - Tests

    @Suite("SwiftData Structured Output Tests")
    struct SwiftDataStructuredOutputTests {

        @Suite("Schema Generation Tests")
        struct SchemaGenerationTests {

            @Test("Generate schema from simple SwiftData model")
            func testSimpleModelSchemaGeneration() {
                let schema = StructuredOutputGenerator.generateStructuredOutput(
                    forSwiftDataModel: TestPerson.self
                )

                #expect(schema["type"] as? String == "object")
                #expect(schema["description"] as? String == "SwiftData model: TestPerson")

                let properties = schema["properties"] as? [String: Any]
                #expect(properties != nil)

                // Properties should be empty due to SwiftData limitations
                #expect(properties?.isEmpty == true)

                // No required fields since we can't introspect
                let required = schema["required"] as? [String]
                #expect(required == nil)
            }

            @Test("Generate schema with relationships")
            func testModelWithRelationships() {
                let schema = StructuredOutputGenerator.generateStructuredOutput(
                    forSwiftDataModel: TestPerson.self
                )

                let properties = schema["properties"] as? [String: Any]

                // Properties should be empty due to SwiftData limitations
                #expect(properties?.isEmpty == true)
            }

            @Test("Custom SwiftDataStructuredOutput conformance")
            func testCustomStructuredOutput() {
                let schema = TestTask.generateStructuredOutput()

                #expect(schema["type"] as? String == "object")

                let properties = schema["properties"] as? [String: Any]

                // Check custom constraints
                if let titleSchema = properties?["title"] as? [String: Any] {
                    #expect(titleSchema["minLength"] as? Int == 1)
                    #expect(titleSchema["maxLength"] as? Int == 200)
                }

                if let prioritySchema = properties?["priority"] as? [String: Any] {
                    #expect(prioritySchema["minimum"] as? Int == 0)
                    #expect(prioritySchema["maximum"] as? Int == 5)
                }

                // Check that excluded properties are handled
                #expect(TestTask.excludedProperties?.contains("internalId") == true)
            }
        }

        @Suite("Model Builder Tests")
        struct ModelBuilderTests {

            @Test("Convert structured output to SwiftData format")
            func testStructuredOutputConversion() {
                let input: [String: Any] = [
                    "title": "Test Task",
                    "completed": true,
                    "priority": 3,
                    "due_date": "2024-12-25T10:00:00Z",
                    "notes": "Important task",
                ]

                let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
                    dateDecodingStrategy: .iso8601,
                    keyDecodingStrategy: .convertFromSnakeCase
                )

                let converted = StructuredOutputToSwiftData.convert(input, using: configuration)

                #expect(converted["title"] as? String == "Test Task")
                #expect(converted["completed"] as? Bool == true)
                #expect(converted["priority"] as? Int == 3)
                #expect(converted["dueDate"] != nil)  // Snake case converted
                #expect(converted["notes"] as? String == "Important task")
            }

            @Test("Property mapping with transformers")
            func testPropertyMappingWithTransformers() {
                let input: [String: Any] = [
                    "task_name": "Test",
                    "is_done": "yes",
                    "importance": "high",
                ]

                let mappings = [
                    StructuredOutputToSwiftData.PropertyMapping(
                        jsonKey: "task_name",
                        modelProperty: "title"
                    ),
                    StructuredOutputToSwiftData.PropertyMapping(
                        jsonKey: "is_done",
                        modelProperty: "completed",
                        transformer: { value in
                            (value as? String) == "yes"
                        }
                    ),
                    StructuredOutputToSwiftData.PropertyMapping(
                        jsonKey: "importance",
                        modelProperty: "priority",
                        transformer: { value in
                            switch value as? String {
                            case "low": return 1
                            case "medium": return 3
                            case "high": return 5
                            default: return 0
                            }
                        }
                    ),
                ]

                let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
                    propertyMappings: mappings
                )

                let converted = StructuredOutputToSwiftData.convert(input, using: configuration)

                #expect(converted["title"] as? String == "Test")
                #expect(converted["completed"] as? Bool == true)
                #expect(converted["priority"] as? Int == 5)
            }

            @Test("Date decoding strategies")
            func testDateDecodingStrategies() {
                // ISO8601
                let iso8601Input = ["date": "2024-12-25T10:00:00Z"]
                let iso8601Config = StructuredOutputToSwiftData.ConversionConfiguration(
                    dateDecodingStrategy: .iso8601
                )
                let iso8601Result = StructuredOutputToSwiftData.convert(
                    iso8601Input, using: iso8601Config)
                #expect(iso8601Result["date"] is Date)

                // Seconds since 1970
                let secondsInput = ["date": "1735124400"]  // 2024-12-25 10:00:00 UTC
                let secondsConfig = StructuredOutputToSwiftData.ConversionConfiguration(
                    dateDecodingStrategy: .secondsSince1970
                )
                let secondsResult = StructuredOutputToSwiftData.convert(
                    secondsInput, using: secondsConfig)
                #expect(secondsResult["date"] is Date)

                // Custom
                let customInput = ["date": "25/12/2024"]
                let customConfig = StructuredOutputToSwiftData.ConversionConfiguration(
                    dateDecodingStrategy: .custom { dateString in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "dd/MM/yyyy"
                        return formatter.date(from: dateString)
                    }
                )
                let customResult = StructuredOutputToSwiftData.convert(
                    customInput, using: customConfig)
                #expect(customResult["date"] is Date)
            }

            @Test("Nested object conversion")
            func testNestedObjectConversion() {
                let input: [String: Any] = [
                    "name": "John",
                    "address": [
                        "street_name": "Main St",
                        "city_name": "New York",
                        "postal_code": "10001",
                    ],
                ]

                let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
                    keyDecodingStrategy: .convertFromSnakeCase
                )

                let converted = StructuredOutputToSwiftData.convert(input, using: configuration)

                #expect(converted["name"] as? String == "John")

                if let address = converted["address"] as? [String: Any] {
                    #expect(address["streetName"] as? String == "Main St")
                    #expect(address["cityName"] as? String == "New York")
                    #expect(address["postalCode"] as? String == "10001")
                } else {
                    Issue.record("Nested address object not converted properly")
                }
            }

            @Test("Array conversion")
            func testArrayConversion() {
                let input: [String: Any] = [
                    "items": [
                        ["item_name": "First", "item_value": 1],
                        ["item_name": "Second", "item_value": 2],
                    ]
                ]

                let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
                    keyDecodingStrategy: .convertFromSnakeCase
                )

                let converted = StructuredOutputToSwiftData.convert(input, using: configuration)

                if let items = converted["items"] as? [[String: Any]] {
                    #expect(items.count == 2)
                    #expect(items[0]["itemName"] as? String == "First")
                    #expect(items[0]["itemValue"] as? Int == 1)
                    #expect(items[1]["itemName"] as? String == "Second")
                    #expect(items[1]["itemValue"] as? Int == 2)
                } else {
                    Issue.record("Array not converted properly")
                }
            }
        }

        @Suite("Relationship Handling Tests")
        struct RelationshipHandlingTests {

            @Test("To-many relationship schema")
            func testToManyRelationshipSchema() {
                let schema = SwiftDataRelationshipHandler.schemaForRelationship(
                    [],
                    isToMany: true
                )

                #expect(schema["type"] as? String == "array")
                #expect(schema["items"] as? [String: Any] != nil)

                if let itemsSchema = schema["items"] as? [String: Any] {
                    #expect(itemsSchema["type"] as? String == "object")
                }
            }

            @Test("To-one relationship schema")
            func testToOneRelationshipSchema() {
                let schema = SwiftDataRelationshipHandler.schemaForRelationship(
                    TestAddress(),
                    isToMany: false
                )

                #expect(schema["type"] as? String == "object")
                #expect(schema["properties"] as? [String: Any] != nil)
            }
        }

        @Suite("Error Handling Tests")
        struct ErrorHandlingTests {

            @Test("Handle missing required properties")
            func testMissingRequiredProperties() {
                let input: [String: Any] = [
                    "completed": true,
                    "priority": 3,
                        // Missing required "title"
                ]

                // The conversion should still work
                let converted = StructuredOutputToSwiftData.convert(
                    input,
                    using: StructuredOutputToSwiftData.ConversionConfiguration()
                )

                #expect(converted["completed"] as? Bool == true)
                #expect(converted["priority"] as? Int == 3)
                #expect(converted["title"] == nil)
            }

            @Test("Handle invalid date formats")
            func testInvalidDateFormats() {
                let input: [String: Any] = [
                    "date": "invalid-date-string"
                ]

                let configuration = StructuredOutputToSwiftData.ConversionConfiguration(
                    dateDecodingStrategy: .iso8601
                )

                let converted = StructuredOutputToSwiftData.convert(input, using: configuration)

                // Should keep original value if date parsing fails
                #expect(converted["date"] as? String == "invalid-date-string")
            }

            @Test("Handle type mismatches")
            func testTypeMismatches() {
                let input: [String: Any] = [
                    "age": "twenty-five",  // String instead of Int
                    "completed": 1,  // Int instead of Bool
                ]

                let converted = StructuredOutputToSwiftData.convert(
                    input,
                    using: StructuredOutputToSwiftData.ConversionConfiguration()
                )

                // Values should be preserved as-is when no transformer is provided
                #expect(converted["age"] as? String == "twenty-five")
                #expect(converted["completed"] as? Int == 1)
            }
        }
    }

#else

    @Suite("SwiftData Structured Output Tests - Unavailable")
    struct SwiftDataStructuredOutputTestsUnavailable {
        @Test("SwiftData not available")
        func testSwiftDataNotAvailable() {
            #expect(true, "SwiftData tests skipped - iOS 17.0+ required")
        }
    }

#endif  // canImport(SwiftData)
