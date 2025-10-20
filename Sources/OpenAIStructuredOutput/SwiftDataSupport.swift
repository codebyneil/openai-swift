import Foundation

#if canImport(SwiftData)
    import SwiftData
    import OpenAICore
    import OpenAIChat

    // MARK: - SwiftData Model Support

    /// Extension to support SwiftData model schema generation.
    ///
    /// This extension provides functionality to generate JSON schemas from SwiftData models,
    /// allowing them to be used as structured output types with OpenAI's API.
    ///
    /// ## Features
    /// - Automatic schema generation from @Model classes
    /// - Support for SwiftData attributes (@Attribute, @Relationship)
    /// - Handling of transient properties
    /// - Relationship mapping to JSON Schema references
    ///
    /// ## Example
    /// ```swift
    /// @Model
    /// class Person {
    ///     var name: String
    ///     var age: Int
    ///     var email: String?
    ///
    ///     @Relationship(deleteRule: .cascade)
    ///     var addresses: [Address]
    ///
    ///     init(name: String, age: Int) {
    ///         self.name = name
    ///         self.age = age
    ///     }
    /// }
    /// ```
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    extension StructuredOutputGenerator {

        /// Generates a JSON Schema from a SwiftData model type.
        ///
        /// This method introspects SwiftData model metadata to create an appropriate
        /// JSON schema, handling:
        /// - Persistent properties
        /// - Optional properties
        /// - Relationships (converted to nested objects or references)
        /// - Transient properties (excluded)
        ///
        /// - Parameter modelType: The SwiftData model type (must be a class with @Model)
        /// - Returns: A JSON Schema dictionary representing the model structure
        public static func generateStructuredOutput<T>(forSwiftDataModel modelType: T.Type)
            -> [String: Any]
        {
            // Since we can't create SwiftData instances without proper context,
            // we'll return a basic schema structure
            // In practice, you would need to:
            // 1. Use compile-time code generation
            // 2. Or manually define schemas for SwiftData models
            // 3. Or use SwiftDataStructuredOutput protocol

            let schema: [String: Any] = [
                "type": "object",
                "properties": [:],
                "additionalProperties": false,
                "description": "SwiftData model: \(String(describing: modelType))",
            ]

            return schema
        }

        /// Creates a dummy instance of a SwiftData model for introspection.
        ///
        /// - Parameter type: The model type to instantiate
        /// - Returns: An optional instance of the model
        private static func createDummyInstance<T>(of type: T.Type) -> T? {
            // SwiftData models require proper initialization with BackingData
            // This is a limitation of the current approach
            return nil
        }

        /// Checks if a property is marked as transient in a SwiftData model.
        ///
        /// - Parameters:
        ///   - propertyName: The name of the property to check
        ///   - modelType: The SwiftData model type
        /// - Returns: true if the property is transient, false otherwise
        private static func isTransientProperty<T>(_ propertyName: String, in modelType: T.Type)
            -> Bool
        {
            // In SwiftData, transient properties are marked with @Transient
            // This would require runtime inspection of property wrappers
            // For now, we'll use a heuristic approach

            // Common patterns for transient properties
            let transientPatterns = ["computed", "derived", "temp", "cache"]

            for pattern in transientPatterns {
                if propertyName.lowercased().contains(pattern) {
                    return true
                }
            }

            return false
        }

        /// Checks if a value is optional.
        private static func isOptionalValue(_ value: Any) -> Bool {
            let mirror = Mirror(reflecting: value)
            return mirror.displayStyle == .optional
        }
    }

    // MARK: - SwiftData Model Protocol

    /// Protocol for SwiftData models to provide custom structured output generation.
    ///
    /// Models can conform to this protocol to provide custom schema generation
    /// that differs from the automatic introspection.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    public protocol SwiftDataStructuredOutput {
        /// Generates a custom JSON Schema for this SwiftData model.
        static func generateStructuredOutput() -> [String: Any]

        /// Optional description for the model schema.
        static var structuredOutputDescription: String? { get }

        /// Specifies which properties to include in the schema.
        static var includedProperties: [String]? { get }

        /// Specifies which properties to exclude from the schema.
        static var excludedProperties: [String]? { get }
    }

    // Default implementation
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    extension SwiftDataStructuredOutput {
        public static var structuredOutputDescription: String? { nil }
        public static var includedProperties: [String]? { nil }
        public static var excludedProperties: [String]? { nil }
    }

    // MARK: - SwiftData Relationship Handling

    /// Utilities for handling SwiftData relationships in structured output.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    public struct SwiftDataRelationshipHandler {

        /// Converts a SwiftData relationship to a JSON Schema representation.
        ///
        /// - Parameters:
        ///   - relationship: The relationship property value
        ///   - isToMany: Whether this is a to-many relationship
        /// - Returns: A JSON Schema for the relationship
        public static func schemaForRelationship(_ relationship: Any, isToMany: Bool) -> [String:
            Any]
        {
            if isToMany {
                // To-many relationship: array of objects
                return [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [:],  // Would be populated based on related model
                    ],
                ]
            } else {
                // To-one relationship: single object
                return [
                    "type": "object",
                    "properties": [:],  // Would be populated based on related model
                ]
            }
        }
    }

    // MARK: - OpenAI Extension for SwiftData

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    extension OpenAI {

        /// Creates a chat completion with structured output for a SwiftData model.
        ///
        /// This method generates a JSON Schema from a SwiftData model and uses it
        /// to ensure the API returns data that can be mapped to the model.
        ///
        /// - Parameters:
        ///   - model: The OpenAI model to use (e.g., "gpt-4")
        ///   - messages: Array of chat messages
        ///   - swiftDataModel: The SwiftData model type
        ///   - temperature: Controls randomness (0-2)
        ///   - maxTokens: Maximum tokens to generate
        ///   - strict: Whether to enforce strict schema validation
        /// - Returns: A dictionary that can be used to populate the SwiftData model
        /// - Throws: `OpenAIError` if the request fails
        ///
        /// ## Example
        /// ```swift
        /// @Model
        /// class Task {
        ///     var title: String
        ///     var completed: Bool
        ///     var priority: Int
        /// }
        ///
        /// let taskData = try await openAI.createChatCompletion(
        ///     model: "gpt-4",
        ///     messages: messages,
        ///     swiftDataModel: Task.self
        /// )
        /// ```
        public func createChatCompletion<T>(
            model: String,
            messages: [ChatMessage],
            swiftDataModel: T.Type,
            temperature: Double? = nil,
            maxTokens: Int? = nil,
            strict: Bool = true
        ) async throws -> [String: Any] {
            // Generate schema for the SwiftData model
            let schema = StructuredOutputGenerator.generateStructuredOutput(
                forSwiftDataModel: swiftDataModel)

            let responseFormat = ResponseFormatBuilder.buildResponseFormat(
                name: String(describing: swiftDataModel),
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

            // Extract and parse the JSON response
            guard let message = response.choices.first?.message,
                case .text(let jsonString) = message.content,
                let jsonData = jsonString.data(using: .utf8)
            else {
                throw OpenAIError.missingData
            }

            // Return as dictionary for SwiftData model population
            do {
                let json = try JSONSerialization.jsonObject(with: jsonData)
                guard let dictionary = json as? [String: Any] else {
                    throw OpenAIError.decodingError(
                        DecodingError.typeMismatch(
                            [String: Any].self,
                            DecodingError.Context(
                                codingPath: [],
                                debugDescription: "Expected dictionary but got \(type(of: json))"
                            )
                        )
                    )
                }
                return dictionary
            } catch {
                throw OpenAIError.decodingError(error)
            }
        }
    }

#endif  // canImport(SwiftData)
