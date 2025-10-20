import Foundation
import Testing

@testable import OpenAIStructuredOutput
@testable import OpenAISwift

@Suite("Type-Based Structured Output Tests")
struct TypeBasedStructuredOutputTests {

    @Suite("Schema Generation from Types")
    struct SchemaGenerationTests {

        @Test("Generate schema for primitive types")
        func testPrimitiveTypeSchemas() {
            // String
            let stringSchema = StructuredOutputGenerator.generateSchema(for: String.self)
            #expect(stringSchema["type"] as? String == "string")

            // Int
            let intSchema = StructuredOutputGenerator.generateSchema(for: Int.self)
            #expect(intSchema["type"] as? String == "integer")

            // Double
            let doubleSchema = StructuredOutputGenerator.generateSchema(for: Double.self)
            #expect(doubleSchema["type"] as? String == "number")

            // Bool
            let boolSchema = StructuredOutputGenerator.generateSchema(for: Bool.self)
            #expect(boolSchema["type"] as? String == "boolean")

            // Optional String
            let optionalStringSchema = StructuredOutputGenerator.generateSchema(for: String?.self)
            #expect(optionalStringSchema["type"] as? String == "string")
        }

        @Test("Generate schema for Foundation types")
        func testFoundationTypeSchemas() {
            // Date
            let dateSchema = StructuredOutputGenerator.generateSchema(for: Date.self)
            #expect(dateSchema["type"] as? String == "string")
            #expect(dateSchema["format"] as? String == "date-time")

            // URL
            let urlSchema = StructuredOutputGenerator.generateSchema(for: URL.self)
            #expect(urlSchema["type"] as? String == "string")
            #expect(urlSchema["format"] as? String == "uri")

            // UUID
            let uuidSchema = StructuredOutputGenerator.generateSchema(for: UUID.self)
            #expect(uuidSchema["type"] as? String == "string")
            #expect(uuidSchema["format"] as? String == "uuid")

            // Data
            let dataSchema = StructuredOutputGenerator.generateSchema(for: Data.self)
            #expect(dataSchema["type"] as? String == "string")
            #expect(dataSchema["format"] as? String == "base64")
        }

        @Test("Generate schema for custom types")
        func testCustomTypeSchemas() {
            struct CustomType: Decodable {
                let name: String
                let value: Int
            }

            let schema = StructuredOutputGenerator.generateSchema(for: CustomType.self)
            #expect(schema["type"] as? String == "object")
            let description = schema["description"] as? String
            #expect(description?.contains("CustomType") == true)
        }

        @Test("Generate schema for StructuredOutputConvertible types")
        func testStructuredOutputConvertibleSchema() {
            struct ConvertibleType: StructuredOutputConvertible {
                static func generateStructuredOutput() -> [String: Any] {
                    return [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string"],
                            "score": ["type": "number", "minimum": 0, "maximum": 100],
                        ],
                        "required": ["id", "score"],
                    ]
                }
            }

            let schema = StructuredOutputGenerator.generateSchema(for: ConvertibleType.self)
            #expect(schema["type"] as? String == "object")

