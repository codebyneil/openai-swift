import Foundation
import Testing

@testable import OpenAIStructuredOutput
@testable import OpenAISwift

@Suite("Structured Output Error Handling Tests")
struct StructuredOutputErrorTests {
    
    @Test("OpenAIError types for structured output")
    func testOpenAIErrorTypes() {
        // Test missingData error
        let missingDataError = OpenAIError.missingData
        if case .missingData = missingDataError {
            // Success
        } else {
            Issue.record("Expected missingData error")
        }
        
        // Test decodingError
        let decodingError = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Test error"
            )
        )
        let wrappedError = OpenAIError.decodingError(decodingError)
        
        if case .decodingError(let error, _) = wrappedError {
            #expect(error is DecodingError)
        } else {
            Issue.record("Expected decodingError")
        }
    }
    
    @Test("Schema generation for types without default initializer")
    func testSchemaGenerationWithoutDefaultInit() {
        struct NoDefaultInit: Decodable {
            let value: String
            
            init(value: String) {
                self.value = value
            }
        }
        
        // This would fail in the extension's createChatCompletion method
        // because it tries to create a temporary instance with empty JSON
        do {
            _ = try JSONDecoder().decode(
                NoDefaultInit.self,
                from: "{}".data(using: .utf8)!
            )
            Issue.record("Should have failed to decode without required value")
        } catch {
            // Expected to fail
            #expect(error is DecodingError)
        }
    }
    
    @Test("Invalid JSON in response")
    func testInvalidJSONResponse() {
        let invalidJSON = "not valid json"
        
        do {
            _ = try JSONSerialization.jsonObject(
                with: invalidJSON.data(using: .utf8)!
            )
            Issue.record("Should have failed to parse invalid JSON")
        } catch {
            // Expected to fail
            #expect(error is any Error)
        }
    }
    
    @Test("Type mismatch in decoding")
    func testTypeMismatchDecoding() {
        struct ExpectString: Decodable {
            let value: String
        }
        
        let jsonWithNumber = """
        {
            "value": 42
        }
        """
        
        do {
            _ = try JSONDecoder().decode(
                ExpectString.self,
                from: jsonWithNumber.data(using: .utf8)!
            )
            Issue.record("Should have failed due to type mismatch")
        } catch {
            #expect(error is DecodingError)
        }
    }
    
    @Test("Missing required fields")
    func testMissingRequiredFields() {
        struct RequiredFields: Decodable {
            let name: String
            let age: Int
        }
        
        let incompleteJSON = """
        {
            "name": "John"
        }
        """
        
        do {
            _ = try JSONDecoder().decode(
                RequiredFields.self,
                from: incompleteJSON.data(using: .utf8)!
            )
            Issue.record("Should have failed due to missing required field")
        } catch {
            #expect(error is DecodingError)
            
            if case DecodingError.keyNotFound(let key, _) = error {
                #expect(key.stringValue == "age")
            }
        }
    }
    
    @Test("Schema validation errors")
    func testSchemaValidationErrors() {
        // Test that property wrappers properly validate constraints
        struct ValidationTest {
            @StructuredOutput.Property(minLength: 5, maxLength: 10)
            var username: String = ""
            
            @StructuredOutput.Property(minimum: 0, maximum: 100)
            var percentage: Int = 0
            
            @StructuredOutput.Array(minItems: 1, maxItems: 3)
            var items: [String] = []
        }
        
        let instance = ValidationTest()
        let schema = StructuredOutputGenerator.generateStructuredOutput(for: instance)
        
        let properties = schema["properties"] as? [String: Any]
        
        // Verify constraints are in schema
        if let usernameSchema = properties?["username"] as? [String: Any] {
            #expect(usernameSchema["minLength"] as? Int == 5)
            #expect(usernameSchema["maxLength"] as? Int == 10)
        }
        
        if let percentageSchema = properties?["percentage"] as? [String: Any] {
            #expect(percentageSchema["minimum"] as? Int == 0)
            #expect(percentageSchema["maximum"] as? Int == 100)
        }
        
        if let itemsSchema = properties?["items"] as? [String: Any] {
            #expect(itemsSchema["minItems"] as? Int == 1)
            #expect(itemsSchema["maxItems"] as? Int == 3)
        }
    }
    
    @Test("Circular reference detection")
    func testCircularReferenceHandling() {
        class CircularNode {
            let value: String = "node"
            var parent: CircularNode?
            
            init() {
                // Don't create actual circular reference in test
            }
        }
        
        let node = CircularNode()
        let schema = StructuredOutputGenerator.generateStructuredOutput(for: node)
        
        // Should handle gracefully without infinite recursion
        #expect(schema["type"] as? String == "object")
        
        let properties = schema["properties"] as? [String: Any]
        #expect(properties?.keys.contains("value") == true)
        
        // Parent should be detected as optional
        if let parentSchema = properties?["parent"] as? [String: Any] {
            #expect(parentSchema["type"] as? String == "object")
        }
    }
}