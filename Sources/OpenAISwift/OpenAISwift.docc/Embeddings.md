# Embeddings

Generate vector representations of text for semantic search and similarity comparisons.

## Overview

Embeddings are numerical representations of text that capture semantic meaning. They're useful for:
- Semantic search
- Clustering similar content
- Recommendations
- Anomaly detection
- Classification tasks

## Basic Usage

### Single Text Embedding

```swift
let request = EmbeddingRequest(
    input: .string("Swift is a powerful programming language"),
    model: "text-embedding-ada-002"
)

let response = try await openAI.createEmbedding(request)
let embedding = response.data.first?.embedding ?? []
print("Embedding dimension: \(embedding.count)")
```

### Multiple Text Embeddings

```swift
let texts = [
    "Swift is great for iOS development",
    "Python is popular for machine learning",
    "JavaScript runs in web browsers"
]

let request = EmbeddingRequest(
    input: .array(texts),
    model: "text-embedding-ada-002"
)

let response = try await openAI.createEmbedding(request)
for (index, data) in response.data.enumerated() {
    print("Text \(index): \(data.embedding.count) dimensions")
}
```

## Using with SwiftUI

The Observable wrapper simplifies embedding generation:

```swift
@StateObject private var openAI = OpenAIObservable(apiKey: "your-key")

func searchSimilarContent(query: String, documents: [String]) async {
    // Generate embeddings for all texts
    let allTexts = [query] + documents
    let embeddings = await openAI.generateEmbeddings(for: allTexts)
    
    guard embeddings.count == allTexts.count else {
        print("Error: \(openAI.error?.localizedDescription ?? "Unknown error")")
        return
    }
    
    // Calculate similarities
    let queryEmbedding = embeddings[0]
    let documentEmbeddings = Array(embeddings.dropFirst())
    
    let similarities = documentEmbeddings.map { docEmbedding in
        cosineSimilarity(queryEmbedding, docEmbedding)
    }
    
    // Find most similar documents
    let rankedDocuments = zip(documents, similarities)
        .sorted { $0.1 > $1.1 }
    
    for (doc, similarity) in rankedDocuments {
        print("Similarity: \(similarity) - \(doc)")
    }
}
```

## Similarity Calculations

### Cosine Similarity

```swift
func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count else { return 0 }
    
    let dotProduct = zip(a, b).map(*).reduce(0, +)
    let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    
    guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
    return dotProduct / (magnitudeA * magnitudeB)
}
```

### Euclidean Distance

```swift
func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count else { return .infinity }
    
    return sqrt(zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +))
}
```

## Efficient Storage

### Storing Embeddings

```swift
struct EmbeddingRecord: Codable {
    let text: String
    let embedding: [Double]
    let metadata: [String: String]
    
    // Compress embeddings for storage
    var compressedEmbedding: Data? {
        let floats = embedding.map { Float($0) }
        return floats.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
    
    // Decompress embeddings
    init(text: String, compressedData: Data, metadata: [String: String]) {
        self.text = text
        self.metadata = metadata
        
        let floatCount = compressedData.count / MemoryLayout<Float>.size
        let floats = compressedData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self).prefix(floatCount))
        }
        self.embedding = floats.map { Double($0) }
    }
}
```

## Semantic Search Implementation

```swift
class SemanticSearch {
    private let openAI: OpenAI
    private var documentEmbeddings: [(text: String, embedding: [Double])] = []
    
    init(openAI: OpenAI) {
        self.openAI = openAI
    }
    
    func indexDocuments(_ documents: [String]) async throws {
        let request = EmbeddingRequest(
            input: .array(documents),
            model: "text-embedding-ada-002"
        )
        
        let response = try await openAI.createEmbedding(request)
        
        documentEmbeddings = zip(documents, response.data).map { 
            (text: $0, embedding: $1.embedding)
        }
    }
    
    func search(_ query: String, topK: Int = 5) async throws -> [(text: String, score: Double)] {
        // Get query embedding
        let request = EmbeddingRequest(
            input: .string(query),
            model: "text-embedding-ada-002"
        )
        
        let response = try await openAI.createEmbedding(request)
        guard let queryEmbedding = response.data.first?.embedding else {
            return []
        }
        
        // Calculate similarities
        let results = documentEmbeddings.map { doc in
            let similarity = cosineSimilarity(queryEmbedding, doc.embedding)
            return (text: doc.text, score: similarity)
        }
        
        // Return top K results
        return results
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }
}
```

## Best Practices

1. **Batch Processing**: Process multiple texts in a single request to reduce API calls
2. **Caching**: Store embeddings to avoid regenerating them
3. **Normalization**: Consider normalizing embeddings for consistent similarity calculations
4. **Model Selection**: Choose the appropriate model based on your use case
5. **Token Limits**: Be aware of token limits when embedding long texts

## Token Limits

Different models have different token limits:
- `text-embedding-ada-002`: 8,191 tokens
- `text-embedding-3-small`: 8,191 tokens
- `text-embedding-3-large`: 8,191 tokens

## See Also

- ``EmbeddingRequest``
- ``EmbeddingResponse``
- <doc:ChatCompletions>