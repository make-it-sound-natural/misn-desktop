import ApplicationServices
import Foundation

/// Collects text shown above the focused field, such as the thread above a
/// chat composer. Climbs the field's ancestors one at a time, walking each
/// one's subtree within a shared node budget and deadline, and keeps static
/// text, headings and other text areas that sit above the field and overlap
/// it horizontally. The climb stops once it has `climbTextLength` characters:
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
    /// more is found than fits, the text closest to the field wins. The walk
    /// stops at `Limits.deadline` from now or at `deadline`, whichever comes
    /// first, and keeps what it found so far.
    func collect(
        around field: Reader.Element,
        frame: Result<CGRect, AXReadError>,
        until deadline: TimeInterval
    ) -> (text: String, walk: NearbyTextWalk) {
        let fieldFrame: CGRect
        switch frame {
        case .success(let frame) where !frame.isEmpty:
            fieldFrame = frame
        case .success, .failure(.unavailable):
            return ("", NearbyTextWalk(cutoff: .noFieldFrame))
        case .failure(.timeout), .failure(.apiDisabled):
            return ("", NearbyTextWalk(cutoff: .readFailed))
        }
        var walk = Walk(
            field: fieldFrame,
            deadline: min(now() + Limits.deadline, deadline)
        )
        var walked = field
        while walk.stats.cutoff == nil,
              walk.textLength < Limits.climbTextLength,
              walk.stats.nodesVisited < Limits.nodeBudget {
            // A level that adds no nodes never reaches the check in the
            // subtree walk.
            if now() >= walk.deadline {
                walk.stats.cutoff = .deadline
                break
            }
            let ancestor: Reader.Element
            let role: String?
            do {
                guard let parent = try optional(
                    reader.element(kAXParentAttribute, of: walked)
                ) else {
                    break
                }
                ancestor = parent
                touch(ancestor)
                role = try optional(
                    reader.string(kAXRoleAttribute, of: ancestor)
                )
            } catch {
                walk.stats.cutoff = .readFailed
                break
            }
            if role == kAXApplicationRole { break }
            walkDescendants(of: ancestor, skipping: walked, into: &walk)
            // Telegram puts the message list right under the window, so the
            // window is walked too. Above the page are only the browser's
            // tabs and toolbars.
            if role == kAXWindowRole || role == Self.webAreaRole { break }
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
        let parent: Reader.Element
        let isAuthor: Bool
    }

    /// A node to visit and where it sits among its siblings.
    struct Entry {
        let node: Reader.Element
        let parent: Reader.Element
        let isFirstChild: Bool
    }

    struct Walk {
        let field: CGRect
        let deadline: TimeInterval
        var stats = NearbyTextWalk()
        var candidates: [Candidate] = []
        var textLength = 0
    }

    enum Visit {
        case descend
        case skip
        case keep(String, distance: CGFloat, isAuthor: Bool)
    }

    static var webAreaRole: String { "AXWebArea" }

    /// Depth first, last child first: the end of a thread is what sits
    /// closest to the composer, so it gets the budget first.
    func walkDescendants(
        of ancestor: Reader.Element,
        skipping walked: Reader.Element,
        into walk: inout Walk
    ) {
        // One more than the budget: the walked branch may be among them.
        var stack = entries(
            children(of: ancestor, walk: &walk, extra: 1),
            of: ancestor
        ).filter { $0.node != walked }
        while walk.stats.cutoff == nil, let entry = stack.popLast() {
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
                switch try visit(entry, field: walk.field) {
                case .skip:
                    continue
                case .descend:
                    stack.append(contentsOf: entries(
                        children(of: entry.node, walk: &walk),
                        of: entry.node
                    ))
                case let .keep(text, distance, isAuthor):
                    walk.candidates.append(Candidate(
                        text: text,
                        distance: distance,
                        order: walk.candidates.count,
                        parent: entry.parent,
                        isAuthor: isAuthor
                    ))
                    walk.textLength += text.utf16.count
                }
            } catch {
                walk.stats.cutoff = .readFailed
                return
            }
        }
    }

    func entries(
        _ nodes: [Reader.Element],
        of parent: Reader.Element
    ) -> [Entry] {
        nodes.enumerated().map { index, node in
            Entry(node: node, parent: parent, isFirstChild: index == 0)
        }
    }

    func visit(_ entry: Entry, field: CGRect) throws -> Visit {
        let node = entry.node
        touch(node)
        let role = try optional(reader.string(kAXRoleAttribute, of: node))
        if let role = role, try isSkipped(node, role: role) {
            return .skip
        }
        // Slack shows a message's author as a button, the first thing in the
        // group that holds the message. Other buttons are actions.
        if role == kAXButtonRole, !entry.isFirstChild { return .skip }
        let frame = try optional(reader.frame(of: node))

        switch role {
        case kAXStaticTextRole?, kAXHeadingRole?, kAXTextAreaRole?,
             kAXButtonRole?:
            // A line of text may report no height; it still has a place.
            // One with no width is text hidden for screen readers.
            guard let frame = frame, frame.width > 1,
                  Self.overlapsHorizontally(frame, field),
                  frame.maxY <= field.minY else {
                // Beside or below the field, or nowhere to place it.
                return .skip
            }
            if let text = try text(of: node, role: role) {
                return .keep(
                    text,
                    distance: field.minY - frame.maxY,
                    isAuthor: role == kAXButtonRole
                )
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
        if role == kAXTextAreaRole {
            return try tail(of: node).flatMap(Self.clean)
        }
        if role == kAXButtonRole {
            // An icon button has only a description; an author has a title.
            return try optional(reader.string(kAXTitleAttribute, of: node))
                .flatMap(Self.clean)
        }
        // Telegram keeps a message in the title, WhatsApp in the
        // description, both with an empty value.
        let attributes = [
            kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute
        ]
        for attribute in attributes {
            if let raw = try optional(reader.string(attribute, of: node)),
               let text = Self.clean(raw) {
                return text
            }
        }
        return nil
    }

    static func clean(_ raw: String) -> String? {
        let text = raw
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A single Character over the cap leaves nothing.
        let capped = suffix(text, Limits.textLength)
        return capped.isEmpty ? nil : capped
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
        // A first button counts as an author only next to message text; a
        // lone "Download all" is not one.
        let textParents = Set(
            walk.candidates.filter { !$0.isAuthor }.map(\.parent)
        )
        let closestFirst = walk.candidates.filter {
            !$0.isAuthor || textParents.contains($0.parent)
        }.sorted {
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
                order: candidate.order,
                parent: candidate.parent,
                isAuthor: candidate.isAuthor
            ))
            length += separator + text.utf16.count
            if text != candidate.text {
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

    /// The last `limit` UTF-16 units, starting at a whole word when cut.
    static func suffix(_ text: String, _ limit: Int) -> String {
        guard text.utf16.count > limit else { return text }
        guard limit > 0 else { return "" }
        return text.suffix(utf16Limit: limit).droppingFirstPartialWord()
    }
}
