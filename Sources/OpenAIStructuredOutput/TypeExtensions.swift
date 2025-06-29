import Foundation

// MARK: - Mirror Extensions for Better Type Detection

/// Extensions to `StructuredOutputGenerator` providing advanced type introspection capabilities.
///
/// These extensions use Swift's Mirror API to provide more sophisticated type detection
/// and schema generation, including support for inheritance, property wrappers, and
/// complex nested structures.
extension StructuredOutputGenerator {

    /// Generates a JSON Schema by deeply introspecting an instance using Mirror reflection.
    ///
    /// This method provides more detailed schema generation than the basic type-based
    /// approach, including:
    /// - Property name extraction
    /// - Required field detection
    /// - Support for property wrappers
    /// - Inheritance chain processing
    ///
    /// - Parameter instance: The instance to introspect
    /// - Returns: A complete JSON Schema object with properties and constraints
    ///
    /// ## Example
    /// ```swift
    /// let person = Person(name: "John", age: 30)
    /// let schema = StructuredOutputGenerator.generateStructuredOutputFromMirror(for: person)
    /// ```
    public static func generateStructuredOutputFromMirror<T>(for instance: T) -> [String: Any] {
        let mirror = Mirror(reflecting: instance)

        var properties: [String: Any] = [:]
        var required: [String] = []

        processProperties(of: mirror, into: &properties, required: &required)

        return [
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": false,
        ]
    }

    /// Recursively processes properties from a Mirror, including superclass properties.
    ///
    /// This method extracts property information from a Mirror reflection and:
    /// - Identifies property names and types
    /// - Detects property wrappers
    /// - Determines required vs optional properties
    /// - Processes superclass properties recursively
    ///
    /// - Parameters:
    ///   - mirror: The Mirror reflection to process
    ///   - properties: Dictionary to populate with property schemas
    ///   - required: Array to populate with required property names
    private static func processProperties(
        of mirror: Mirror,
        into properties: inout [String: Any],
        required: inout [String]
    ) {
        for case let (label?, value) in mirror.children {
            let propertyName = sanitizePropertyName(label)

            // Check for property wrappers
            if let structuredProperty = value as? StructuredPropertyProtocol {
                properties[propertyName] = structuredProperty.structuredOutputRepresentation
                if structuredProperty.isRequired {
                    required.append(propertyName)
                }
            } else {
                // Generate schema based on type
                if let schema = generateStructuredOutputForValue(value) {
                    properties[propertyName] = schema

                    // Check if non-optional
                    if !isOptional(value) {
                        required.append(propertyName)
                    }
                }
            }
        }

        // Process superclass properties if any
        if let superclassMirror = mirror.superclassMirror {
            processProperties(of: superclassMirror, into: &properties, required: &required)
        }
    }

    /// Sanitizes property names by removing leading underscores from stored properties.
    ///
    /// Swift property wrappers often use underscore-prefixed storage, which
    /// this method cleans up for the JSON Schema.
    ///
    /// - Parameter name: The raw property name from Mirror
    /// - Returns: The sanitized property name
    private static func sanitizePropertyName(_ name: String) -> String {
        // Remove leading underscore from stored properties
        if name.hasPrefix("_") {
            return String(name.dropFirst())
        }
        return name
    }

    private static func isOptional(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional
    }

    /// Generates a JSON Schema for a single value with comprehensive type detection.
    ///
    /// This method handles:
    /// - Optional unwrapping
    /// - Collection types (arrays, dictionaries)
    /// - Enum detection
    /// - Basic Swift types
    /// - Custom types
    ///
    /// - Parameter value: The value to analyze
    /// - Returns: An optional JSON Schema dictionary, or nil if type cannot be determined
    private static func generateStructuredOutputForValue(_ value: Any) -> [String: Any]? {
        let mirror = Mirror(reflecting: value)

        // Handle optionals
        if mirror.displayStyle == .optional {
            if let first = mirror.children.first?.value {
                return generateStructuredOutputForValue(first)
            } else {
                // nil value - try to infer from type
                return nil
            }
        }

        // Handle collections
        if mirror.displayStyle == .collection {
            return generateArrayStructuredOutput(from: value)
        }

        if mirror.displayStyle == .dictionary {
            return ["type": "object", "additionalProperties": true]
        }

        // Handle enums
        if mirror.displayStyle == .enum {
            return generateEnumStructuredOutput(from: value, mirror: mirror)
        }

        // Handle basic types
        switch value {
        case is String:
            return ["type": "string"]
        case is Int, is Int8, is Int16, is Int32, is Int64,
            is UInt, is UInt8, is UInt16, is UInt32, is UInt64:
            return ["type": "integer"]
        case is Float, is Double:
            return ["type": "number"]
        case is Bool:
            return ["type": "boolean"]
        case is Date:
            return ["type": "string", "format": "date-time"]
        case is URL:
            return ["type": "string", "format": "uri"]
        case is UUID:
            return ["type": "string", "format": "uuid"]
        case is Data:
            return ["type": "string", "format": "byte"]
        default:
            // For custom types, return nil to let the main method handle it
            if mirror.displayStyle == .struct || mirror.displayStyle == .class {
                return nil
            }
            return nil
        }
    }

