import Foundation
import os.log

/// Parses LLM API responses using multiple fallback strategies
struct LLMResponseParser {
    struct ParseResult {
        let content: String
        let strategy: String
    }

    private static let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "LLMResponseParser"
    )

    /// Parses the JSON response from OpenAI API
    /// Tries multiple strategies to handle different response formats
    /// - Parameter json: The JSON dictionary from the API response
    /// - Returns: ParseResult with the content and the strategy that succeeded, or nil
    static func parse(_ json: [String: Any]) -> ParseResult? {
        log("Response keys: \(json.keys.joined(separator: ", "))")

        // Try each parsing strategy in order
        if let result = parseStructuredOutput(json) { return result }
        if let result = parseOutputSummary(json) { return result }
        if let result = parseOutputContentText(json) { return result }
        if let result = parseTextContentText(json) { return result }
        if let result = parseDirectText(json) { return result }
        if let result = parseOutputStringArray(json) { return result }
        if let result = parseLegacyChatCompletions(json) { return result }
        if let result = parseOutputString(json) { return result }

        // Log failure details
        logParsingFailure(json)
        return nil
    }

    // MARK: - Strategy 0: Chat Completions with Structured Output

    private static func parseStructuredOutput(_ json: [String: Any]) -> ParseResult? {
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let textContent = message["content"] as? String else {
            return nil
        }

        guard let jsonData = textContent.data(using: .utf8),
              let variantsJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let balanced = variantsJson["balanced"],
              let casual = variantsJson["casual"],
              let formal = variantsJson["formal"],
              let concise = variantsJson["concise"] else {
            return nil
        }

        let content = """
        ---BALANCED---
        \(balanced)

        ---CASUAL---
        \(casual)

        ---FORMAL---
        \(formal)

        ---CONCISE---
        \(concise)
        """

        log("Parsed via Strategy 0: Chat Completions Structured Output")
        return ParseResult(content: content, strategy: "Strategy 0: Structured Output")
    }

    // MARK: - Strategy 1: Responses API - output array with summary fields

    private static func parseOutputSummary(_ json: [String: Any]) -> ParseResult? {
        guard let outputArray = json["output"] as? [[String: Any]] else {
            return nil
        }

        var extractedSummaries: [String] = []
        for item in outputArray {
            if let summary = item["summary"] as? String {
                extractedSummaries.append(summary)
            }
        }

        guard !extractedSummaries.isEmpty else {
            return nil
        }

        let content = extractedSummaries.joined(separator: "\n\n")
        log("Parsed via Strategy 1: output[].summary concatenation (items: \(extractedSummaries.count))")
        return ParseResult(content: content, strategy: "Strategy 1: Output Summary Array")
    }

    // MARK: - Strategy 2: New Responses API - output[0].content[0].text

    private static func parseOutputContentText(_ json: [String: Any]) -> ParseResult? {
        guard let output = json["output"] as? [[String: Any]],
              let firstItem = output.first,
              let contentList = firstItem["content"] as? [[String: Any]],
              let firstContent = contentList.first,
              let text = firstContent["text"] as? String else {
            return nil
        }

        log("Parsed via Strategy 2: output[0].content[0].text")
        return ParseResult(content: text, strategy: "Strategy 2: Output Content Text")
    }

    // MARK: - Strategy 3: Text field as Dictionary - text.content[0].text

    private static func parseTextContentText(_ json: [String: Any]) -> ParseResult? {
        guard let textDict = json["text"] as? [String: Any],
              let contentList = textDict["content"] as? [[String: Any]],
              let firstContent = contentList.first,
              let text = firstContent["text"] as? String else {
            return nil
        }

        log("Parsed via Strategy 3: text.content[0].text")
        return ParseResult(content: text, strategy: "Strategy 3: Text Content")
    }

    // MARK: - Strategy 4: Direct text field as String

    private static func parseDirectText(_ json: [String: Any]) -> ParseResult? {
        guard let text = json["text"] as? String else {
            return nil
        }

        log("Parsed via Strategy 4: direct text string")
        return ParseResult(content: text, strategy: "Strategy 4: Direct Text")
    }

    // MARK: - Strategy 5: Output as array of strings

    private static func parseOutputStringArray(_ json: [String: Any]) -> ParseResult? {
        guard let output = json["output"] as? [String],
              let firstOutput = output.first else {
            return nil
        }

        log("Parsed via Strategy 5: output array of strings")
        return ParseResult(content: firstOutput, strategy: "Strategy 5: Output String Array")
    }

    // MARK: - Strategy 6: Legacy Chat Completions structure

    private static func parseLegacyChatCompletions(_ json: [String: Any]) -> ParseResult? {
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return nil
        }

        log("Parsed via Strategy 6: legacy choices structure")
        return ParseResult(content: text, strategy: "Strategy 6: Legacy Chat")
    }

    // MARK: - Strategy 7: Top level output string

    private static func parseOutputString(_ json: [String: Any]) -> ParseResult? {
        guard let outputStr = json["output"] as? String else {
            return nil
        }

        log("Parsed via Strategy 7: output as string")
        return ParseResult(content: outputStr, strategy: "Strategy 7: Output String")
    }

    // MARK: - Logging

    private static func logParsingFailure(_ json: [String: Any]) {
        log("❌ All parsing strategies failed! Dumping structure:")

        if let outputVal = json["output"] {
            log("Debug: 'output' field type: \(type(of: outputVal))")
            if let outputArr = outputVal as? [[String: Any]] {
                log("Debug: 'output' is array with \(outputArr.count) elements")
                for (index, item) in outputArr.enumerated() {
                    log("Debug: output[\(index)] keys: \(item.keys.joined(separator: ", "))")
                    if let type = item["type"] as? String {
                        log("Debug: output[\(index)].type: \(type)")
                    }
                    if let summary = item["summary"] as? String {
                        log("Debug: output[\(index)].summary: \(summary.prefix(100))...")
                    } else {
                        log("Debug: output[\(index)].summary: NIL")
                    }

                    if let contentList = item["content"] as? [[String: Any]] {
                        log("Debug: output[\(index)].content has \(contentList.count) elements")
                        if let firstContent = contentList.first {
                            let keys = firstContent.keys.joined(separator: ", ")
                            log("Debug: output[\(index)].content[0] keys: \(keys)")
                        }
                    }
                }
            } else {
                log("Debug: 'output' is not [[String: Any]]")
            }
        } else {
            log("Debug: 'output' field is missing")
        }

        if let textVal = json["text"] {
            log("Debug: 'text' field type: \(type(of: textVal))")
            if let textDict = textVal as? [String: Any] {
                log("Debug: 'text' keys: \(textDict.keys.joined(separator: ", "))")
            }
        }
    }

    private static func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}
