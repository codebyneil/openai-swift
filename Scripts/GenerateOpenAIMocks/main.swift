import Foundation
import OpenAISwift

@main
struct GenerateOpenAIMocks {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty
        else {
            print("⚠️  Please set the OPENAI_API_KEY environment variable before running.")
            return
        }

        let organization = ProcessInfo.processInfo.environment["OPENAI_ORGANIZATION"]
        let api = OpenAI(apiKey: apiKey, organization: organization)

        // Directory where fixtures will be written
        let outputDir = URL(
            fileURLWithPath: "Tests/OpenAIOfflineTests/Fixtures",
            relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        enum Endpoint: String, CaseIterable {
            case chatCompletion = "chat_completion"
            case chatCompletionFunctions = "chat_completion_functions"
            case embedding = "embedding"
            case imageGeneration = "image_generation"
            case modelsList = "models_list"
        }

        for endpoint in Endpoint.allCases {
            do {
                switch endpoint {
                case .chatCompletion:
                    let request = ChatRequest(
                        model: "gpt-3.5-turbo",
                        messages: [ChatMessage(role: .user, content: .text("Say hello"))],
                        temperature: 0.0,
                        maxTokens: 10
                    )
                    let response = try await api.createChatCompletion(request)
                    try writeJSON(response, name: endpoint.rawValue, to: outputDir)

                case .chatCompletionFunctions:
                    let weatherFunction = FunctionDefinition(
                        name: "get_weather",
                        description: "Get the current weather in a given location",
                        parameters: [
                            "type": "object",
                            "properties": [
                                "location": ["type": "string"],
                                "unit": ["type": "string", "enum": ["celsius", "fahrenheit"]],
                            ],
                            "required": ["location"],
                        ]
                    )
                    let request = ChatRequest(
                        model: "gpt-3.5-turbo",
                        messages: [ChatMessage(role: .user, content: .text("Weather in London?"))],
                        temperature: 0.0,
                        tools: [ChatTool(function: weatherFunction)],
                        toolChoice: .auto
                    )
                    let response = try await api.createChatCompletion(request)
                    try writeJSON(response, name: endpoint.rawValue, to: outputDir)

                case .embedding:
                    let request = EmbeddingRequest(
                        input: .string("Hello world"),
                        model: "text-embedding-ada-002"
                    )
                    let response = try await api.createEmbedding(request)
                    try writeJSON(response, name: endpoint.rawValue, to: outputDir)

                case .imageGeneration:
                    let request = ImageGenerationRequest(
                        prompt: "A red apple on a white background",
                        model: "dall-e-3",
                        n: 1,
                        responseFormat: .url,
                        size: .size1024x1024
                    )
                    let response = try await api.createImage(request)
                    try writeJSON(response, name: endpoint.rawValue, to: outputDir)

                case .modelsList:
                    let response = try await api.listModels()
                    try writeJSON(response, name: endpoint.rawValue, to: outputDir)
                }

                print("✅ Captured \(endpoint.rawValue)")
            } catch {
                print("⚠️  Failed to capture \(endpoint.rawValue): \(error)")
            }
        }

        print("✨ Fixtures written to \(outputDir.path)")
    }

    private static func writeJSON<T: Encodable>(_ value: T, name: String, to directory: URL) throws
    {
        let url = directory.appendingPathComponent("\(name).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url)
    }
}
