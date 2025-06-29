import Foundation

/// A protocol that enables custom types to define their own JSON Schema generation.
///
/// Types conforming to `StructuredOutputConvertible` can provide custom logic
/// for generating their JSON Schema representation. This is useful when the
/// automatic schema generation doesn't capture all the constraints or when
/// you need fine-grained control over the schema output.
///
/// ## Example
/// ```swift
/// struct EmailAddress: StructuredOutputConvertible {
///     let value: String
///
///     static var structuredOutputName: String { "EmailAddress" }
///     static var structuredOutputDescription: String? { "A valid email address" }
///
///     static func generateStructuredOutput() -> [String: Any] {
///         return [
///             "type": "string",
///             "format": "email",
///             "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
///         ]
///     }
/// }
/// ```
public protocol StructuredOutputConvertible {
    /// The name to use for this type in the JSON Schema.
    ///
    /// This name is used when generating response formats for OpenAI API calls.
    /// By default, it returns the type name using `String(describing: self)`.
    static var structuredOutputName: String { get }

    /// An optional description of the type for documentation purposes.
    ///
    /// This description can be included in the generated JSON Schema to provide
    /// context about the type's purpose and usage. Defaults to `nil`.
    static var structuredOutputDescription: String? { get }

    /// Generates the JSON Schema representation for this type.
    ///
    /// Implement this method to provide custom schema generation logic.
    /// The returned dictionary should be a valid JSON Schema object.
    ///
    /// - Returns: A dictionary representing the JSON Schema for this type
    ///
    /// ## Common Schema Properties
    /// - `"type"`: The JSON type ("string", "number", "integer", "boolean", "object", "array")
    /// - `"properties"`: For object types, defines the properties
    /// - `"required"`: Array of required property names
    /// - `"description"`: Human-readable description
    /// - `"enum"`: Array of allowed values
    /// - `"pattern"`: Regex pattern for string validation
    /// - `"minimum"`/`"maximum"`: Bounds for numeric types
    static func generateStructuredOutput() -> [String: Any]
}

extension StructuredOutputConvertible {
    public static var structuredOutputDescription: String? { nil }

    public static var structuredOutputName: String {
        String(describing: self)
    }
}

// Provide a deprecated type alias for backward compatibility
@available(*, deprecated, renamed: "StructuredOutputConvertible")
public typealias SchemaConvertible = StructuredOutputConvertible
