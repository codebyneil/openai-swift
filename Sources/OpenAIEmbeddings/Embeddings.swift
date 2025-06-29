import Foundation
import OpenAICore

/// A request to create embeddings.
///
/// Embeddings are numerical representations of text that can be used for
/// semantic search, clustering, and other machine learning tasks.
///
/// ## Example
/// ```swift
/// let request = EmbeddingRequest(
///     input: .string("Swift is a great programming language"),
///     model: "text-embedding-ada-002"
/// )
/// ```
public struct EmbeddingRequest: Codable, Sendable {
    /// The input text to embed, encoded as a string or array of strings.
    public let input: TextInput

    /// ID of the model to use (e.g., "text-embedding-ada-002").
    public let model: String

    /// The format to return the embeddings in.
    public let encodingFormat: EncodingFormat?

    /// The number of dimensions the resulting output embeddings should have.
    public let dimensions: Int?

    /// A unique identifier representing your end-user.
    public let user: String?

    public init(
        input: TextInput,
        model: String,
        encodingFormat: EncodingFormat? = nil,
        dimensions: Int? = nil,
        user: String? = nil
    ) {
        self.input = input
        self.model = model
        self.encodingFormat = encodingFormat
        self.dimensions = dimensions
        self.user = user
    }

    private enum CodingKeys: String, CodingKey {
        case input, model, dimensions, user
        case encodingFormat = "encoding_format"
    }
}

/// The format for embedding vectors.
public enum EncodingFormat: String, Codable, Sendable {
    /// Return embeddings as an array of floats (default).
    case float

    /// Return embeddings as a base64-encoded string.
    case base64
}

/// The response from an embedding request.
public struct EmbeddingResponse: Codable, Sendable {
    /// Object type, always "list".
    public let object: String

    /// List of embedding objects.
    public let data: [EmbeddingData]

    /// The model used to generate the embeddings.
    public let model: String

    /// Token usage statistics.
    public let usage: EmbeddingUsage
}

/// A single embedding vector.
public struct EmbeddingData: Codable, Sendable {
    /// Object type, always "embedding".
    public let object: String

    /// The index of the embedding in the list of embeddings.
    public let index: Int

    /// The embedding vector.
    public let embedding: [Double]
}

/// Token usage statistics for an embedding request.
public struct EmbeddingUsage: Codable, Sendable {
    /// The number of tokens used by the prompt.
    public let promptTokens: Int
    public let totalTokens: Int
}
