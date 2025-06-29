import Foundation
import Testing

/// Call at the start of a test to ensure live credentials are available.
/// Throws `TestSkip` when `OPENAI_API_KEY` is not present so the test is marked as skipped
/// rather than failing with a network/authentication error.
@inline(__always)
func requireLiveTests() throws {
    try #require(
        !TestConstants.apiKey.isEmpty,
        "OPENAI_API_KEY not set; skipping live tests"
    )
}

/// Replaces hard-coded `Task.sleep` calls with a polling helper so tests fail
/// faster when a condition is already met and remain responsive under slow networks.
@discardableResult
func waitUntil(
    timeout: TimeInterval = TestConstants.testTimeout,
    poll: TimeInterval = 0.1,
    _ predicate: @escaping () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() && Date() < deadline {
        try? await Task.sleep(for: .milliseconds(Int(poll * 1000)))
    }
    return predicate()
}
