import Foundation

/// Errors that can occur when interacting with the OpenAI API.
///
/// This enum encapsulates all possible error conditions, from network failures
/// to API-specific errors.
public enum OpenAIError: LocalizedError {
    /// The server returned a response that couldn't be parsed.
    case invalidResponse

    /// The API returned an error response.
    case apiError(ErrorResponse)

    /// An HTTP error occurred with the specified status code.
    case httpError(statusCode: Int)

    /// Failed to decode the response data. Extra structured `info` helps diagnose problems.
    case decodingError(Error, info: DecodingDebugInfo? = nil)

    /// The URL configuration is invalid.
    case invalidURL

    /// Expected data was missing from the response.
    case missingData

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let errorResponse):
            return errorResponse.error.message
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .decodingError(let error, let info):
            if let info = info {
                return "Decoding error: \(error.localizedDescription) – \(info.humanDescription)"
            }
            return "Decoding error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .missingData:
            return "Missing data in response"
        }
    }
}

/// A structured error response from the OpenAI API.
///
/// This represents the standard error format returned by OpenAI when a request fails.
public struct ErrorResponse: Codable, Sendable {
    /// The error details.
    public let error: APIError

    /// Creates a new error response.
    public init(error: APIError) {
        self.error = error
    }
}

/// Details about an API error.
///
/// This structure contains the specifics of what went wrong with an API request.
public struct APIError: Codable, Sendable {
    /// A human-readable error message.
    public let message: String

    /// The type of error (e.g., "invalid_request_error", "rate_limit_error").
    public let type: String

    /// The parameter that caused the error, if applicable.
    public let param: String?

    /// An error code for programmatic handling.
    public let code: String?

    /// Creates a new API error.
    public init(message: String, type: String, param: String? = nil, code: String? = nil) {
        self.message = message
        self.type = type
        self.param = param
        self.code = code
    }
}

/// Structured diagnostics for JSON decoding failures.
public struct DecodingDebugInfo: Sendable {
    public enum Reason: String, Sendable {
        case dataCorrupted, keyNotFound, typeMismatch, valueNotFound, other
    }

    /// High-level reason for the failure.
    public let reason: Reason

    /// Coding path where the error occurred.
    public let codingPath: [String]

    /// Additional message supplied by `JSONDecoder`.
    public let debugDescription: String

    /// Optional name of the missing key (for `keyNotFound`).
    public let key: String?

    public var humanDescription: String {
        let path = codingPath.joined(separator: ".")
        let keyPart = key.map { " \"\($0)\"" } ?? ""
        return "\(reason.rawValue)\(keyPart) at [\(path)] – \(debugDescription)"
    }
}
