import Foundation
import Testing

@testable import OpenAIStructuredOutput
@testable import OpenAISwift

// Test models defined at file level for proper reflection
struct TestModel {
    let name: String
    let age: Int
    let isActive: Bool
}

struct OptionalModel {
    let required: String
    let optional: String?
}

@Suite("Structured Output Tests")
struct StructuredOutputMockTests {

    @Suite("StructuredOutputGenerator Tests")
    struct GeneratorTests {

        @Test("Generate structured output for simple types")
        func testSimpleTypes() {
            // String
            let stringSchema = StructuredOutputGenerator.generateStructuredOutput(for: String.self)
            #expect(stringSchema["type"] as? String == "string")

            // Integer
            let intSchema = StructuredOutputGenerator.generateStructuredOutput(for: Int.self)
            #expect(intSchema["type"] as? String == "integer")

            // Double
            let doubleSchema = StructuredOutputGenerator.generateStructuredOutput(for: Double.self)
            #expect(doubleSchema["type"] as? String == "number")

            // Boolean
            let boolSchema = StructuredOutputGenerator.generateStructuredOutput(for: Bool.self)
            #expect(boolSchema["type"] as? String == "boolean")
        }

        @Test("Generate structured output from instance")
        func testGenerateFromInstance() {
            let instance = TestModel(name: "Test", age: 25, isActive: true)
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: instance)

            #expect(schema["type"] as? String == "object")

            let properties = schema["properties"] as? [String: Any]
            #expect(properties != nil)
            #expect(properties?.keys.contains("name") == true)
            #expect(properties?.keys.contains("age") == true)
            #expect(properties?.keys.contains("isActive") == true)

            let required = schema["required"] as? [String]
            #expect(required?.count == 3)
        }

        @Test("Generate structured output with optionals")
        func testOptionalProperties() {
            let instance = OptionalModel(required: "value", optional: nil)
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: instance)

