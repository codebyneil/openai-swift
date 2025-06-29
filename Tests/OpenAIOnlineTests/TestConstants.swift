import Foundation

enum TestConstants {
    static let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    static let organization: String? = nil
    static let testTimeout: TimeInterval = 30.0
    static let streamTimeout: TimeInterval = 60.0

    enum Models {
        static let chat = "gpt-3.5-turbo-0125"
        static let embedding = "text-embedding-ada-002"
        static let image = "dall-e-3"
        static let audio = "whisper-1"
        static let nonExistentModel = "no-such-model"
        static let dallE2 = "dall-e-2"
    }
}
