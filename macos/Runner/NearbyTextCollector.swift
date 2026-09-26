import ApplicationServices
import Foundation

enum NearbyTextLimits {
    /// How many ancestors of the field the walk starts from.
    static let ancestors = 4
    static let nodeBudget = 300
    static let deadline: TimeInterval = 0.15
    static let textLength = 3_000
}

/// Which elements the nearby text walk skips.
private enum NearbyTextRoles {
    /// Chrome and navigation around the content, never message text. Applies
    /// below the ancestors only: a field inside a tab group still gets the
    /// rest of that tab's content.
    static let skippedRoles: Set<String> = [
        kAXToolbarRole,
        kAXMenuBarRole,
        kAXMenuRole,
        kAXTabGroupRole,
        kAXOutlineRole,
        kAXButtonRole,
        kAXScrollBarRole
    ]

    /// Sidebar lists: AppKit source lists and web navigation landmarks.
    static let skippedSubroles: Set<String> = [
        "AXSourceList",
        "AXLandmarkNavigation"
    ]

    /// Containers whose subrole can mark a sidebar; only these pay for the
    /// extra subrole read.
    static let subroleCheckedRoles: Set<String> = [
        kAXGroupRole,
        kAXListRole
    ]
}

/// How a nearby text walk went, for the debug saver and logs.
struct NearbyTextWalk: Equatable {
    /// What stopped the walk before it covered every ancestor.
    enum Cutoff: String, Equatable {
        case nodeBudget
        case deadline
        /// The target app stopped answering or the API was disabled.
        case readFailed
        /// More text was found than fits; the farthest was dropped.
        case textLength
        /// The field reports no frame, so nothing can be placed above it.
        case noFieldFrame
    }

    var nodesVisited = 0
    var cutoff: Cutoff?
}

/// Collects text shown above the focused field, such as the thread above a
/// chat composer. Walks the subtrees of the field's nearest ancestors within
/// a node budget and a deadline, and keeps static text, headings and other
/// text areas that sit above the field and overlap it horizontally.
final class NearbyTextCollector<Reader: AXElementReading> {
    private typealias Limits = NearbyTextLimits

    private let reader: Reader
    private let messagingTimeout: Float
    private let now: () -> TimeInterval

    init(
        reader: Reader,
        messagingTimeout: Float,
        now: @escaping () -> TimeInterval
    ) {
        self.reader = reader
        self.messagingTimeout = messagingTimeout
        self.now = now
    }

    /// Returns the kept text top to bottom, one element per line. When more
    /// is found than fits, the text closest to the field wins.
    func collect(
        around field: Reader.Element
    ) -> (text: String, walk: NearbyTextWalk) {
        guard case .success(let fieldFrame) = reader.frame(of: field),
              !fieldFrame.isEmpty else {
            return ("", NearbyTextWalk(cutoff: .noFieldFrame))
        }
        var walk = Walk(
            field: fieldFrame,
            deadline: now() + Limits.deadline
        )
        var walked = field
        for _ in 0..<Limits.ancestors {
            guard case .success(let ancestor) = reader.element(
                kAXParentAttribute,
                of: walked
            ), !isWindowOrApplication(ancestor) else {
                break
            }
            walkDescendants(of: ancestor, skipping: walked, into: &walk)
            guard walk.stats.cutoff == nil else { break }
            walked = ancestor
        }
        // Children are fetched only up to the budget, so a walk that spent
        // it exactly may still have skipped some.
        if walk.stats.cutoff == nil,
           walk.stats.nodesVisited >= Limits.nodeBudget {
            walk.stats.cutoff = .nodeBudget
        }
        return Self.assemble(&walk)
    }
}

private extension NearbyTextCollector {
    struct Candidate {
        let text: String
        let frame: CGRect
        /// Vertical gap to the field.
        let distance: CGFloat
        let order: Int
    }

    struct Walk {
        let field: CGRect
        let deadline: TimeInterval
        var stats = NearbyTextWalk()
        var candidates: [Candidate] = []
    }

    enum Visit {
        case descend
        case skip
        case keep(String, CGRect)
    }

    func isWindowOrApplication(_ element: Reader.Element) -> Bool {
        touch(element)
        guard case .success(let role) = reader.string(
            kAXRoleAttribute,
            of: element
        ) else {
            return false
        }
        return role == kAXWindowRole || role == kAXApplicationRole
    }

    /// Depth first, last child first: the end of a thread is what sits
    /// closest to the composer, so it gets the budget first.
    func walkDescendants(
        of ancestor: Reader.Element,
        skipping walked: Reader.Element,
        into walk: inout Walk
    ) {
        var stack = children(of: ancestor, walk: &walk)
            .filter { $0 != walked }
        while walk.stats.cutoff == nil, let node = stack.popLast() {
            if now() >= walk.deadline {
                walk.stats.cutoff = .deadline
                return
            }
            if walk.stats.nodesVisited >= Limits.nodeBudget {
                walk.stats.cutoff = .nodeBudget
                return
            }
            walk.stats.nodesVisited += 1

            do {
                switch try visit(node, field: walk.field) {
                case .skip:
                    continue
                case .descend:
                    stack.append(contentsOf: children(of: node, walk: &walk))
                case let .keep(text, frame):
                    walk.candidates.append(Candidate(
                        text: text,
                        frame: frame,
                        distance: walk.field.minY - frame.maxY,
                        order: walk.candidates.count
                    ))
                }
            } catch {
                walk.stats.cutoff = .readFailed
                return
            }
        }
    }

