import Foundation

/// The four rewrite variants the model returns as one JSON object.
struct CorrectionVariantsJSON: Decodable {
    let balanced: String
    let casual: String
    let formal: String
    let concise: String

    /// The marker text `LLMService.extractVariant` reads.
    var markerContent: String {
        """
        ---BALANCED---
        \(balanced)

        ---CASUAL---
        \(casual)

        ---FORMAL---
        \(formal)

        ---CONCISE---
        \(concise)
        """
    }

    /// JSON Schema for the object above. Computed because a stored
    /// `[String: Any]` static is not `Sendable`.
    static var jsonSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "balanced": ["type": "string"],
                "casual": ["type": "string"],
                "formal": ["type": "string"],
                "concise": ["type": "string"]
            ],
            "required": ["balanced", "casual", "formal", "concise"],
            "additionalProperties": false
        ]
    }
}
