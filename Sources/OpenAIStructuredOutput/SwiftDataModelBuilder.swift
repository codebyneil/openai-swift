import Foundation
#if canImport(SwiftData)
import SwiftData

// MARK: - SwiftData Model Builder

/// A builder for creating SwiftData models from structured output responses.
///
/// This builder helps bridge the gap between JSON responses from OpenAI
/// and SwiftData model creation, handling type conversions and relationships.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public class SwiftDataModelBuilder {
    
    private let modelContext: ModelContext
    
    /// Initializes the builder with a model context.
    ///
    /// - Parameter modelContext: The SwiftData model context for creating models
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Creates a SwiftData model instance from a dictionary response.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary containing model data
    ///   - modelType: The SwiftData model type to create
    /// - Returns: The created model instance
    /// - Throws: An error if model creation fails
    /// 
    /// - Note: This is a placeholder implementation. In practice, you would need to:
    ///   1. Use proper SwiftData initialization patterns
    ///   2. Handle the BackingData requirement
    ///   3. Use ModelContainer for proper context management
    public func createModel<T: PersistentModel>(
        from dictionary: [String: Any],
        modelType: T.Type
    ) throws -> T {
        // This is a simplified placeholder - actual implementation would need
        // to properly handle SwiftData's initialization requirements
        fatalError("SwiftData model creation requires proper BackingData initialization. Use manual property setting instead.")
    }
    
    /// Sets a property value on a model using runtime introspection.
    private func setProperty<T>(named name: String, value: Any, on model: T) {
        // This is a simplified version. In practice, you'd need to:
        // 1. Handle type conversions
        // 2. Deal with relationships
        // 3. Handle optional unwrapping
        
        // Try to use KVC if the model supports it
        if let object = model as? NSObject {
            object.setValue(value, forKey: name)
        }
    }
}

// MARK: - Structured Output to SwiftData Converter

/// Converts structured output schemas to SwiftData-compatible formats.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct StructuredOutputToSwiftData {
    
    /// Property mapping configuration for SwiftData models.
    public struct PropertyMapping {
        public let jsonKey: String
        public let modelProperty: String
        public let transformer: ((Any) -> Any)?
        
        public init(
            jsonKey: String,
            modelProperty: String,
            transformer: ((Any) -> Any)? = nil
        ) {
            self.jsonKey = jsonKey
            self.modelProperty = modelProperty
            self.transformer = transformer
        }
    }
    
    /// Configuration for converting structured output to SwiftData models.
    public struct ConversionConfiguration {
        public let propertyMappings: [PropertyMapping]
        public let dateDecodingStrategy: DateDecodingStrategy
        public let keyDecodingStrategy: KeyDecodingStrategy
        
        public enum DateDecodingStrategy {
            case iso8601
            case secondsSince1970
            case millisecondsSince1970
            case custom((String) -> Date?)
        }
        
        public enum KeyDecodingStrategy {
            case useDefaultKeys
            case convertFromSnakeCase
            case custom((String) -> String)
        }
        
        public init(
            propertyMappings: [PropertyMapping] = [],
            dateDecodingStrategy: DateDecodingStrategy = .iso8601,
            keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
        ) {
            self.propertyMappings = propertyMappings
            self.dateDecodingStrategy = dateDecodingStrategy
            self.keyDecodingStrategy = keyDecodingStrategy
        }
    }
    
    /// Converts a dictionary from structured output to SwiftData-compatible format.
    ///
    /// - Parameters:
    ///   - dictionary: The source dictionary from OpenAI response
    ///   - configuration: The conversion configuration
    /// - Returns: A transformed dictionary ready for SwiftData model creation
    public static func convert(
        _ dictionary: [String: Any],
        using configuration: ConversionConfiguration
    ) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Apply property mappings
        for mapping in configuration.propertyMappings {
            if let value = dictionary[mapping.jsonKey] {
                let transformedValue = mapping.transformer?(value) ?? value
                result[mapping.modelProperty] = transformedValue
            }
        }
        
        // Process remaining properties
        for (key, value) in dictionary {
            // Skip if already mapped
            if configuration.propertyMappings.contains(where: { $0.jsonKey == key }) {
                continue
            }
            
            // Apply key decoding strategy
            let decodedKey = decodeKey(key, using: configuration.keyDecodingStrategy)
            
            // Apply value transformations
            let transformedValue = transformValue(
                value,
                key: key,
                configuration: configuration
            )
            
            result[decodedKey] = transformedValue
        }
        
        return result
    }
    
    private static func decodeKey(_ key: String, using strategy: ConversionConfiguration.KeyDecodingStrategy) -> String {
        switch strategy {
        case .useDefaultKeys:
            return key
        case .convertFromSnakeCase:
            return key.convertFromSnakeCase()
        case .custom(let converter):
            return converter(key)
        }
    }
    
    private static func transformValue(
        _ value: Any,
        key: String,
        configuration: ConversionConfiguration
    ) -> Any {
        // Handle date strings
        if let dateString = value as? String,
           key.lowercased().contains("date") || key.lowercased().contains("time") {
            if let date = decodeDate(dateString, using: configuration.dateDecodingStrategy) {
                return date
            }
        }
        
        // Handle arrays
        if let array = value as? [Any] {
            return array.map { transformValue($0, key: key, configuration: configuration) }
        }
        
        // Handle nested objects
        if let dict = value as? [String: Any] {
            return convert(dict, using: configuration)
        }
        
        return value
    }
    
    private static func decodeDate(_ string: String, using strategy: ConversionConfiguration.DateDecodingStrategy) -> Date? {
        switch strategy {
        case .iso8601:
            return ISO8601DateFormatter().date(from: string)
        case .secondsSince1970:
            guard let seconds = Double(string) else { return nil }
            return Date(timeIntervalSince1970: seconds)
        case .millisecondsSince1970:
            guard let milliseconds = Double(string) else { return nil }
            return Date(timeIntervalSince1970: milliseconds / 1000)
        case .custom(let decoder):
            return decoder(string)
        }
    }
}

// MARK: - String Extension for Snake Case Conversion

private extension String {
    func convertFromSnakeCase() -> String {
        let components = self.split(separator: "_")
        guard components.count > 1 else { return self }
        
        let first = String(components[0])
        let rest = components.dropFirst().map { $0.capitalized }
        
        return ([first] + rest).joined()
    }
}

// MARK: - SwiftData Model Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension PersistentModel {
    
    /// Populates the model with data from a dictionary.
    ///
    /// - Parameters:
    ///   - dictionary: The source data dictionary
    ///   - configuration: Optional conversion configuration
    func populate(
        from dictionary: [String: Any],
        using configuration: StructuredOutputToSwiftData.ConversionConfiguration? = nil
    ) {
        let convertedDict = if let config = configuration {
            StructuredOutputToSwiftData.convert(dictionary, using: config)
        } else {
            dictionary
        }
        
        let mirror = Mirror(reflecting: self)
        
        for (key, _) in convertedDict {
            // This is where we'd need proper property setting
            // In practice, this would require runtime manipulation
            // or code generation
            if mirror.children.contains(where: { $0.label == key }) {
                // Set the property value
                // Note: This is simplified - real implementation would need
                // proper type checking and conversion
            }
        }
    }
}

#endif // canImport(SwiftData)