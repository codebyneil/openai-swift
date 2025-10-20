import XCTest

@testable import OpenAICore

final class BaseURLTests: XCTestCase {
    func testDefaultBaseURL() {
        let api = OpenAI(apiKey: "test-key")
        XCTAssertEqual(api.baseURL.absoluteString, "https://api.openai.com/v1")
    }

    func testCustomBaseURL() {
        let customURL = URL(string: "https://custom.openai.com/v2")!
        let api = OpenAI(apiKey: "test-key", baseURL: customURL)
        XCTAssertEqual(api.baseURL, customURL)
    }

    func testCustomBaseURLWithOrganization() {
        let customURL = URL(string: "https://enterprise.openai.com/api")!
        let api = OpenAI(apiKey: "test-key", organization: "org-123", baseURL: customURL)
        XCTAssertEqual(api.baseURL, customURL)
        XCTAssertEqual(api.organization, "org-123")
    }
}
