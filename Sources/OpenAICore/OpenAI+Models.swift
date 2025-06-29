import Foundation

/// Extension providing model-related functionality for the OpenAI API.
extension OpenAI {
    /// Lists all available models from the OpenAI API.
    ///
    /// This method retrieves a list of all models that are currently available for use
    /// with your API key. The list includes both base models and fine-tuned models.
    ///
    /// - Returns: A `ModelList` containing an array of available models with their details.
    /// - Throws: `OpenAIError` if the request fails or the response cannot be decoded.
    ///
    /// ## Example
    /// ```swift
    /// let openAI = OpenAI(apiKey: "your-api-key")
    /// do {
    ///     let models = try await openAI.listModels()
    ///     for model in models.data {
    ///         print("Model ID: \(model.id)")
    ///     }
    /// } catch {
    ///     print("Failed to list models: \(error)")
    /// }
    /// ```
    ///
    /// - Note: The response includes both OpenAI's base models (like gpt-4, gpt-3.5-turbo)
    ///   and any fine-tuned models associated with your organization.
    public func listModels() async throws -> ModelList {
        let (data, response) = try await makeRequest(endpoint: "models")
        return try decodeResponse(ModelList.self, from: data, response: response)
    }

    /// Retrieves detailed information about a specific model.
    ///
    /// This method fetches comprehensive details about a single model, including
    /// its capabilities, ownership, permissions, and creation date.
    ///
    /// - Parameter modelId: The identifier of the model to retrieve (e.g., "gpt-4", "gpt-3.5-turbo").
    /// - Returns: A `ModelDetails` object containing comprehensive information about the specified model.
    /// - Throws: `OpenAIError` if the request fails, the model doesn't exist, or the response cannot be decoded.
    ///
    /// ## Example
    /// ```swift
    /// let openAI = OpenAI(apiKey: "your-api-key")
    /// do {
    ///     let modelDetails = try await openAI.retrieveModel(modelId: "gpt-4")
    ///     print("Model: \(modelDetails.id)")
    ///     print("Created: \(modelDetails.created)")
    ///     print("Owned by: \(modelDetails.ownedBy)")
    /// } catch {
    ///     print("Failed to retrieve model details: \(error)")
    /// }
    /// ```
    ///
    /// - Important: Ensure the modelId parameter matches exactly with the model identifier
    ///   as returned by `listModels()`. Model IDs are case-sensitive.
    public func retrieveModel(modelId: String) async throws -> ModelDetails {
        let (data, response) = try await makeRequest(endpoint: "models/\(modelId)")
        return try decodeResponse(ModelDetails.self, from: data, response: response)
    }
}
