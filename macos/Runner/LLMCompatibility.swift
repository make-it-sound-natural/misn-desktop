import Foundation

/// Recognizes explicit parameter rejections, independently of UI error text.
enum LLMCompatibility {
    enum Parameter: String, CaseIterable {
        case reasoningEffort = "reasoning_effort"
        case responseFormat = "response_format"
    }

    static func rejectedParameters(
        data: Data?,
        statusCode: Int
    ) -> Set<Parameter> {
        guard statusCode == 400 || statusCode == 422,
              let data = data,
              let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        else { return [] }

        let error = envelope.error
        let message = error.message.lowercased()
        let rejectionCodes = [
            "unsupported_parameter", "unsupported_value", "invalid_value",
            "unknown_parameter", "unrecognized_request_argument"
        ]
        let rejectionPhrases = [
            "unsupported", "not supported", "not support", "unavailable",
            "unrecognized", "unknown parameter", "invalid value",
            "invalid parameter", "not permitted", "not allowed",
            "must be one of", "extra inputs are not permitted"
        ]
        let isRejection = rejectionPhrases.contains { message.contains($0) }
        return Set(Parameter.allCases.filter { parameter in
            if let field = error.param {
                guard field == parameter.rawValue else { return false }
                return rejectionCodes.contains(error.code ?? "") || isRejection
            }
            return explicitlyRejects(parameter, in: message)
        })
    }

    private static func explicitlyRejects(
        _ parameter: Parameter,
        in message: String
    ) -> Bool {
        // Tie the rejection to the field, not another error elsewhere in the
        // message (for example an invalid model mentioning request settings).
        let field = "[\"'`]?\\b" + parameter.rawValue + "\\b[\"'`]?"
        let before = "(?:unsupported|invalid)(?: value| parameter)?" +
            "|unknown parameter|unrecognized (?:parameter|request argument)|" +
            "does not support|doesn't support"
        let after = "unsupported|not supported|unavailable|not allowed|" +
            "not permitted|must be one of|does not support"
        let patterns = [
            "(?:" + before + ")(?: for| supplied)?[ :]*" + field,
            field + "(?: parameter| value)?[ :]*(?:is |are )?(?:" + after + ")"
        ]
        return patterns.contains {
            message.range(of: $0, options: .regularExpression) != nil
        }
    }

    private struct ErrorEnvelope: Decodable {
        let error: APIError
    }

    private struct APIError: Decodable {
        let message: String
        let param: String?
        let code: String?

        enum CodingKeys: String, CodingKey { case message, param, code }

        init(from decoder: Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                message = text
                param = nil
                code = nil
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
            param = try container.decodeIfPresent(String.self, forKey: .param)
            // Gateways also use numeric HTTP codes in this field.
            code = try? container.decode(String.self, forKey: .code)
        }
    }
}
