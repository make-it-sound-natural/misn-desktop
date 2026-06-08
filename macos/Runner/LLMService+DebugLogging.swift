import Foundation

extension LLMService {
    func debugRequestContextLines(config: Configuration) -> [String] {
        var lines: [String] = []
        if let context = config.context, !context.isEmpty {
            lines.append(
                "Text context attached to LLM request: yes, length=\(context.count)"
            )
            lines.append("Text context preview: \(contextPreview(context))")
            if environment["MISN_LOG_FULL_LLM_CONTEXT"] == "1" {
                lines.append("Text context full:\n\(context)")
            } else {
                lines.append(
                    "Text context full: hidden. Set MISN_LOG_FULL_LLM_CONTEXT=1"
                )
            }
        } else {
            lines.append("Text context attached to LLM request: no")
        }

        if let screenshot = config.screenshotAttachment {
            lines.append(
                "Screenshot context attached to LLM request: yes, " +
                "mime=\(screenshot.mimeType), " +
                "base64Length=\(screenshot.base64Data.count), detail=low"
            )
        } else {
            lines.append("Screenshot context attached to LLM request: no")
        }
        return lines
    }

    private func contextPreview(_ context: String) -> String {
        let normalized = context
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        guard normalized.count > 240 else { return normalized }
        return String(normalized.prefix(240)) + "..."
    }
}
