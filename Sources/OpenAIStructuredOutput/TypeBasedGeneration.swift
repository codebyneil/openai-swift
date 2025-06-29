import Foundation
import OpenAICore
import OpenAIChat

// MARK: - Type-Based Schema Generation

/// Extension to generate JSON schemas from Swift types without requiring instances.
extension StructuredOutputGenerator {
    
    /// Generates a JSON Schema from a Swift type using compile-time type information.
    ///
    /// This method creates schemas for common Swift types without needing an instance.
    /// For custom types, use `StructuredOutputConvertible` protocol for better control.
    ///
    /// - Parameter type: The Swift type to generate a schema for
    /// - Returns: A JSON Schema dictionary
    ///
    /// ## Supported Types
    /// - Primitives: String, Int, Double, Bool, Float
    /// - Foundation: Date, URL, UUID, Data
    /// - Collections: Array<T>, Set<T>, Dictionary<K,V>
    /// - Optionals: T?
    /// - Custom types conforming to StructuredOutputConvertible
    ///
    /// ## Example
    /// ```swift
    /// struct User: Decodable {
    ///     let name: String
    ///     let age: Int
    ///     let email: String?
    /// }
    /// 
    /// let schema = StructuredOutputGenerator.generateSchema(for: User.self)
    /// ```
    public static func generateSchema<T>(for type: T.Type) -> [String: Any] {
        // Handle StructuredOutputConvertible types
        if let convertibleType = type as? any StructuredOutputConvertible.Type {
            return convertibleType.generateStructuredOutput()
        }
        
        // Handle primitive types
        switch type {
        case is String.Type, is String?.Type:
            return ["type": "string"]
        case is Int.Type, is Int?.Type,
             is Int8.Type, is Int8?.Type,
             is Int16.Type, is Int16?.Type,
             is Int32.Type, is Int32?.Type,
             is Int64.Type, is Int64?.Type,
             is UInt.Type, is UInt?.Type,
             is UInt8.Type, is UInt8?.Type,
             is UInt16.Type, is UInt16?.Type,
             is UInt32.Type, is UInt32?.Type,
             is UInt64.Type, is UInt64?.Type:
            return ["type": "integer"]
        case is Float.Type, is Float?.Type,
             is Double.Type, is Double?.Type,
             is Decimal.Type, is Decimal?.Type:
            return ["type": "number"]
        case is Bool.Type, is Bool?.Type:
            return ["type": "boolean"]
        case is Date.Type, is Date?.Type:
            return ["type": "string", "format": "date-time"]
        case is URL.Type, is URL?.Type:
            return ["type": "string", "format": "uri"]
        case is UUID.Type, is UUID?.Type:
            return ["type": "string", "format": "uuid"]
        case is Data.Type, is Data?.Type:
            return ["type": "string", "format": "base64"]
        default:
            // For complex types, try to infer structure
            return inferStructure(for: type)
        }
    }
    
    /// Infers the structure of a type using Mirror and other runtime information.
    private static func inferStructure<T>(for type: T.Type) -> [String: Any] {
        // Check if it's an array type by checking the type name
        let typeName = String(describing: type)
        if typeName.hasPrefix("Array<") || typeName.hasPrefix("[") {
            return [
                "type": "array",
                "items": ["type": "object"] // Generic object for now
            ]
        }
        
        // Default to object type for complex types
        return [
            "type": "object",
            "properties": [:],
            "additionalProperties": false,
            "description": "Type: \(String(describing: type))"
        ]
    }
}

// MARK: - Enhanced Decodable Support

/// Protocol for types that can provide property information at compile time.
public protocol StructuredOutputDecodable: Decodable {
    /// Returns property information for schema generation.
    static var propertyInfo: [PropertyInfo] { get }
}

/// Information about a property for schema generation.
public struct PropertyInfo {
    public let name: String
    public let type: String
    public let isOptional: Bool
    public let description: String?
    public let constraints: PropertyConstraints?
    
    public init(
        name: String,
        type: String,
        isOptional: Bool = false,
        description: String? = nil,
        constraints: PropertyConstraints? = nil
    ) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.description = description
        self.constraints = constraints
    }
}

