import Foundation
import OpenAICore

/// Extension providing embedding-related functionality for the OpenAI API.
extension OpenAI {
    /**
     Creates embeddings for the provided input text.
    
     Embeddings are numerical representations of text that can be used to measure
     the relatedness between text strings. They are commonly used for:
     - Search (ranking results by relevance)
     - Clustering (grouping text by similarity)
     - Recommendations (finding related items)
     - Anomaly detection (identifying outliers)
     - Classification (categorizing text)
    
     - Parameter request: An `EmbeddingRequest` containing the input text and configuration parameters.
     - Returns: An `EmbeddingResponse` containing the generated embeddings and usage information.
     - Throws: `OpenAIError` if the request fails, exceeds token limits, or the response cannot be decoded.
    
     ## Example
     ```swift
     let openAI = OpenAI(apiKey: "your-api-key")
     let request = EmbeddingRequest(
         model: "text-embedding-ada-002",
         input: "The quick brown fox jumps over the lazy dog"
     )
    
     do {
         let response = try await openAI.createEmbedding(request)
         if let embedding = response.data.first {
             print("Embedding dimensions: \(embedding.embedding.count)")
             print("Total tokens used: \(response.usage.totalTokens)")
         }
     } catch {
         print("Failed to create embedding: \(error)")
     }
     ```
    
     ## Batch Processing Example
     ```swift
     let batchRequest = EmbeddingRequest(
         model: "text-embedding-ada-002",
         input: [
             "First text to embed",
             "Second text to embed",
             "Third text to embed"
         ]
     )
    
     let batchResponse = try await openAI.createEmbedding(batchRequest)
     for (index, embedding) in batchResponse.data.enumerated() {
         print("Text \(index + 1) embedding: \(embedding.embedding.prefix(5))...")
     }
     ```
    
     - Important: The maximum input size varies by model. For text-embedding-ada-002,
       the maximum is 8,191 tokens. Longer inputs will be truncated.
    
     - Note: Embeddings are normalized to unit length, meaning the dot product of
       an embedding with itself equals 1.0, which is useful for cosine similarity calculations.
    
     - SeeAlso: `EmbeddingRequest` for available configuration options.
     */
    public func createEmbedding(_ request: EmbeddingRequest) async throws -> EmbeddingResponse {
        let (data, response) = try await makeRequest(endpoint: "embeddings", body: request)
        return try decodeResponse(EmbeddingResponse.self, from: data, response: response)
    }
}
