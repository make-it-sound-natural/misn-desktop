import ApplicationServices
import Foundation

enum NearbyTextLimits {
    /// Shared by every ancestor the walk climbs. Slack's message pane alone
    /// is about 290 nodes, and the empty levels below it cost a few dozen.
    static let nodeBudget = 500
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
    /// What stopped the walk before it found text or reached the window.
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
/// chat composer. Climbs the field's ancestors one at a time, walking each
/// one's subtree within a shared node budget and deadline, and keeps static
/// text, headings and other text areas that sit above the field and overlap
/// it horizontally. The climb stops at the first ancestor that adds text:
/// web apps nest a composer under many empty wrapper groups, so no fixed
/// depth reaches the thread everywhere.
///
/// Geometry only prunes and ranks: virtualized lists, like Slack's, report
/// a 1 px frame for the list and the same line for every row, so the text
/// is assembled in document order.
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

    /// Returns the kept text in document order, one element per line. When
    /// more is found than fits, the text closest to the field wins.
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
        while walk.stats.cutoff == nil, walk.candidates.isEmpty,
              walk.stats.nodesVisited < Limits.nodeBudget {
            // A level that adds no nodes never reaches the check in the
            // subtree walk.
            if now() >= walk.deadline {
                walk.stats.cutoff = .deadline
                break
            }
            guard case .success(let ancestor) = reader.element(
                kAXParentAttribute,
                of: walked
            ) else {
                break
            }
            let role = self.role(of: ancestor)
            if role == kAXWindowRole || role == kAXApplicationRole { break }
            walkDescendants(of: ancestor, skipping: walked, into: &walk)
            // Above the page are only the browser's tabs and toolbars.
            if role == Self.webAreaRole { break }
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
        /// Vertical gap to the field.
        let distance: CGFloat
        /// Visit order. The walk goes last child first, so this is reverse
        /// document order.
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
        case keep(String, distance: CGFloat)
    }

    static var webAreaRole: String { "AXWebArea" }

    /// An ancestor whose role cannot be read is walked like any other.
    func role(of element: Reader.Element) -> String? {
        touch(element)
        return try? reader.string(kAXRoleAttribute, of: element).get()
    }

    /// Depth first, last child first: the end of a thread is what sits
    /// closest to the composer, so it gets the budget first.
    func walkDescendants(
        of ancestor: Reader.Element,
        skipping walked: Reader.Element,
        into walk: inout Walk
    ) {
        // One more than the budget: the walked branch may be among them.
        var stack = children(of: ancestor, walk: &walk, extra: 1)
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
                case let .keep(text, distance):
                    walk.candidates.append(Candidate(
                        text: text,
                        distance: distance,
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

        switch role {
        case kAXStaticTextRole?, kAXHeadingRole?, kAXTextAreaRole?:
            // A line of text may report no height; it still has a place.
            guard let frame = frame,
                  Self.overlapsHorizontally(frame, field),
                  frame.maxY <= field.minY else {
                // Beside or below the field, or nowhere to place it.
                return .skip
            }
            if let text = try text(of: node, role: role) {
                return .keep(text, distance: field.minY - frame.maxY)
            }
            // A web heading keeps its text in static text children.
            return role == kAXHeadingRole ? .descend : .skip
        default:
            // A container beside the field, or one that starts at or below
            // it, holds nothing above it. A degenerate frame says nothing
            // about where its children are.
            if let frame = frame, !Self.isDegenerate(frame),
               !Self.overlapsHorizontally(frame, field)
                || frame.minY >= field.minY {
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
        walk: inout Walk,
        extra: Int = 0
    ) -> [Reader.Element] {
        let remaining = Limits.nodeBudget - walk.stats.nodesVisited
        guard remaining > 0 else { return [] }
        switch reader.lastChildren(remaining + extra, of: node) {
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

    /// Slack's virtualized message list is 1 px square while its rows span
    /// the whole pane.
    static func isDegenerate(_ frame: CGRect) -> Bool {
        frame.width <= 1 || frame.height <= 1
    }

    /// Trims closest first; at equal distance the end of the document
    /// wins, so a thread whose rows share one line keeps its last messages.
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
                distance: candidate.distance,
                order: candidate.order
            ))
            length += separator + text.count
            if text.count < candidate.text.count {
                walk.stats.cutoff = walk.stats.cutoff ?? .textLength
                break
            }
        }

        let documentOrder = kept.sorted { $0.order > $1.order }
        return (
            documentOrder.map(\.text).joined(separator: "\n"),
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
