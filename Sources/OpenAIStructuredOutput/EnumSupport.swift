import Foundation

// MARK: - Protocol for Enum Schema Generation

/// A protocol for enums that can generate their own JSON Schema representation.
///
/// Enums conforming to this protocol can automatically generate a JSON Schema
/// with enum constraints based on their cases. The protocol requires the enum
/// to have a raw value and be CaseIterable.
///
/// ## Example
/// ```swift
/// enum Status: String, StructuredOutputEnumConvertible, CaseIterable {
///     case pending = "pending"
///     case active = "active"
///     case inactive = "inactive"
///
///     static var enumDescription: String? { "The status of the item" }
/// }
///
/// let schema = Status.generateEnumStructuredOutput()
/// // Results in: {"type": "string", "enum": ["pending", "active", "inactive"], "description": "The status of the item"}
/// ```
public protocol StructuredOutputEnumConvertible: RawRepresentable, CaseIterable
where RawValue: Codable {
    /// An optional description for the enum in the JSON Schema.
    ///
    /// This description helps document the purpose and usage of the enum.
    /// Defaults to `nil`.
    static var enumDescription: String? { get }
}

extension StructuredOutputEnumConvertible {
    public static var enumDescription: String? { nil }

    /// Generates a JSON Schema representation for the enum.
    ///
    /// This method automatically creates a schema with:
    /// - The appropriate type based on the RawValue
    /// - An enum constraint with all possible values
    /// - An optional description if provided
    ///
    /// - Returns: A dictionary representing the JSON Schema for the enum
    public static func generateEnumStructuredOutput() -> [String: Any] {
        var schema: [String: Any] = [:]

        // Determine type based on RawValue
        switch RawValue.self {
        case is String.Type:
            schema["type"] = "string"
        case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type:
            schema["type"] = "integer"
        case is Float.Type, is Double.Type:
            schema["type"] = "number"
        default:
            schema["type"] = "string"
        }

        // Add enum values
        schema["enum"] = allCases.map { $0.rawValue }

        // Add description if provided
        if let description = enumDescription {
            schema["description"] = description
        }

        return schema
    }
}

// MARK: - Automatic Schema Generation for Enums

extension StructuredOutputGenerator {

    /// Checks if a given type is an enum.
    ///
    /// - Parameter type: The type to check
    /// - Returns: `true` if the type is an enum, `false` otherwise
    ///
    /// ## Note
    /// This method uses Mirror reflection to determine if a type is an enum.
    public static func isEnum<T>(_ type: T.Type) -> Bool {
        let mirror = Mirror(reflecting: type)
        return mirror.displayStyle == .enum
    }

    /// Generates a JSON Schema for any enum type with raw values.
    ///
    /// This method creates a schema for enums that have raw values and are CaseIterable,
    /// automatically determining the type and extracting all possible values.
    ///
    /// - Parameter type: The enum type to generate a schema for
    /// - Returns: A dictionary representing the JSON Schema
    ///
    /// ## Example
    /// ```swift
    /// enum Priority: Int, CaseIterable {
    ///     case low = 1
    ///     case medium = 2
    ///     case high = 3
    /// }
    ///
    /// let schema = StructuredOutputGenerator.generateEnumStructuredOutput(for: Priority.self)
    /// // Results in: {"type": "integer", "enum": [1, 2, 3]}
    /// ```
    public static func generateEnumStructuredOutput<T: RawRepresentable & CaseIterable>(
        for type: T.Type
    ) -> [String: Any] where T.RawValue: Codable {
        var schema: [String: Any] = [:]

        // Determine type based on RawValue
        switch T.RawValue.self {
        case is String.Type:
            schema["type"] = "string"
        case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type:
            schema["type"] = "integer"
        case is Float.Type, is Double.Type:
            schema["type"] = "number"
        default:
            schema["type"] = "string"
        }

        // Add enum values
        schema["enum"] = type.allCases.map { $0.rawValue }

        return schema
    }
}

// MARK: - Enum Detection Helper

/// A utility struct for building JSON Schemas for enum types.
///
/// `EnumStructuredOutputBuilder` provides convenience methods for creating
/// JSON Schemas for enums with additional features like descriptions and
/// human-readable labels for enum cases.
public struct EnumStructuredOutputBuilder {

    /// Builds a JSON Schema for an enum type with an optional description.
    ///
    /// - Parameters:
    ///   - type: The enum type to build a schema for
    ///   - description: An optional description for the enum
    /// - Returns: A dictionary representing the JSON Schema
    ///
    /// ## Example
    /// ```swift
    /// let schema = EnumStructuredOutputBuilder.build(
    ///     for: Status.self,
    ///     description: "The current status of the process"
    /// )
    /// ```
    public static func build<T: RawRepresentable & CaseIterable>(
        for type: T.Type,
        description: String? = nil
    ) -> [String: Any] where T.RawValue: Codable {
        var schema = StructuredOutputGenerator.generateEnumStructuredOutput(for: type)

        if let description = description {
            schema["description"] = description
        }

        return schema
    }

    /// Builds a JSON Schema for an enum with human-readable labels.
    ///
    /// This method allows you to provide descriptive labels for each enum case,
    /// which are included as examples in the schema. This is useful for documentation
    /// and helping API consumers understand the meaning of each enum value.
    ///
    /// - Parameters:
    ///   - type: The enum type to build a schema for
    ///   - labels: A dictionary mapping enum cases to human-readable labels
    ///   - description: An optional description for the enum
    /// - Returns: A dictionary representing the JSON Schema with labeled examples
    ///
    /// ## Example
    /// ```swift
    /// enum OrderStatus: String, CaseIterable {
    ///     case new, processing, shipped, delivered
    /// }
    ///
    /// let schema = EnumStructuredOutputBuilder.buildWithLabels(
    ///     for: OrderStatus.self,
    ///     labels: [
    ///         .new: "New Order",
    ///         .processing: "Order Being Processed",
    ///         .shipped: "Order Shipped",
    ///         .delivered: "Order Delivered"
    ///     ],
    ///     description: "The current status of an order"
    /// )
    /// ```
    public static func buildWithLabels<T: RawRepresentable & CaseIterable>(
        for type: T.Type,
        labels: [T: String],
        description: String? = nil
    ) -> [String: Any] where T.RawValue: Codable {
        var schema = build(for: type, description: description)

        // Add enum labels as examples
        var examples: [[String: Any]] = []
        for (enumCase, label) in labels {
            examples.append([
                "value": enumCase.rawValue,
                "label": label,
            ])
        }

        if !examples.isEmpty {
            schema["examples"] = examples
        }

        return schema
    }
}
