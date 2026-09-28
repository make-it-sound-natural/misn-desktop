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
        /// An author's parent; a text's parent and grandparent, as Slack
        /// wraps a short reply in a group below the author button.
        let containers: [Reader.Element]
        let isAuthor: Bool
    }

    struct Entry {
        let node: Reader.Element
        let parent: Reader.Element
        let grandparent: Reader.Element?
    }

    struct Walk {
        let field: CGRect
        let deadline: TimeInterval
        var stats = NearbyTextWalk()
        var candidates: [Candidate] = []
        var textLength = 0
        /// Parents and grandparents of kept text. The walk goes last child
        /// first, so a button visited in one of them comes before that text.
        var textContainers: Set<Reader.Element> = []
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
                switch try visit(entry, in: walk) {
                case .skip:
                    continue
                case .descend:
                    stack.append(contentsOf: entries(
                        children(of: entry.node, walk: &walk),
                        of: entry.node,
                        grandparent: entry.parent
                    ))
                case let .keep(text, distance, isAuthor):
                    let containers = isAuthor ? [entry.parent]
                        : [entry.parent] + [entry.grandparent].compactMap { $0 }
                    walk.candidates.append(Candidate(
                        text: text,
                        distance: distance,
                        order: walk.candidates.count,
                        containers: containers,
                        isAuthor: isAuthor
                    ))
                    walk.textLength += text.utf16.count
                    if !isAuthor { walk.textContainers.formUnion(containers) }
                }
            } catch {
                walk.stats.cutoff = .readFailed
                return
            }
        }
    }

    func entries(
        _ nodes: [Reader.Element],
        of parent: Reader.Element,
        grandparent: Reader.Element? = nil
    ) -> [Entry] {
        nodes.map { Entry(node: $0, parent: parent, grandparent: grandparent) }
    }

    func visit(_ entry: Entry, in walk: Walk) throws -> Visit {
        let node = entry.node
        let field = walk.field
        touch(node)
        let role = try optional(reader.string(kAXRoleAttribute, of: node))
        if let role = role, try isSkipped(node, role: role) {
            return .skip
        }
        // Chat apps can show a message's author as a button (Slack opens
        // the profile). Only a button followed by message text in its
        // container can be one; the rest are actions, skipped after one read.
        if role == kAXButtonRole, !walk.textContainers.contains(entry.parent) {
            return .skip
        }
        let frame = try optional(reader.frame(of: node))

        switch role {
        case kAXStaticTextRole?, kAXHeadingRole?, kAXTextAreaRole?,
             kAXButtonRole?:
            // A line of text may report no height; it still has a place.
            // One with no width is text hidden for screen readers.
            guard let frame = frame, frame.width > 1,
                  NearbyTextFilters.overlapsHorizontally(frame, field),
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
            if let frame = frame, !NearbyTextFilters.isDegenerate(frame),
               !NearbyTextFilters.overlapsHorizontally(frame, field)
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
            return try tail(of: node).flatMap(NearbyTextFilters.clean)
        }
        if role == kAXButtonRole {
            // An icon button has only a description; an author has a title.
            return try optional(reader.string(kAXTitleAttribute, of: node))
                .flatMap(NearbyTextFilters.clean)
        }
        // Telegram keeps a message in the title, WhatsApp in the
        // description, both with an empty value.
        let attributes = [
            kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute
        ]
        for attribute in attributes {
            if let raw = try optional(reader.string(attribute, of: node)),
               let text = NearbyTextFilters.clean(raw) {
                return text
            }
        }
        return nil
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

    /// Per container, the one titled button that could name the author: the
    /// first in document order, and before all of the container's text. A
    /// "Show more" between two paragraphs or a second button is an action.
    static func authorOrders(
        _ candidates: [Candidate]
    ) -> [Reader.Element: Int] {
        // Visit order is reverse document order: larger means earlier.
        var firstText: [Reader.Element: Int] = [:]
        for candidate in candidates where !candidate.isAuthor {
            for container in candidate.containers {
                firstText[container] = max(
                    firstText[container] ?? candidate.order,
                    candidate.order
                )
            }
        }
        var authors: [Reader.Element: Int] = [:]
        for candidate in candidates where candidate.isAuthor {
            let parent = candidate.containers[0]
            guard let text = firstText[parent],
                  candidate.order > text else { continue }
            authors[parent] = max(
                authors[parent] ?? candidate.order,
                candidate.order
            )
        }
        return authors
    }

    /// Trims closest first; at equal distance the end of the document
    /// wins, so a thread whose rows share one line keeps its last messages.
    static func assemble(
        _ walk: inout Walk
    ) -> (text: String, walk: NearbyTextWalk) {
        let authors = authorOrders(walk.candidates)
        let closestFirst = walk.candidates.filter {
            !$0.isAuthor || authors[$0.containers[0]] == $0.order
        }.sorted {
            ($0.distance, $0.order) < ($1.distance, $1.order)
        }
        var kept: [(text: String, order: Int)] = []
        var length = 0
        for candidate in closestFirst {
            let separator = kept.isEmpty ? 0 : 1
            let remaining = Limits.textLength - length - separator
            let text = NearbyTextFilters.suffix(candidate.text, remaining)
            guard !text.isEmpty else {
                walk.stats.cutoff = walk.stats.cutoff ?? .textLength
                break
            }
            kept.append((text, candidate.order))
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
}
