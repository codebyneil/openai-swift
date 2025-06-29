import Foundation

/// A utility class for generating JSON Schema structured outputs from Swift types.
///
/// `StructuredOutputGenerator` provides methods to introspect Swift types and instances
/// to generate JSON Schema definitions compatible with OpenAI's structured output format.
/// It supports primitive types, collections, custom types, and property wrappers.
///
/// ## Example
/// ```swift
/// struct Person {
///     let name: String
///     let age: Int
/// }
///
/// let schema = StructuredOutputGenerator.generateStructuredOutput(for: Person.self)
/// // Results in: {"type": "object", "properties": {"name": {"type": "string"}, "age": {"type": "integer"}}}
/// ```
public class StructuredOutputGenerator {

    /// Generates a JSON Schema structured output from an instance of any type.
    ///
    /// This method uses reflection to introspect the given instance and generate
    /// a corresponding JSON Schema. It handles various Swift types including:
    /// - Primitive types (String, Int, Bool, etc.)
    /// - Foundation types (Date, URL, UUID)
    /// - Collections (Array, Dictionary)
    /// - Custom structs and classes
    /// - Optional types
    ///
    /// - Parameter instance: The instance to generate a schema from
    /// - Returns: A dictionary representing the JSON Schema for the instance's type
    ///
    /// ## Example
    /// ```swift
    /// let person = Person(name: "John", age: 30)
    /// let schema = StructuredOutputGenerator.generateStructuredOutput(for: person)
    /// ```
    public static func generateStructuredOutput(for instance: Any) -> [String: Any] {
        let mirror = Mirror(reflecting: instance)

        // First check for known Foundation types that appear as structs
        switch instance {
        case is Date:
            return ["type": "string", "format": "date-time"]
        case is URL:
            return ["type": "string", "format": "uri"]
        case is UUID:
            return ["type": "string", "format": "uuid"]
        default:
            break
        }

        // Check if it's a primitive or special type
        if mirror.displayStyle == nil || mirror.displayStyle == .optional {
            if let schema = structuredOutputForValue(instance) {
                return schema
            }
        }

        // For structs and classes, use mirror-based generation
        if mirror.displayStyle == .struct || mirror.displayStyle == .class {
            return generateStructuredOutputFromMirror(mirror)
        }

        // For other types (collections, enums, etc.), try value-based detection
        if let schema = structuredOutputForValue(instance) {
            return schema
        }

        // Default fallback
        return generateStructuredOutputFromMirror(mirror)
    }

    /// Generates a JSON Schema structured output for a type conforming to `StructuredOutputConvertible`.
    ///
    /// This method delegates to the type's own `generateStructuredOutput()` implementation,
    /// allowing custom types to define their own schema generation logic.
    ///
    /// - Parameter type: The type conforming to `StructuredOutputConvertible`
    /// - Returns: A dictionary representing the JSON Schema for the type
    ///
    /// ## Example
    /// ```swift
    /// struct CustomType: StructuredOutputConvertible {
    ///     static func generateStructuredOutput() -> [String: Any] {
    ///         return ["type": "object", "properties": ["custom": ["type": "string"]]]
    ///     }
    /// }
    ///
    /// let schema = StructuredOutputGenerator.generateStructuredOutput(for: CustomType.self)
    /// ```
    public static func generateStructuredOutput<T: StructuredOutputConvertible>(for type: T.Type)
        -> [String: Any]
    {
        return type.generateStructuredOutput()
    }

    /// Generates a JSON Schema structured output for any Swift type.
    ///
    /// This is a convenience method that attempts to generate a schema for any type,
    /// even those that don't conform to `StructuredOutputConvertible`. It uses
    /// type introspection to determine the appropriate schema.
    ///
    /// - Parameter type: The Swift type to generate a schema for
    /// - Returns: A dictionary representing the JSON Schema, defaults to `{"type": "object"}` if type cannot be determined
    ///
    /// ## Example
    /// ```swift
    /// let schema = StructuredOutputGenerator.generateStructuredOutput(for: String.self)
    /// // Results in: {"type": "string"}
    /// ```
    public static func generateStructuredOutput(for type: Any.Type) -> [String: Any] {
        return structuredOutputForType(type) ?? ["type": "object"]
    }

    /// Generates a JSON Schema structured output from a Mirror reflection.
    ///
    /// This method processes the properties of a type through its Mirror representation,
    /// creating a JSON Schema object with properties and required fields. It handles:
    /// - Property detection and naming
    /// - Required vs optional properties
    /// - Properties marked with `@StructuredOutput.Ignored`
    /// - Nested object structures
    ///
    /// - Parameter mirror: The Mirror reflection of the type to process
    /// - Returns: A dictionary representing a JSON Schema object with properties
    ///
    /// ## Note
    /// Properties marked with `@StructuredOutput.Ignored` will be excluded from the schema.
    /// Non-optional properties are automatically marked as required.
    public static func generateStructuredOutputFromMirror(_ mirror: Mirror) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []

