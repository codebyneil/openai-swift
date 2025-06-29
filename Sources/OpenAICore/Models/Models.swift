import Foundation

/// Response containing a list of available OpenAI models.
///
/// This structure represents the response from the OpenAI Models API endpoint,
/// containing an array of available models and their details.
///
/// Example usage:
/// ```swift
/// let modelList: ModelList = // response from API
/// for model in modelList.data {
///     print("Model: \(model.id), Owner: \(model.ownedBy ?? "Unknown")")
/// }
/// ```
public struct ModelList: Codable, Sendable {
    /// The object type, which is always "list" for model lists.
    public let object: String

    /// An array of available models with their details.
    public let data: [ModelDetails]
}

/// Detailed information about a specific OpenAI model.
///
/// This structure contains metadata about an individual model available through
/// the OpenAI API, including its identifier, creation timestamp, and ownership information.
///
/// Example usage:
/// ```swift
/// let model: ModelDetails = // model from API
/// if model.id.contains("gpt-4") {
///     print("This is a GPT-4 model variant")
/// }
/// ```
///
/// - Note: The `ownedBy` field may be nil for certain models where ownership
///   information is not available or applicable.
public struct ModelDetails: Codable, Sendable {
    /// The unique identifier for the model (e.g., "gpt-3.5-turbo", "gpt-4").
    public let id: String

    /// The object type, which is always "model" for model details.
    public let object: String

    /// Unix timestamp (in seconds) representing when the model was created.
    public let created: Int

    /// The organization that owns the model.
    /// This is typically "openai" for standard models, but may vary for fine-tuned models.
    public let ownedBy: String?

    private enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
    }
}
