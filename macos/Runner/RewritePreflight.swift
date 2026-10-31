import Foundation

/// Required selections checked before starting a rewrite request.
enum RewritePreflight {
    static let missingModelMessage = "Choose a model in Settings."
    static let missingTargetProfileMessage =
        "Choose a target language before rewriting."

    static func blockingMessage(
        model: String,
        requiresTargetProfileSelection: Bool
    ) -> String? {
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return missingModelMessage
        }
        if requiresTargetProfileSelection {
            return missingTargetProfileMessage
        }
        return nil
    }
}