    /// Generates a JSON Schema for array/collection types by examining their contents.
    ///
    /// This method attempts to determine the item type by examining the first
    /// element in the collection. For empty collections, it defaults to string items.
    ///
    /// - Parameter value: The array/collection value
    /// - Returns: A JSON Schema for an array type
    private static func generateArrayStructuredOutput(from value: Any) -> [String: Any] {
        var schema: [String: Any] = ["type": "array"]

        let mirror = Mirror(reflecting: value)
        if let first = mirror.children.first?.value,
            let itemSchema = generateStructuredOutputForValue(first)
        {
            schema["items"] = itemSchema
        } else {
            // Empty array - default to string items
            schema["items"] = ["type": "string"]
        }

        return schema
    }

    /// Generates a JSON Schema for enum values by extracting their raw values.
    ///
    /// This method attempts to extract the raw value from enum cases and
    /// determine the appropriate JSON type.
    ///
    /// - Parameters:
    ///   - value: The enum value
    ///   - mirror: The Mirror reflection of the enum
    /// - Returns: A JSON Schema for the enum type
    private static func generateEnumStructuredOutput(from value: Any, mirror: Mirror) -> [String:
        Any]
    {
        // For simple enums with raw values
        if let rawValue = mirror.children.first?.value {
            switch rawValue {
            case is String:
                return ["type": "string", "enum": [rawValue]]
            case is Int:
                return ["type": "integer", "enum": [rawValue]]
            default:
                return ["type": "string"]
            }
        }

        return ["type": "string"]
    }
}

// MARK: - Protocol for Property Wrappers

/// Internal protocol for property wrappers to provide their schema representation.
///
/// Property wrappers conforming to this protocol can customize how they
/// appear in the generated JSON Schema.
protocol StructuredPropertyProtocol {
    /// The JSON Schema representation of this property.
    var structuredOutputRepresentation: [String: Any] { get }
    /// Whether this property should be marked as required in the schema.
    var isRequired: Bool { get }
}

extension StructuredOutput.Property: StructuredPropertyProtocol {
    var structuredOutputRepresentation: [String: Any] {
        var schema: [String: Any] = [:]

        // Determine type based on wrapped value
        switch wrappedValue {
        case is String:
            schema["type"] = "string"
        case is Int, is Int8, is Int16, is Int32, is Int64:
            schema["type"] = "integer"
        case is Float, is Double:
            schema["type"] = "number"
        case is Bool:
            schema["type"] = "boolean"
        default:
            schema["type"] = "object"
        }

        // Add constraints
        if let description = description {
            schema["description"] = description
        }
        if let examples = examples {
            schema["examples"] = examples
        }
        if let pattern = pattern {
            schema["pattern"] = pattern
        }
        if let minimum = minimum {
            schema["minimum"] = minimum
        }
        if let maximum = maximum {
            schema["maximum"] = maximum
        }
        if let minLength = minLength {
            schema["minLength"] = minLength
        }
        if let maxLength = maxLength {
            schema["maxLength"] = maxLength
        }
        if let enumValues = enumValues {
            schema["enum"] = enumValues
        }

        return schema
    }

    var isRequired: Bool { false }
}

extension StructuredOutput.Required: StructuredPropertyProtocol {
    var structuredOutputRepresentation: [String: Any] {
        return StructuredOutputGenerator.structuredOutputForValue(wrappedValue) ?? [
            "type": "object"
        ]
    }

    var isRequired: Bool { true }
}
