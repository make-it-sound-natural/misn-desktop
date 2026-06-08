import Foundation

/// Parses LLM HTTP error bodies into short user-visible strings.
enum LLMErrorMessageParser {
    struct ErrorInfo {
        let message: String
        let isAuthenticationFailure: Bool
    }

    /// Maximum length for user-visible API error text (bubble and SnackBar).
    static let maxUserErrorLength = 200

    static func errorInfo(from data: Data?, statusCode: Int) -> ErrorInfo {
        let message = userMessage(from: data, statusCode: statusCode)
        return ErrorInfo(
            message: message,
            isAuthenticationFailure: isAuthenticationStatus(statusCode)
                || hasInvalidApiKeyCode(data)
        )
    }

    /// Produces a short user-visible string from an API error body (or nil).
    static func userMessage(from data: Data?, statusCode: Int) -> String {
        guard let data = data, !data.isEmpty else {
            return "HTTP Error: \(statusCode)"
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "HTTP Error: \(statusCode)"
        }

        if let errorText = json["error"] as? String {
            let trimmed = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return truncateForUser(trimmed, maxLength: maxUserErrorLength)
            }
        }

        guard let error = json["error"] as? [String: Any] else {
            return "HTTP Error: \(statusCode)"
        }

        if let msg = error["message"] as? String {
            let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return truncateForUser(trimmed, maxLength: maxUserErrorLength)
            }
        }

        if let codeStr = error["code"] as? String,
           let mapped = mapOpenAIStyleErrorCode(codeStr) {
            return mapped
        }

        if let codeNum = error["code"] as? Int,
           let mapped = mapNumericErrorCode(codeNum) {
            return mapped
        }

        return "HTTP Error: \(statusCode)"
    }

    static func truncateForUser(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let end = text.index(text.startIndex, offsetBy: maxLength - 1)
        return String(text[..<end]) + "…"
    }

    static func mapOpenAIStyleErrorCode(_ code: String) -> String? {
        switch code {
        case "insufficient_quota":
            return "Quota exceeded. Check billing."
        case "rate_limit_exceeded":
            return "Rate limited. Try again shortly."
        case "invalid_api_key":
            return "Invalid API key. Check settings."
        default:
            return nil
        }
    }

    static func mapNumericErrorCode(_ code: Int) -> String? {
        switch code {
        case 401:
            return "Invalid API key. Check settings."
        case 402:
            return "Insufficient credits or quota. Check your provider account."
        case 429:
            return "Rate limited. Try again shortly."
        default:
            return nil
        }
    }

    private static func isAuthenticationStatus(_ statusCode: Int) -> Bool {
        statusCode == 401 || statusCode == 403
    }

    private static func hasInvalidApiKeyCode(_ data: Data?) -> Bool {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            return false
        }

        if let code = json["code"] as? String {
            return code == "invalid_api_key"
        }

        guard let error = json["error"] as? [String: Any],
              let code = error["code"] as? String else {
            return false
        }

        return code == "invalid_api_key"
    }
}