    func visit(_ node: Reader.Element, field: CGRect) throws -> Visit {
        touch(node)
        let role = try optional(reader.string(kAXRoleAttribute, of: node))
        if let role = role, try isSkipped(node, role: role) {
            return .skip
        }
        let frame = try optional(reader.frame(of: node))
            .flatMap { $0.isEmpty ? nil : $0 }
        if let frame = frame, !Self.overlapsHorizontally(frame, field) {
            return .skip
        }

        switch role {
        case kAXStaticTextRole?, kAXHeadingRole?, kAXTextAreaRole?:
            guard let frame = frame, frame.maxY <= field.minY else {
                // Below the field, or nowhere to place it.
                return .skip
            }
            if let text = try text(of: node, role: role) {
                return .keep(text, frame)
            }
            // A web heading keeps its text in static text children.
            return role == kAXHeadingRole ? .descend : .skip
        default:
            // A container that starts at or below the field holds nothing
            // above it.
            if let frame = frame, frame.minY >= field.minY {
                return .skip
            }
            return .descend
        }
    }

    func isSkipped(_ node: Reader.Element, role: String) throws -> Bool {
        if NearbyTextRoles.skippedRoles.contains(role) { return true }
        guard NearbyTextRoles.subroleCheckedRoles.contains(role),
              let subrole = try optional(
                reader.string(kAXSubroleAttribute, of: node)
              ) else {
            return false
        }
        return NearbyTextRoles.skippedSubroles.contains(subrole)
    }

    func text(of node: Reader.Element, role: String?) throws -> String? {
        let raw: String?
        if role == kAXTextAreaRole {
            raw = try tail(of: node)
        } else {
            raw = try optional(reader.string(kAXValueAttribute, of: node))
                ?? optional(reader.string(kAXTitleAttribute, of: node))
        }
        guard let raw = raw else { return nil }
        let text = raw
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return Self.suffix(text, Limits.textLength)
    }

    /// Another text area can hold a whole document, so read only its end,
    /// the part nearest the field. Offsets are UTF-16, like the field read.
    func tail(of node: Reader.Element) throws -> String? {
        guard let count = try optional(
            reader.integer(kAXNumberOfCharactersAttribute, of: node)
        ), count > 0 else {
            return nil
        }
        let length = min(count, Limits.textLength)
        return try optional(reader.string(
            for: CFRange(location: count - length, length: length),
            of: node
        ))
    }

    /// A child list that cannot be read counts as empty; the walk goes on
    /// with the other nodes.
    func children(
        of node: Reader.Element,
        walk: inout Walk
    ) -> [Reader.Element] {
        let remaining = Limits.nodeBudget - walk.stats.nodesVisited
        guard remaining > 0 else { return [] }
        switch reader.lastChildren(remaining, of: node) {
        case .success(let children):
            return children
        case .failure(.unavailable):
            return []
        case .failure(.timeout), .failure(.apiDisabled):
            walk.stats.cutoff = .readFailed
            return []
        }
    }

    func touch(_ element: Reader.Element) {
        reader.setMessagingTimeout(messagingTimeout, for: element)
    }

    /// A missing attribute reads as nil; a hung app or a disabled API ends
    /// the walk.
    func optional<Value>(
        _ result: Result<Value, AXReadError>
    ) throws -> Value? {
        switch result {
        case .success(let value):
            return value
        case .failure(.unavailable):
            return nil
        case .failure(let error):
            throw error
        }
    }

    static func overlapsHorizontally(_ frame: CGRect, _ field: CGRect) -> Bool {
        frame.minX < field.maxX && frame.maxX > field.minX
    }

    static func assemble(
        _ walk: inout Walk
    ) -> (text: String, walk: NearbyTextWalk) {
        let closestFirst = walk.candidates.sorted {
            ($0.distance, $0.order) < ($1.distance, $1.order)
        }
        var kept: [Candidate] = []
        var length = 0
        for candidate in closestFirst {
            let separator = kept.isEmpty ? 0 : 1
            let remaining = Limits.textLength - length - separator
            let text = Self.suffix(candidate.text, remaining)
            guard !text.isEmpty else {
                walk.stats.cutoff = walk.stats.cutoff ?? .textLength
                break
            }
            kept.append(Candidate(
                text: text,
                frame: candidate.frame,
                distance: candidate.distance,
                order: candidate.order
            ))
            length += separator + text.count
            if text.count < candidate.text.count {
                walk.stats.cutoff = walk.stats.cutoff ?? .textLength
                break
            }
        }

        let topToBottom = kept.sorted {
            ($0.frame.minY, $0.frame.minX, $0.order)
                < ($1.frame.minY, $1.frame.minX, $1.order)
        }
        return (
            topToBottom.map(\.text).joined(separator: "\n"),
            walk.stats
        )
    }

    /// The last `limit` characters, starting at a whole word when cut.
    static func suffix(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        guard limit > 0 else { return "" }
        let cut = text.suffix(limit)
        guard let space = cut.firstIndex(where: { $0.isWhitespace }) else {
            return String(cut)
        }
        return String(cut[cut.index(after: space)...])
    }
}