/// Constraints for a property.
public struct PropertyConstraints {
    public let minimum: Double?
    public let maximum: Double?
    public let minLength: Int?
    public let maxLength: Int?
    public let pattern: String?
    public let enumValues: [Any]?
    
    public init(
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        enumValues: [Any]? = nil
    ) {
        self.minimum = minimum
        self.maximum = maximum
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
        self.enumValues = enumValues
    }
}

// MARK: - Response Transformation

/// A type-safe wrapper for transforming OpenAI responses to Swift types.
public struct StructuredResponse<T: Decodable> {
    private let jsonString: String
    
    init(jsonString: String) {
        self.jsonString = jsonString
    }
    
    /// Decodes the response into the specified type.
    ///
    /// - Parameter type: The type to decode into (can be inferred)
    /// - Returns: The decoded value
    /// - Throws: DecodingError if the JSON doesn't match the expected structure
    public func decode(as type: T.Type = T.self) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to convert string to UTF-8 data"
                )
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: data)
    }
    
    /// Decodes the response with a custom JSONDecoder configuration.
    ///
    /// - Parameters:
    ///   - type: The type to decode into
    ///   - configure: A closure to configure the decoder
    /// - Returns: The decoded value
    /// - Throws: DecodingError if the JSON doesn't match the expected structure
    public func decode(
        as type: T.Type = T.self,
        configure: (JSONDecoder) -> Void
    ) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to convert string to UTF-8 data"
                )
            )
        }
        
        let decoder = JSONDecoder()
        configure(decoder)
        return try decoder.decode(type, from: data)
    }
}

// MARK: - Convenience Extensions

extension OpenAI {
    /// Creates a chat completion with structured output for a Decodable type.
    ///
    /// This enhanced version generates schemas from types and returns a decoded response.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion
    ///   - messages: Array of chat messages
    ///   - responseType: The Decodable type to decode the response into
    ///   - temperature: Controls randomness (0-2)
    ///   - maxTokens: Maximum tokens to generate
    ///   - strict: Whether to enforce strict schema validation
    /// - Returns: The decoded response of type T
    /// - Throws: `OpenAIError` if the request fails or response cannot be decoded
    ///
    /// ## Example
    /// ```swift
    /// struct Analysis: Decodable {
    ///     let summary: String
    ///     let sentiment: String
    ///     let score: Double
    /// }
    /// 
    /// let result = try await openAI.createChatCompletionTyped(
    ///     model: "gpt-4",
    ///     messages: messages,
    ///     responseType: Analysis.self
    /// )
    /// // result is of type Analysis
    /// ```
    public func createChatCompletionTyped<T: Decodable>(
        model: String,
        messages: [ChatMessage],
        responseType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        strict: Bool = true
    ) async throws -> T {
        // Generate schema for the type
        let schema = StructuredOutputGenerator.generateSchema(for: responseType)
        
        let responseFormat = ResponseFormatBuilder.buildResponseFormat(
            name: String(describing: responseType),
            schema: schema,
            strict: strict
        )
        
        // Create the request
        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat
        )
        
        // Make the API call
        let response = try await createChatCompletion(request)
        
        // Extract and decode the response
        guard let message = response.choices.first?.message,
              case .text(let jsonString) = message.content else {
            throw OpenAIError.missingData
        }
        
        // Use the type-safe wrapper for better error handling
        let structuredResponse = StructuredResponse<T>(jsonString: jsonString)
        
