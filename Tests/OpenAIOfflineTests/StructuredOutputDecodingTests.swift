import Foundation
import Testing

@testable import OpenAISwift

@Suite("Structured Output Decoding Tests")
struct StructuredOutputDecodingTests {

    @Test("ResponseFormat with json_schema decoding")
    func testResponseFormatDecoding() throws {
        // JSON in which the `schema` field is a normal JSON object (not Base-64 encoded data).
        let json = """
            {
                "type": "json_schema",
                "json_schema": {
                    "name": "person_schema",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "age":  {"type": "integer"}
                        },
                        "required": ["name", "age"]
                    },
                    "strict": true
                }
            }
            """

        let decoder = JSONDecoder()
        let responseFormat = try decoder.decode(ResponseFormat.self, from: json.data(using: .utf8)!)

        #expect(responseFormat.type == .jsonStructuredOutput)
        guard let schema = responseFormat.jsonStructuredOutput else {
            Issue.record("jsonStructuredOutput should not be nil")
            return
        }
        #expect(schema.name == "person_schema")
        #expect(schema.strict == true)
        #expect(schema.structuredOutput["type"] as? String == "object")
    }

    @Test("FunctionDefinition decoding with parameters object")
    func testFunctionDefinitionDecoding() throws {
        let json = """
            {
                "name": "get_weather",
                "description": "Retrieve weather information",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "location": {
                            "type": "string",
                            "description": "City name"
                        }
                    },
                    "required": ["location"]
                },
                "strict": false
            }
            """

        let decoder = JSONDecoder()
        let functionDef = try decoder.decode(FunctionDefinition.self, from: json.data(using: .utf8)!)

        #expect(functionDef.name == "get_weather")
        #expect(functionDef.description == "Retrieve weather information")
        #expect(functionDef.strict == false)
        guard let params = functionDef.parameters else {
            Issue.record("Parameters decoded incorrectly")
            return
        }
        #expect(params["type"] as? String == "object")
        if let properties = params["properties"] as? [String: Any] {
            #expect(properties.keys.contains("location"))
        } else {
            Issue.record("Expected properties dictionary in parameters")
        }
    }
} 