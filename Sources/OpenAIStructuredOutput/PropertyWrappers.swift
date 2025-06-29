import Foundation

/// This file provides backward compatibility type aliases for legacy code.
///
/// The property wrappers have been moved to the `StructuredOutput` namespace
/// for better organization. These aliases ensure existing code continues to work
/// while encouraging migration to the new names.
///
/// ## Migration Guide
/// - `@SchemaProperty` → `@StructuredOutput.Property`
/// - `@Required` → `@StructuredOutput.Required`
/// - `@SchemaIgnored` → `@StructuredOutput.Ignored`

/// Legacy alias for `StructuredOutput.Property`.
///
/// - Important: This type alias is deprecated. Use `StructuredOutput.Property` instead.
@available(*, deprecated, renamed: "StructuredOutput.Property")
public typealias SchemaProperty = StructuredOutput.Property

/// Legacy alias for `StructuredOutput.Required`.
///
/// - Important: This type alias is deprecated. Use `StructuredOutput.Required` instead.
@available(*, deprecated, renamed: "StructuredOutput.Required")
public typealias Required = StructuredOutput.Required

/// Legacy alias for `StructuredOutput.Ignored`.
///
/// - Important: This type alias is deprecated. Use `StructuredOutput.Ignored` instead.
@available(*, deprecated, renamed: "StructuredOutput.Ignored")
public typealias SchemaIgnored = StructuredOutput.Ignored