        do {
            return try structuredResponse.decode()
        } catch {
            throw OpenAIError.decodingError(error)
        }
    }
    
    /// Creates a chat completion and returns a structured response wrapper.
    ///
    /// This version returns a `StructuredResponse` wrapper that allows for
    /// custom decoding strategies.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion
    ///   - messages: Array of chat messages
    ///   - responseType: The expected response type (for schema generation)
    ///   - temperature: Controls randomness (0-2)
    ///   - maxTokens: Maximum tokens to generate
    ///   - strict: Whether to enforce strict schema validation
    /// - Returns: A `StructuredResponse` wrapper containing the JSON response
    /// - Throws: `OpenAIError` if the request fails
    ///
    /// ## Example
    /// ```swift
    /// let response = try await openAI.createChatCompletionStructured(
    ///     model: "gpt-4",
    ///     messages: messages,
    ///     responseType: MyType.self
    /// )
    /// 
    /// // Decode with custom configuration
    /// let decoder = JSONDecoder()
    /// decoder.keyDecodingStrategy = .custom { /* ... */ }
    /// let result = try response.decode(using: decoder)
    /// ```
    public func createChatCompletionStructured<T: Decodable>(
        model: String,
        messages: [ChatMessage],
        responseType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        strict: Bool = true
    ) async throws -> StructuredResponse<T> {
        // Generate schema for the type
        let schema = StructuredOutputGenerator.generateSchema(for: responseType)
        
        let responseFormat = ResponseFormatBuilder.buildResponseFormat(
            name: String(describing: responseType),
            schema: schema,
            strict: strict
        )
        
        // Create the request
        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat
        )
        
        // Make the API call
        let response = try await createChatCompletion(request)
        
        // Extract the response
        guard let message = response.choices.first?.message,
              case .text(let jsonString) = message.content else {
            throw OpenAIError.missingData
        }
        
        return StructuredResponse(jsonString: jsonString)
    }
}

// MARK: - Result Builder for Schema Definition

/// A result builder for declaratively defining schemas.
@resultBuilder
public enum SchemaBuilder {
    public static func buildBlock(_ components: PropertyDefinition...) -> [PropertyDefinition] {
        components
    }
}

/// A property definition for schema building.
public struct PropertyDefinition {
    let name: String
    let schema: [String: Any]
    let required: Bool
    
    public init(name: String, type: String, required: Bool = true, constraints: [String: Any] = [:]) {
        self.name = name
        self.required = required
        
        var schema: [String: Any] = ["type": type]
        for (key, value) in constraints {
            schema[key] = value
        }
        self.schema = schema
    }
}

/// Helper functions for creating property definitions.
public func property(_ name: String, type: String, required: Bool = true) -> PropertyDefinition {
    PropertyDefinition(name: name, type: type, required: required)
}

public func string(_ name: String, required: Bool = true, minLength: Int? = nil, maxLength: Int? = nil, pattern: String? = nil) -> PropertyDefinition {
    var constraints: [String: Any] = [:]
    if let min = minLength { constraints["minLength"] = min }
    if let max = maxLength { constraints["maxLength"] = max }
    if let pat = pattern { constraints["pattern"] = pat }
    
    return PropertyDefinition(name: name, type: "string", required: required, constraints: constraints)
}

public func integer(_ name: String, required: Bool = true, minimum: Int? = nil, maximum: Int? = nil) -> PropertyDefinition {
    var constraints: [String: Any] = [:]
    if let min = minimum { constraints["minimum"] = min }
    if let max = maximum { constraints["maximum"] = max }
    
    return PropertyDefinition(name: name, type: "integer", required: required, constraints: constraints)
}

public func number(_ name: String, required: Bool = true, minimum: Double? = nil, maximum: Double? = nil) -> PropertyDefinition {
    var constraints: [String: Any] = [:]
    if let min = minimum { constraints["minimum"] = min }
    if let max = maximum { constraints["maximum"] = max }
    
    return PropertyDefinition(name: name, type: "number", required: required, constraints: constraints)
}

public func boolean(_ name: String, required: Bool = true) -> PropertyDefinition {
    PropertyDefinition(name: name, type: "boolean", required: required)
}

public func array(_ name: String, itemType: String, required: Bool = true, minItems: Int? = nil, maxItems: Int? = nil) -> PropertyDefinition {
    var constraints: [String: Any] = ["items": ["type": itemType]]
    if let min = minItems { constraints["minItems"] = min }
    if let max = maxItems { constraints["maxItems"] = max }
    
    return PropertyDefinition(name: name, type: "array", required: required, constraints: constraints)
}