            let properties = schema["properties"] as? [String: Any]
            #expect(properties?.keys.contains("id") == true)
            #expect(properties?.keys.contains("score") == true)
        }
    }

    @Suite("Structured Response Tests")
    struct StructuredResponseTests {

        struct TestResponse: Decodable {
            let name: String
            let age: Int
            let active: Bool
        }

        @Test("Decode valid JSON response")
        func testDecodeValidJSON() throws {
            let json = """
                {
                    "name": "John",
                    "age": 30,
                    "active": true
                }
                """

            let response = StructuredResponse<TestResponse>(jsonString: json)
            let decoded = try response.decode()

            #expect(decoded.name == "John")
            #expect(decoded.age == 30)
            #expect(decoded.active == true)
        }

        @Test("Decode with snake_case conversion")
        func testDecodeSnakeCase() throws {
            struct SnakeCaseResponse: Decodable {
                let userName: String
                let isActive: Bool
                let createdAt: String
            }

            let json = """
                {
                    "user_name": "Alice",
                    "is_active": true,
                    "created_at": "2024-01-01"
                }
                """

            let response = StructuredResponse<SnakeCaseResponse>(jsonString: json)
            let decoded = try response.decode()

            #expect(decoded.userName == "Alice")
            #expect(decoded.isActive == true)
            #expect(decoded.createdAt == "2024-01-01")
        }

        @Test("Decode with custom decoder")
        func testDecodeWithCustomDecoder() throws {
            struct DateResponse: Decodable {
                let date: Date
            }

            let json = """
                {
                    "date": "01/15/2024"
                }
                """

            let response = StructuredResponse<DateResponse>(jsonString: json)

            let decoded = try response.decode { decoder in
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                decoder.dateDecodingStrategy = .formatted(formatter)
            }

            // Check that the date was parsed correctly
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: decoded.date)
            #expect(components.year == 2024)
            #expect(components.month == 1)
            #expect(components.day == 15)
        }

        @Test("Decode failure with invalid JSON")
        func testDecodeInvalidJSON() {
            let json = """
                {
                    "name": "John",
                    "age": "thirty"
                }
                """

            let response = StructuredResponse<TestResponse>(jsonString: json)

            do {
                _ = try response.decode()
                Issue.record("Should have thrown decoding error")
            } catch {
                #expect(error is DecodingError)
            }
        }
    }

    @Suite("Schema Builder Tests")
    struct SchemaBuilderTests {

        @Test("Build simple property definitions")
        func testSimplePropertyDefinitions() {
            let nameProp = string("name", minLength: 1, maxLength: 100)
            #expect(nameProp.name == "name")
            #expect(nameProp.schema["type"] as? String == "string")
            #expect(nameProp.schema["minLength"] as? Int == 1)
            #expect(nameProp.schema["maxLength"] as? Int == 100)
            #expect(nameProp.required == true)

            let ageProp = integer("age", minimum: 0, maximum: 150)
            #expect(ageProp.name == "age")
            #expect(ageProp.schema["type"] as? String == "integer")
            #expect(ageProp.schema["minimum"] as? Int == 0)
            #expect(ageProp.schema["maximum"] as? Int == 150)

            let scoreProp = number("score", required: false, minimum: 0.0, maximum: 100.0)
            #expect(scoreProp.name == "score")
            #expect(scoreProp.schema["type"] as? String == "number")
            #expect(scoreProp.required == false)

            let activeProp = boolean("active")
            #expect(activeProp.name == "active")
            #expect(activeProp.schema["type"] as? String == "boolean")

            let tagsProp = array("tags", itemType: "string", minItems: 1, maxItems: 10)
            #expect(tagsProp.name == "tags")
            #expect(tagsProp.schema["type"] as? String == "array")
            #expect(tagsProp.schema["minItems"] as? Int == 1)
            #expect(tagsProp.schema["maxItems"] as? Int == 10)
        }

        @Test("Schema builder result builder")
        func testSchemaBuilderResultBuilder() {
            @SchemaBuilder
            func buildProperties() -> [PropertyDefinition] {
                string("id", pattern: "^[A-Z0-9]+$")
                string("name", minLength: 1)
                integer("age", minimum: 0)
                boolean("active")
                array("tags", itemType: "string")
            }

            let properties = buildProperties()
            #expect(properties.count == 5)
            #expect(properties[0].name == "id")
            #expect(properties[1].name == "name")
            #expect(properties[2].name == "age")
            #expect(properties[3].name == "active")
            #expect(properties[4].name == "tags")
        }
    }

    @Suite("Property Info Tests")
    struct PropertyInfoTests {

        @Test("Create property info with constraints")
        func testPropertyInfoWithConstraints() {
            let constraints = PropertyConstraints(
                minimum: 0,
                maximum: 100,
                minLength: 5,
                maxLength: 50,
                pattern: "^[A-Za-z]+$",
                enumValues: ["active", "inactive", "pending"]
            )

            let propInfo = PropertyInfo(
                name: "status",
                type: "string",
                isOptional: false,
                description: "User status",
                constraints: constraints
            )

            #expect(propInfo.name == "status")
            #expect(propInfo.type == "string")
            #expect(propInfo.isOptional == false)
            #expect(propInfo.description == "User status")
            #expect(propInfo.constraints?.minimum == 0)
            #expect(propInfo.constraints?.maximum == 100)
            #expect(propInfo.constraints?.pattern == "^[A-Za-z]+$")
        }
    }

    @Suite("Integration Tests")
    struct IntegrationTests {

        @Test("End-to-end type to schema to response")
        func testEndToEndFlow() throws {
            // Define a type
            struct Product: Decodable, StructuredOutputConvertible {
                let id: String
                let name: String
                let price: Double
                let inStock: Bool

                static func generateStructuredOutput() -> [String: Any] {
                    return [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string"],
                            "name": ["type": "string", "minLength": 1],
                            "price": ["type": "number", "minimum": 0],
                            "inStock": ["type": "boolean"],
                        ],
                        "required": ["id", "name", "price", "inStock"],
                    ]
                }
            }

            // Generate schema
            let schema = StructuredOutputGenerator.generateSchema(for: Product.self)
            #expect(schema["type"] as? String == "object")

            // Simulate API response
            let apiResponse = """
                {
                    "id": "PROD123",
                    "name": "Premium Widget",
                    "price": 99.99,
                    "inStock": true
                }
                """

            // Decode response
            let response = StructuredResponse<Product>(jsonString: apiResponse)
            let product = try response.decode()

            #expect(product.id == "PROD123")
            #expect(product.name == "Premium Widget")
            #expect(product.price == 99.99)
            #expect(product.inStock == true)
        }
    }
}