            let required = schema["required"] as? [String]
            #expect(required?.contains("required") == true)
            #expect(required?.contains("optional") == false)
        }
    }

    @Suite("StructuredOutputConvertible Tests")
    struct ConvertibleTests {

        struct CustomType: StructuredOutputConvertible {
            static var structuredOutputName: String { "CustomType" }
            static var structuredOutputDescription: String? { "A custom test type" }

            static func generateStructuredOutput() -> [String: Any] {
                return [
                    "type": "object",
                    "description": structuredOutputDescription ?? "",
                    "properties": [
                        "id": ["type": "string"],
                        "value": ["type": "number"],
                    ],
                    "required": ["id", "value"],
                ]
            }
        }

        @Test("Custom type conformance")
        func testCustomTypeConformance() {
            let schema = CustomType.generateStructuredOutput()

            #expect(CustomType.structuredOutputName == "CustomType")
            #expect(CustomType.structuredOutputDescription == "A custom test type")
            #expect(schema["type"] as? String == "object")
            #expect(schema["description"] as? String == "A custom test type")

            let properties = schema["properties"] as? [String: Any]
            #expect(properties?.keys.count == 2)
        }

        @Test("Generate structured output for conforming type")
        func testGenerateForConformingType() {
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: CustomType.self)

            #expect(schema["type"] as? String == "object")
            #expect(schema["description"] as? String == "A custom test type")
        }
    }

    @Suite("Property Wrapper Tests")
    struct PropertyWrapperTests {

        @Test("Property wrapper initialization")
        func testPropertyWrapperInit() {
            let property = StructuredOutput.Property(
                wrappedValue: "test",
                description: "Test property",
                minLength: 1,
                maxLength: 10
            )

            #expect(property.wrappedValue == "test")
            #expect(property.description == "Test property")
            #expect(property.minLength == 1)
            #expect(property.maxLength == 10)
        }

        @Test("Required wrapper")
        func testRequiredWrapper() {
            let required = StructuredOutput.Required(wrappedValue: 42)
            #expect(required.wrappedValue == 42)
        }

        @Test("Ignored wrapper")
        func testIgnoredWrapper() {
            let ignored = StructuredOutput.Ignored(wrappedValue: "ignored")
            #expect(ignored.wrappedValue == "ignored")
        }

        @Test("Optional wrapper")
        func testOptionalWrapper() {
            let optional = StructuredOutput.Optional(wrappedValue: "value", default: "default")
            #expect(optional.wrappedValue == "value")
            #expect(optional.defaultValue == "default")
        }

        @Test("Array wrapper")
        func testArrayWrapper() {
            let array = StructuredOutput.Array(
                wrappedValue: [1, 2, 3],
                minItems: 1,
                maxItems: 5,
                uniqueItems: true
            )

            #expect(array.wrappedValue == [1, 2, 3])
            #expect(array.minItems == 1)
            #expect(array.maxItems == 5)
            #expect(array.uniqueItems == true)
        }
    }

    @Suite("Enum Support Tests")
    struct EnumSupportTests {

        enum TestEnum: String, CaseIterable, StructuredOutputEnumConvertible {
            case optionA = "a"
            case optionB = "b"
            case optionC = "c"

            static var enumDescription: String? { "Test enumeration" }
        }

        @Test("Enum structured output generation")
        func testEnumGeneration() {
            let schema = TestEnum.generateEnumStructuredOutput()

            #expect(schema["type"] as? String == "string")
            #expect(schema["description"] as? String == "Test enumeration")

            let enumValues = schema["enum"] as? [String]
            #expect(enumValues?.count == 3)
            #expect(enumValues?.contains("a") == true)
            #expect(enumValues?.contains("b") == true)
            #expect(enumValues?.contains("c") == true)
        }

        @Test("Enum structured output builder")
        func testEnumBuilder() {
            let schema = EnumStructuredOutputBuilder.build(
                for: TestEnum.self,
                description: "Custom description"
            )

            #expect(schema["type"] as? String == "string")
            #expect(schema["description"] as? String == "Custom description")
            #expect((schema["enum"] as? [String])?.count == 3)
        }

        @Test("Enum builder with labels")
        func testEnumBuilderWithLabels() {
            let schema = EnumStructuredOutputBuilder.buildWithLabels(
                for: TestEnum.self,
                labels: [
                    .optionA: "First option",
                    .optionB: "Second option",
                    .optionC: "Third option",
                ],
                description: "Labeled enum"
            )

            #expect(schema["description"] as? String == "Labeled enum")

            let examples = schema["examples"] as? [[String: Any]]
            #expect(examples?.count == 3)

            // Check that all expected examples exist (order not guaranteed)
            let hasOptionA =
                examples?.contains { example in
                    example["value"] as? String == "a"
                        && example["label"] as? String == "First option"
                } ?? false

            let hasOptionB =
                examples?.contains { example in
                    example["value"] as? String == "b"
                        && example["label"] as? String == "Second option"
                } ?? false

            let hasOptionC =
                examples?.contains { example in
                    example["value"] as? String == "c"
                        && example["label"] as? String == "Third option"
                } ?? false

            #expect(hasOptionA)
            #expect(hasOptionB)
            #expect(hasOptionC)
        }
    }

    @Suite("Type Detection Tests")
    struct TypeDetectionTests {

        @Test("Array type detection")
        func testArrayDetection() {
            let arrayInstance = [1, 2, 3]
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: arrayInstance)

            #expect(schema["type"] as? String == "array")

            let itemSchema = schema["items"] as? [String: Any]
            #expect(itemSchema?["type"] as? String == "integer")
        }

        @Test("Dictionary type detection")
        func testDictionaryDetection() {
            let dictInstance = ["key": "value"]
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: dictInstance)

            #expect(schema["type"] as? String == "object")
            #expect(schema["additionalProperties"] as? Bool == true)
        }

        @Test("Date type detection")
        func testDateDetection() {
            let dateInstance = Date()
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: dateInstance)

            #expect(schema["type"] as? String == "string")
            #expect(schema["format"] as? String == "date-time")
        }

        @Test("URL type detection")
        func testURLDetection() {
            let urlInstance = URL(string: "https://example.com")!
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: urlInstance)

            #expect(schema["type"] as? String == "string")
            #expect(schema["format"] as? String == "uri")
        }

        @Test("UUID type detection")
        func testUUIDDetection() {
            let uuidInstance = UUID()
            let schema = StructuredOutputGenerator.generateStructuredOutput(for: uuidInstance)

            #expect(schema["type"] as? String == "string")
            #expect(schema["format"] as? String == "uuid")
        }
    }
}
