import Foundation

/// Namespace for OpenAI structured output property wrappers and utilities.
///
/// `StructuredOutput` provides a collection of property wrappers and utilities
/// for defining structured outputs compatible with OpenAI's JSON Schema format.
/// These wrappers allow you to add metadata and constraints to your Swift properties
/// that will be reflected in the generated JSON Schema.
///
/// ## Example
/// ```swift
/// struct Person {
///     @StructuredOutput.Property(description: "Person's full name", minLength: 1)
///     var name: String = ""
///
///     @StructuredOutput.Required
///     var age: Int = 0
///
///     @StructuredOutput.Ignored
///     var internalId: UUID = UUID()
/// }
/// ```
public enum StructuredOutput {

    /// A property wrapper that adds JSON Schema constraints and metadata to a property.
    ///
    /// Use this wrapper to enhance your properties with additional schema information
    /// such as descriptions, validation patterns, length constraints, and more.
    ///
    /// ## Example
    /// ```swift
    /// struct User {
    ///     @StructuredOutput.Property(
    ///         description: "User's email address",
    ///         pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    ///     )
    ///     var email: String = ""
    ///
    ///     @StructuredOutput.Property(
    ///         description: "User's age in years",
    ///         minimum: 0,
    ///         maximum: 150
    ///     )
    ///     var age: Int = 0
    /// }
    /// ```
    @propertyWrapper
    public struct Property<Value> {
        public var wrappedValue: Value
        public let description: String?
        public let examples: [Any]?
        public let pattern: String?
        public let minimum: Double?
        public let maximum: Double?
        public let minLength: Int?
        public let maxLength: Int?
        public let enumValues: [Any]?

        /// Creates a property wrapper with JSON Schema constraints.
        ///
        /// - Parameters:
        ///   - wrappedValue: The initial value of the property
        ///   - description: A description of the property for documentation
        ///   - examples: An array of example values for the property
        ///   - pattern: A regex pattern for string validation
        ///   - minimum: The minimum value for numeric types
        ///   - maximum: The maximum value for numeric types
        ///   - minLength: The minimum length for string types
        ///   - maxLength: The maximum length for string types
        ///   - enumValues: An array of allowed values (creates an enum constraint)
        ///
        /// ## Note
        /// Not all parameters apply to all types. For example, `pattern` only applies
        /// to strings, while `minimum`/`maximum` apply to numeric types.
        public init(
            wrappedValue: Value,
            description: String? = nil,
            examples: [Any]? = nil,
            pattern: String? = nil,
            minimum: Double? = nil,
            maximum: Double? = nil,
            minLength: Int? = nil,
            maxLength: Int? = nil,
            enumValues: [Any]? = nil
        ) {
            self.wrappedValue = wrappedValue
            self.description = description
            self.examples = examples
            self.pattern = pattern
            self.minimum = minimum
            self.maximum = maximum
            self.minLength = minLength
            self.maxLength = maxLength
            self.enumValues = enumValues
        }
    }

    /// A property wrapper that marks a property as required in the JSON Schema.
    ///
    /// Properties wrapped with `@Required` will be included in the "required"
    /// array of the generated JSON Schema, indicating that they must be present
    /// in valid JSON data.
    ///
    /// ## Example
    /// ```swift
    /// struct Order {
    ///     @StructuredOutput.Required
    ///     var orderId: String = ""
    ///
    ///     @StructuredOutput.Required
    ///     var totalAmount: Double = 0.0
    ///
    ///     var notes: String? = nil  // Optional field
    /// }
    /// ```
    ///
    /// ## Note
    /// Non-optional properties are automatically considered required unless
    /// explicitly marked with `@Ignored`.
    @propertyWrapper
    public struct Required<Value> {
        public var wrappedValue: Value

        public init(wrappedValue: Value) {
            self.wrappedValue = wrappedValue
        }
    }

    /// A property wrapper that excludes a property from the JSON Schema.
    ///
    /// Properties wrapped with `@Ignored` will not appear in the generated
    /// JSON Schema. This is useful for internal properties, computed properties,
    /// or any data that shouldn't be part of the structured output.
    ///
    /// ## Example
    /// ```swift
    /// struct Product {
    ///     var name: String = ""
    ///     var price: Double = 0.0
    ///
    ///     @StructuredOutput.Ignored
    ///     var internalSKU: String = ""
    ///
    ///     @StructuredOutput.Ignored
    ///     var lastModified: Date = Date()
    /// }
    /// ```
    @propertyWrapper
    public struct Ignored<Value> {
        public var wrappedValue: Value

        public init(wrappedValue: Value) {
            self.wrappedValue = wrappedValue
        }
    }

    /// A property wrapper for optional fields with default values.
    ///
    /// This wrapper allows you to specify a default value for optional properties
    /// in the JSON Schema. When the property is not provided in the JSON data,
    /// the default value will be used.
    ///
    /// ## Example
    /// ```swift
    /// struct Settings {
    ///     @StructuredOutput.Optional(default: "en")
    ///     var language: String = "en"
    ///
    ///     @StructuredOutput.Optional(default: true)
    ///     var notifications: Bool = true
    /// }
    /// ```
    ///
    /// ## Note
    /// This wrapper is different from Swift's optional types. It represents
    /// a property that has a default value in the schema.
    @propertyWrapper
    public struct Optional<Value> {
        public var wrappedValue: Value
        public let defaultValue: Value

        /// Creates an optional property wrapper with a default value.
        ///
        /// - Parameters:
        ///   - wrappedValue: The initial value of the property
        ///   - defaultValue: The default value to use when the property is not provided
        public init(wrappedValue: Value, default defaultValue: Value) {
            self.wrappedValue = wrappedValue
            self.defaultValue = defaultValue
        }
    }

    /// A property wrapper for array properties with JSON Schema constraints.
    ///
    /// This wrapper allows you to add array-specific constraints such as
    /// minimum/maximum item counts and uniqueness requirements.
    ///
    /// ## Example
    /// ```swift
    /// struct ShoppingCart {
    ///     @StructuredOutput.Array(minItems: 1, maxItems: 100)
    ///     var items: [String] = []
    ///
    ///     @StructuredOutput.Array(uniqueItems: true)
    ///     var tags: [String] = []
    /// }
    /// ```
    @propertyWrapper
    public struct Array<Element> {
        public var wrappedValue: [Element]
        public let minItems: Int?
        public let maxItems: Int?
        public let uniqueItems: Bool

        /// Creates an array property wrapper with constraints.
        ///
        /// - Parameters:
        ///   - wrappedValue: The initial array value
        ///   - minItems: The minimum number of items allowed in the array
        ///   - maxItems: The maximum number of items allowed in the array
        ///   - uniqueItems: Whether all items in the array must be unique
        ///
        /// ## Note
        /// The `uniqueItems` constraint requires that all items in the array
        /// are distinct when compared using JSON equality.
        public init(
            wrappedValue: [Element],
            minItems: Int? = nil,
            maxItems: Int? = nil,
            uniqueItems: Bool = false
        ) {
            self.wrappedValue = wrappedValue
            self.minItems = minItems
            self.maxItems = maxItems
            self.uniqueItems = uniqueItems
        }
    }
}