        for child in mirror.children {
            guard let propertyName = child.label else {
                continue
            }

            // Skip properties marked with @StructuredOutputIgnored
            if isStructuredOutputIgnored(child.value) {
                continue
            }

            // Get the structured output for this property
            if let schema = structuredOutputForValue(child.value) {
                properties[propertyName] = schema

                // Check if property is required
                if isRequiredProperty(child.value) || !(isOptional(child.value)) {
                    required.append(propertyName)
                }
            }
        }

        var schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false,
        ]

        if !required.isEmpty {
            schema["required"] = required
        }

        return schema
    }

    /// Determines the JSON Schema for a given value by examining its type and structure.
    ///
    /// This internal method handles the type detection logic for individual values,
    /// including unwrapping optionals and delegating to appropriate schema generators.
    ///
    /// - Parameter value: The value to generate a schema for
    /// - Returns: An optional dictionary representing the JSON Schema, or nil if the type cannot be determined
    ///
    /// ## Note
    /// This method is primarily used internally by other schema generation methods.
    static func structuredOutputForValue(_ value: Any) -> [String: Any]? {
        let mirror = Mirror(reflecting: value)

        // Get the actual type, handling optionals
        let actualValue: Any
        if mirror.displayStyle == .optional, let first = mirror.children.first {
            actualValue = first.value
        } else {
            actualValue = value
        }

        // Try to determine structured output from the value
        return structuredOutputForType(type(of: actualValue), value: actualValue)
    }

    /// Checks if a value is wrapped in an Optional type.
    ///
    /// - Parameter value: The value to check
    /// - Returns: `true` if the value is optional, `false` otherwise
    private static func isOptional(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional
    }

    /// Checks if a value is marked to be ignored in structured output generation.
    ///
    /// This method looks for property wrappers like `@StructuredOutput.Ignored` or
    /// the deprecated `@SchemaIgnored` wrapper.
    ///
    /// - Parameter value: The value to check
    /// - Returns: `true` if the value should be ignored, `false` otherwise
    private static func isStructuredOutputIgnored(_ value: Any) -> Bool {
        // Check if the type name contains StructuredOutputIgnored
        let typeName = String(describing: type(of: value))
        return typeName.contains("StructuredOutputIgnored") || typeName.contains("SchemaIgnored")  // SchemaIgnored for backward compatibility
    }

    /// Checks if a property is explicitly marked as required.
    ///
    /// This method detects the `@StructuredOutput.Required` property wrapper.
    ///
    /// - Parameter value: The property value to check
    /// - Returns: `true` if the property is marked as required, `false` otherwise
    ///
    /// ## Note
    /// Properties wrapped in `Optional<Required<T>>` are not considered required.
    private static func isRequiredProperty(_ value: Any) -> Bool {
        // Check if the type name contains Required
        let typeName = String(describing: type(of: value))
        return typeName.contains("Required<") && !typeName.contains("Optional<Required")
    }

    /// Generates a JSON Schema for a specific Swift type.
    ///
    /// This method contains the core type mapping logic, converting Swift types
    /// to their JSON Schema equivalents. It handles:
    /// - Primitive types (String, Int, Bool, etc.)
    /// - Numeric types with appropriate constraints
    /// - Foundation types (Date, URL, UUID)
    /// - Collections (Array, Dictionary)
    /// - Custom types conforming to `StructuredOutputConvertible`
    ///
    /// - Parameters:
    ///   - type: The Swift type to generate a schema for
    ///   - value: An optional value instance for extracting additional constraints
    /// - Returns: An optional dictionary representing the JSON Schema
    private static func structuredOutputForType(_ type: Any.Type, value: Any? = nil) -> [String:
        Any]?
    {
        switch type {
        case is String.Type, is String?.Type:
            return stringStructuredOutput(for: value)
        case is Int.Type, is Int?.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type:
            return integerStructuredOutput(for: value)
        case is UInt.Type, is UInt?.Type, is UInt8.Type, is UInt16.Type, is UInt32.Type,
            is UInt64.Type:
            return integerStructuredOutput(for: value, minimum: 0)
        case is Float.Type, is Float?.Type, is Double.Type, is Double?.Type:
            return numberStructuredOutput(for: value)
        case is Bool.Type, is Bool?.Type:
            return ["type": "boolean"]
        case is Date.Type, is Date?.Type:
            return ["type": "string", "format": "date-time"]
        case is URL.Type, is URL?.Type:
            return ["type": "string", "format": "uri"]
        case is UUID.Type, is UUID?.Type:
            return ["type": "string", "format": "uuid"]
        default:
            // Check for arrays
            let typeString = String(describing: type)
            if typeString.hasPrefix("Array<") || typeString.hasPrefix("Optional<Array<") {
                return arrayStructuredOutput(for: type)
            }

            // Check for dictionaries
            if typeString.hasPrefix("Dictionary<") || typeString.hasPrefix("Optional<Dictionary<") {
                return ["type": "object", "additionalProperties": true]
            }

            // Check for custom types that conform to StructuredOutputConvertible
            if let schemaType = type as? StructuredOutputConvertible.Type {
                return schemaType.generateStructuredOutput()
            }

            // Default to object for unknown types
            return ["type": "object"]
        }
    }

    /// Generates a JSON Schema for string types with optional constraints.
    ///
    /// If the value is wrapped in a `StructuredOutput.Property`, this method
    /// extracts additional constraints such as:
    /// - description
    /// - pattern (regex)
    /// - minLength/maxLength
    /// - enum values
    /// - examples
    ///
    /// - Parameter value: An optional value that may contain property constraints
    /// - Returns: A dictionary representing a string JSON Schema
    private static func stringStructuredOutput(for value: Any?) -> [String: Any] {
        var schema: [String: Any] = ["type": "string"]

        if let property = value as? StructuredOutput.Property<String> {
            if let description = property.description {
                schema["description"] = description
            }
            if let pattern = property.pattern {
                schema["pattern"] = pattern
            }
            if let minLength = property.minLength {
                schema["minLength"] = minLength
            }
            if let maxLength = property.maxLength {
                schema["maxLength"] = maxLength
            }
            if let enumValues = property.enumValues {
                schema["enum"] = enumValues
            }
            if let examples = property.examples {
                schema["examples"] = examples
            }
        }

        return schema
    }

    /// Generates a JSON Schema for integer types with optional constraints.
    ///
    /// If the value is wrapped in a `StructuredOutput.Property`, this method
    /// extracts additional constraints such as:
    /// - description
    /// - minimum/maximum values
    /// - examples
    ///
    /// - Parameters:
    ///   - value: An optional value that may contain property constraints
    ///   - minimum: An optional minimum value (used for unsigned integers)
    /// - Returns: A dictionary representing an integer JSON Schema
    private static func integerStructuredOutput(for value: Any?, minimum: Int? = nil) -> [String:
        Any]
    {
        var schema: [String: Any] = ["type": "integer"]

        if let min = minimum {
            schema["minimum"] = min
        }

        if let property = value as? StructuredOutput.Property<Int> {
            if let description = property.description {
                schema["description"] = description
            }
            if let min = property.minimum {
                schema["minimum"] = Int(min)
            }
            if let max = property.maximum {
                schema["maximum"] = Int(max)
            }
            if let examples = property.examples {
                schema["examples"] = examples
            }
        }

        return schema
    }

    /// Generates a JSON Schema for floating-point number types with optional constraints.
    ///
    /// If the value is wrapped in a `StructuredOutput.Property`, this method
    /// extracts additional constraints such as:
    /// - description
    /// - minimum/maximum values
    /// - examples
    ///
    /// - Parameter value: An optional value that may contain property constraints
    /// - Returns: A dictionary representing a number JSON Schema
    private static func numberStructuredOutput(for value: Any?) -> [String: Any] {
        var schema: [String: Any] = ["type": "number"]

        if let property = value as? StructuredOutput.Property<Double> {
            if let description = property.description {
                schema["description"] = description
            }
            if let min = property.minimum {
                schema["minimum"] = min
            }
            if let max = property.maximum {
                schema["maximum"] = max
            }
            if let examples = property.examples {
                schema["examples"] = examples
            }
        }

        return schema
    }

    /// Generates a JSON Schema for array types.
    ///
    /// This method attempts to determine the element type of the array
    /// and creates an appropriate schema with items constraint.
    ///
    /// - Parameter type: The array type to generate a schema for
    /// - Returns: A dictionary representing an array JSON Schema
    ///
    /// ## Note
    /// The method uses string parsing to extract the element type, which
    /// works for common types but may default to object for complex types.
    private static func arrayStructuredOutput(for type: Any.Type) -> [String: Any] {
        var schema: [String: Any] = ["type": "array"]

        // Extract element type from array
        let typeString = String(describing: type)
        if let startIndex = typeString.firstIndex(of: "<"),
            let endIndex = typeString.lastIndex(of: ">")
        {
            let elementTypeString = String(
                typeString[typeString.index(after: startIndex)..<endIndex])

            // Map common types
            switch elementTypeString {
            case "String":
                schema["items"] = ["type": "string"]
            case "Int", "Int8", "Int16", "Int32", "Int64":
                schema["items"] = ["type": "integer"]
            case "Float", "Double":
                schema["items"] = ["type": "number"]
            case "Bool":
                schema["items"] = ["type": "boolean"]
            default:
                schema["items"] = ["type": "object"]
            }
        }

        return schema
    }
}
