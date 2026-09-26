import ApplicationServices
import XCTest
@testable import Make_It_Sound_Natural

/// Nearby text through the capturer in `fieldAndNearby` mode, against fake
/// trees laid out in screen coordinates (origin top left).
final class NearbyTextCollectorTests: XCTestCase {
    private var reader: FakeAXReader!
    private var window: FakeAXNode!
    private var field: FakeAXNode!

    override func setUp() {
        super.setUp()
        reader = FakeAXReader()
        window = FakeAXNode(
            "window",
            role: kAXWindowRole,
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 800)
        )
        reader.app.elements[kAXFocusedWindowAttribute] = window
        field = FakeAXNode.textArea("Hi, looks good", selection: NSRange(
            location: 4,
            length: 5
        ))
        field.frame = CGRect(x: 260, y: 710, width: 800, height: 40)
        reader.app.elements[kAXFocusedUIElementAttribute] = field
    }

    override func tearDown() {
        reader = nil
        window = nil
        field = nil
        super.tearDown()
    }

    // MARK: - Chat layout

    func testChatLayoutKeepsThreadAboveComposerAndDropsNoise() {
        buildChatLayout()

        let context = usableContext()

        XCTAssertEqual(
            context.nearbyText,
            [
                "#design",
                "Anna: can someone review the mockups?",
                "Bob: I will take a look after lunch.",
                "Anna: thanks, the draft is in Figma."
            ].joined(separator: "\n")
        )
        XCTAssertEqual(context.nearbyWalk?.cutoff, nil)
    }

    func testChatLayoutNeverReadsSkippedSubtrees() {
        buildChatLayout()

        _ = usableContext()

        // Skipped by role or subrole: their children are never listed.
        for name in ["toolbar", "react"] {
            XCTAssertFalse(
                reader.readAttributes(of: name).contains(kAXChildrenAttribute),
                name
            )
        }
        XCTAssertTrue(reader.readAttributes(of: "toolbarText").isEmpty)
        XCTAssertTrue(reader.readAttributes(of: "reactText").isEmpty)
        // The content holds the thread, so the climb stops below the split.
        XCTAssertTrue(reader.readAttributes(of: "split").isEmpty)
        // The focused field is never walked.
        XCTAssertFalse(
            reader.readAttributes(of: "field").contains(kAXChildrenAttribute)
        )
    }

    func testFieldModeDoesNotWalk() {
        buildChatLayout()

        let context = usableContext(mode: .field)

        XCTAssertEqual(context.nearbyText, "")
        XCTAssertNil(context.nearbyWalk)
        XCTAssertTrue(reader.childrenRequests.isEmpty)
    }

    func testNonFocusedTextAreaIsReadFromItsEndOnly() {
        let document = String(repeating: "word ", count: 2_000) + "last line"
        let quoted = FakeAXNode(
            "quoted",
            role: kAXTextAreaRole,
            frame: CGRect(x: 260, y: 300, width: 800, height: 300)
        )
        quoted.text = document
        quoted.strings[kAXValueAttribute] = document
        quoted.integers[kAXNumberOfCharactersAttribute] = document.utf16.count
        layout(quoted)

        let context = usableContext()

        XCTAssertFalse(
            reader.readAttributes(of: quoted.name).contains(kAXValueAttribute)
        )
        XCTAssertLessThanOrEqual(
            context.nearbyText.count,
            NearbyTextLimits.textLength
        )
        XCTAssertTrue(context.nearbyText.hasSuffix("word last line"))
        XCTAssertTrue(context.nearbyText.hasPrefix("word "))
    }

    func testHeadingWithoutTitleContributesItsStaticText() {
        let heading = FakeAXNode(
            "heading",
            role: kAXHeadingRole,
            frame: CGRect(x: 260, y: 100, width: 300, height: 30)
        )
        heading.add(staticText("Project update", y: 100))
        layout(heading)

        XCTAssertEqual(usableContext().nearbyText, "Project update")
    }

    // MARK: - Climb

    /// Slack nests its composer under six wrapper groups that hold no text;
    /// the thread is beside the seventh.
    func testClimbPassesEmptyWrappersToReachTheThread() {
        var levels: [[FakeAXNode]] = Array(repeating: [], count: 7)
        let nav = FakeAXNode(
            "nav",
            role: kAXGroupRole,
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 40)
        ).add(staticText("Home DMs Activity", x: 0, y: 0, width: 1_200))
        nav.strings[kAXSubroleAttribute] = "AXLandmarkNavigation"
        let sidebar = FakeAXNode(
            "sidebar",
            role: kAXGroupRole,
            frame: CGRect(x: 0, y: 40, width: 250, height: 760)
        ).add(staticText("general", x: 10, y: 100, width: 200))
        levels[2] = [nav, sidebar]
        levels[6] = [list([
            staticText("Anna: can someone review the mockups?", y: 140),
            staticText("Bob: I will take a look after lunch.", y: 200)
        ])]
        nest(levels)

        let context = usableContext()

        XCTAssertEqual(
            context.nearbyText,
            [
                "Anna: can someone review the mockups?",
                "Bob: I will take a look after lunch."
            ].joined(separator: "\n")
        )
        XCTAssertNil(context.nearbyWalk?.cutoff)
        // Skipped by subrole, and beside the field: pruned without reading
        // their children.
        for name in ["nav", "sidebar"] {
            XCTAssertFalse(
                reader.readAttributes(of: name).contains(kAXChildrenAttribute),
                name
            )
        }
    }

    func testClimbStopsAtTheFirstAncestorWithText() {
        nest([
            [],
            [staticText("close", y: 600)],
            [staticText("far", name: "far", y: 300)]
        ])

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "close")
        XCTAssertNil(context.nearbyWalk?.cutoff)
        XCTAssertTrue(reader.readAttributes(of: "wrapper3").isEmpty)
        XCTAssertTrue(reader.readAttributes(of: "far").isEmpty)
    }

    /// An Electron app with its tree off: the whole climb must stay small
    /// and uncut, or the tree is never turned on.
    func testEmptyTreeClimbsToTheWindowWithoutCutoff() {
        var levels: [[FakeAXNode]] = Array(repeating: [], count: 20)
        levels[0] = [
            FakeAXNode(
                "send",
                role: kAXButtonRole,
                frame: CGRect(x: 1_070, y: 710, width: 100, height: 40)
            ),
            staticText("Press Enter to send", y: 760, height: 20)
        ]
        nest(levels)

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "")
        XCTAssertEqual(context.nearbyWalk, NearbyTextWalk(nodesVisited: 2))
        XCTAssertLessThan(
            context.nearbyWalk?.nodesVisited ?? .max,
            ElectronAccessibilityEnabler<FakeAXReader>.emptyWalkNodeLimit
        )
        XCTAssertTrue(
            reader.readAttributes(of: "wrapper20")
                .contains(kAXChildrenAttribute)
        )
        XCTAssertFalse(
            reader.readAttributes(of: "window").contains(kAXChildrenAttribute)
        )
    }

    func testClimbStopsAtTheWebArea() {
        let browser = FakeAXNode(
            "browser",
            role: kAXGroupRole,
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 800)
        ).add(staticText("Address bar", name: "chrome", y: 0))
        window.add(browser)
        nest([[], []], in: browser)
            .strings[kAXRoleAttribute] = "AXWebArea"

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "")
        XCTAssertNil(context.nearbyWalk?.cutoff)
        XCTAssertTrue(reader.readAttributes(of: "browser").isEmpty)
        XCTAssertTrue(reader.readAttributes(of: "chrome").isEmpty)
    }

    func testNodeBudgetCutsTheClimb() {
        let levels = (0..<10).map { level in
            (0..<60).map { index in
                FakeAXNode(
                    "spacer\(level)-\(index)",
                    role: kAXGroupRole,
                    frame: CGRect(x: 260, y: 100, width: 800, height: 40)
                )
            }
        }
        nest(levels)

        let context = usableContext()

        XCTAssertEqual(context.nearbyWalk?.cutoff, .nodeBudget)
        XCTAssertEqual(
            context.nearbyWalk?.nodesVisited,
            NearbyTextLimits.nodeBudget
        )
        XCTAssertTrue(reader.readAttributes(of: "wrapper10").isEmpty)
    }

    func testDeadlineCutsAClimbThroughEmptyWrappers() {
        nest(Array(repeating: [], count: 30))
        var clock: TimeInterval = 0
        let capturer = AccessibilityContextCapturer(reader: reader) {
            clock += 0.01
            return clock
        }

        let context = usableContext(capturer.capture(request()))

        XCTAssertEqual(context.nearbyWalk?.cutoff, .deadline)
        XCTAssertEqual(context.nearbyWalk?.nodesVisited, 0)
        XCTAssertTrue(reader.readAttributes(of: "wrapper30").isEmpty)
    }

    // MARK: - Frames

    /// Slack's virtualized message list: the list reports a 1×1 px frame
    /// beside the field and every row sits on one line, so geometry can
    /// neither find the rows nor order them.
    func testVirtualListWithDegenerateFramesKeepsDocumentOrder() {
        field.frame = CGRect(x: 601, y: 924, width: 1_102, height: 38)
        let rows = [
            ["Anna", "can someone review the mockups?"],
            ["Bob", "replied to a thread:", "I will take a look after lunch."],
            ["Anna", "thanks, the draft is in Figma."]
        ].map(messageRow)
        let list = FakeAXNode(
            "list",
            role: kAXListRole,
            frame: CGRect(x: 580, y: 892, width: 1, height: 1)
        )
        list.strings[kAXSubroleAttribute] = "AXContentList"
        for row in rows { list.add(row) }
        let scroller = FakeAXNode(
            "scroller",
            role: kAXGroupRole,
            frame: CGRect(x: 580, y: 152, width: 1_144, height: 741)
        ).add(
            FakeAXNode(
                "empty",
                role: kAXGroupRole,
                frame: CGRect(x: 1_152, y: 166, width: 572, height: 727)
            ),
            list,
            FakeAXNode(
                "jump",
                role: kAXGroupRole,
                frame: CGRect(x: 1_712, y: 835, width: 8, height: 50)
            )
        )
        let pane = FakeAXNode(
            "pane",
            role: kAXGroupRole,
            frame: CGRect(x: 580, y: 160, width: 1_144, height: 733)
        ).add(scroller)
        let toolbar = FakeAXNode(
            "toolbar",
            role: kAXToolbarRole,
            frame: CGRect(x: 601, y: 900, width: 300, height: 20)
        ).add(staticText(
            "Bold",
            name: "toolbarText",
            x: 601,
            y: 900,
            width: 40,
            height: 20
        ))
        let composer = FakeAXNode(
            "composer",
            role: kAXGroupRole,
            frame: CGRect(x: 580, y: 900, width: 1_144, height: 70)
        ).add(toolbar, field)
        window.add(FakeAXNode("messages", role: kAXGroupRole).add(
            pane,
            composer
        ))

        let context = usableContext()

        XCTAssertEqual(
            context.nearbyText,
            [
                "Anna",
                "can someone review the mockups?",
                "Bob",
                "replied to a thread:",
                "I will take a look after lunch.",
                "Anna",
                "thanks, the draft is in Figma."
            ].joined(separator: "\n")
        )
        XCTAssertNil(context.nearbyWalk?.cutoff)
        XCTAssertFalse(
            reader.readAttributes(of: "toolbar").contains(kAXChildrenAttribute)
        )
        XCTAssertTrue(reader.readAttributes(of: "toolbarText").isEmpty)
        XCTAssertFalse(
            reader.readAttributes(of: "jump").contains(kAXChildrenAttribute)
        )
    }

    /// Rows that share one line tie on distance; the text cap keeps the
    /// end of the thread.
    func testTextLengthCapKeepsTheEndOfASingleLineThread() {
        let messages = (0..<5).map { index in
            staticText(
                "m\(index) " + String(repeating: "x ", count: 450),
                y: 100,
                height: 1
            )
        }
        let list = FakeAXNode(
            "list",
            role: kAXListRole,
            frame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        for message in messages { list.add(message) }
        layout(list)

        let context = usableContext()

        XCTAssertEqual(context.nearbyWalk?.cutoff, .textLength)
        let kept = context.nearbyText.split(separator: "\n")
        XCTAssertEqual(
            kept.suffix(3).map { $0.prefix(3) },
            ["m2 ", "m3 ", "m4 "]
        )
        XCTAssertFalse(context.nearbyText.contains("m0 "))
    }

    func testContainerWithRealFrameBelowTheFieldIsSkipped() {
        // Its child claims a place above the field; the container's frame
        // decides.
        let below = FakeAXNode(
            "below",
            role: kAXGroupRole,
            frame: CGRect(x: 260, y: 710, width: 800, height: 80)
        ).add(staticText("Suggested reply", name: "belowText", y: 600))
        layout(staticText("Anna: ready?", y: 600), below)

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "Anna: ready?")
        XCTAssertFalse(
            reader.readAttributes(of: "below").contains(kAXChildrenAttribute)
        )
        XCTAssertTrue(reader.readAttributes(of: "belowText").isEmpty)
    }

    func testContainerWithRealFrameBesideTheFieldIsSkipped() {
        let sidebar = FakeAXNode(
            "sidebar",
            role: kAXGroupRole,
            frame: CGRect(x: 0, y: 40, width: 250, height: 760)
        ).add(staticText("general", name: "sidebarText", y: 600))
        layout(sidebar, staticText("Anna: ready?", y: 600))

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "Anna: ready?")
        XCTAssertFalse(
            reader.readAttributes(of: "sidebar").contains(kAXChildrenAttribute)
        )
        XCTAssertTrue(reader.readAttributes(of: "sidebarText").isEmpty)
    }

    // MARK: - Budgets

    func testNodeBudgetKeepsTheLinesClosestToTheField() {
        let lines = (0..<1_000).map { index in
            staticText("l\(index)", y: 100 + CGFloat(index) * 0.5, height: 0.5)
        }
        layout(list(lines))

        let context = usableContext()
        let kept = context.nearbyText.split(separator: "\n")

        XCTAssertEqual(context.nearbyWalk?.cutoff, .nodeBudget)
        XCTAssertEqual(
            context.nearbyWalk?.nodesVisited,
            NearbyTextLimits.nodeBudget
        )
        XCTAssertEqual(kept.last, "l999")
        XCTAssertFalse(kept.contains("l0"))
        // Plus the branch the climb came from.
        XCTAssertTrue(reader.childrenRequests.allSatisfy {
            $0 <= NearbyTextLimits.nodeBudget + 1
        })
    }

    func testDeadlineStopsTheWalk() {
        let lines = (0..<250).map { index in
            staticText("l\(index)", y: 100 + CGFloat(index), height: 1)
        }
        layout(list(lines))
        var clock: TimeInterval = 0
        let capturer = AccessibilityContextCapturer(reader: reader) {
            clock += 0.001
            return clock
        }

        let context = usableContext(capturer.capture(request()))

        XCTAssertEqual(context.nearbyWalk?.cutoff, .deadline)
        XCTAssertLessThan(context.nearbyWalk?.nodesVisited ?? 0, 250)
        XCTAssertGreaterThan(context.timings.nearby, 0)
        XCTAssertTrue(context.nearbyText.hasSuffix("l249"))
    }

    func testTextLengthCapKeepsTheClosestMessages() throws {
        let messages = (0..<5).map { index in
            staticText(
                "m\(index) " + String(repeating: "x ", count: 450),
                y: 100 + CGFloat(index) * 100
            )
        }
        layout(list(messages))

        let context = usableContext()

        XCTAssertEqual(context.nearbyWalk?.cutoff, .textLength)
        XCTAssertLessThanOrEqual(
            context.nearbyText.count,
            NearbyTextLimits.textLength
        )
        XCTAssertTrue(context.nearbyText.contains("m4 "))
        XCTAssertTrue(context.nearbyText.contains("m2 "))
        XCTAssertFalse(context.nearbyText.contains("m0 "))
        // Still top to bottom.
        let m2 = context.nearbyText.range(of: "m2 ")?.lowerBound
        let m4 = context.nearbyText.range(of: "m4 ")?.lowerBound
        XCTAssertLessThan(try XCTUnwrap(m2), try XCTUnwrap(m4))
    }

    func testTimeoutKeepsWhatWasAlreadyCollected() {
        let far = staticText("far", y: 100)
        let hung = staticText("hung", y: 200)
        hung.errors[kAXRoleAttribute] = .timeout
        let close = staticText("close", y: 300)
        layout(list([far, hung, close]))

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "close")
        XCTAssertEqual(context.nearbyWalk?.cutoff, .readFailed)
        XCTAssertTrue(reader.readAttributes(of: far.name).isEmpty)
    }

    func testFieldWithoutFrameSkipsTheWalk() {
        buildChatLayout()
        field.frame = nil

        let context = usableContext()

        XCTAssertEqual(context.nearbyText, "")
        XCTAssertEqual(context.nearbyWalk?.cutoff, .noFieldFrame)
        XCTAssertTrue(reader.childrenRequests.isEmpty)
    }

    func testNearbyTextAloneMakesAWholeFieldSelectionUsable() {
        field = FakeAXNode.textArea("Hi, looks good", selection: NSRange(
            location: 0,
            length: 14
        ))
        field.frame = CGRect(x: 260, y: 710, width: 800, height: 40)
        reader.app.elements[kAXFocusedUIElementAttribute] = field
        layout(staticText("Anna: ready?", y: 600))

        let result = capture().resolve(copiedText: "Hi, looks good")

        guard case .usable(let context) = result else {
            return XCTFail("Expected usable, got \(result)")
        }
        XCTAssertEqual(context.nearbyText, "Anna: ready?")
    }

    /// Chat composers often end with a newline the copy does not include.
    func testNearbyTextSurvivesWhitespaceOnlyFieldText() {
        field = FakeAXNode.textArea("Hi, looks good\n", selection: NSRange(
            location: 0,
            length: 14
        ))
        field.frame = CGRect(x: 260, y: 710, width: 800, height: 40)
        reader.app.elements[kAXFocusedUIElementAttribute] = field
        layout(staticText("Anna: ready?", y: 600))

        let result = capture().resolve(copiedText: "Hi, looks good")

        guard case .usable(let context) = result else {
            return XCTFail("Expected usable, got \(result)")
        }
        XCTAssertEqual(context.nearbyText, "Anna: ready?")
        XCTAssertEqual(context.textBeforeSelection, "")
        XCTAssertEqual(context.textAfterSelection, "")
    }

    func testNearbyTextIsSentWithoutPlaceholderFieldText() {
        let placeholders = String(repeating: "\u{FFFC}", count: 10)
        let value = placeholders + " ok " + placeholders
        field = FakeAXNode.textArea(
            value,
            selection: (value as NSString).range(of: "ok")
        )
        field.frame = CGRect(x: 260, y: 710, width: 800, height: 40)
        reader.app.elements[kAXFocusedUIElementAttribute] = field
        layout(staticText("Anna: ready?", y: 600))

        let result = capture().resolve(copiedText: "ok")

        guard case .usable(let context) = result else {
            return XCTFail("Expected usable, got \(result)")
        }
        XCTAssertEqual(context.nearbyText, "Anna: ready?")
        XCTAssertEqual(context.textBeforeSelection, "")
        XCTAssertEqual(context.textAfterSelection, "")
    }

    // MARK: - Tree builders

    /// A Slack-like window: navigation bar, sidebar, toolbar, channel
    /// heading, message list, composer with a send button and a hint below.
    private func buildChatLayout() {
        let nav = FakeAXNode(
            "nav",
            role: kAXGroupRole,
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 40)
        ).add(staticText("Home DMs Activity", x: 0, y: 0, width: 1_200))
        nav.strings[kAXSubroleAttribute] = "AXLandmarkNavigation"
        let sidebar = FakeAXNode(
            "sidebar",
            role: kAXGroupRole,
            frame: CGRect(x: 0, y: 40, width: 250, height: 760)
        ).add(staticText("general", x: 10, y: 100, width: 200))

        let toolbar = FakeAXNode(
            "toolbar",
            role: kAXToolbarRole,
            frame: CGRect(x: 250, y: 40, width: 950, height: 40)
        ).add(staticText("Huddle", name: "toolbarText", y: 50))
        let heading = FakeAXNode(
            "heading",
            role: kAXHeadingRole,
            frame: CGRect(x: 260, y: 90, width: 300, height: 30)
        )
        heading.strings[kAXTitleAttribute] = "#design"
        let react = FakeAXNode(
            "react",
            role: kAXButtonRole,
            frame: CGRect(x: 1_100, y: 140, width: 40, height: 20)
        ).add(staticText("React", name: "reactText", x: 1_100, y: 140, width: 40))
        let messages = list([
            staticText("Anna: can someone review the mockups?", y: 140),
            react,
            staticText("Bob: I will take a look after lunch.", y: 200),
            staticText("Anna: thanks, the draft is in Figma.", y: 260)
        ])

        let split = FakeAXNode(
            "split",
            role: kAXSplitGroupRole,
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 800)
        )
        window.add(split)
        split.add(nav, sidebar, content([toolbar, heading, messages]))
    }

    /// Nests the field in one wrapper group per entry of `levels`, innermost
    /// first, with that entry's nodes before the level below. Adds the
    /// outermost wrapper to `parent`, the window by default, and returns it.
    @discardableResult
    private func nest(
        _ levels: [[FakeAXNode]],
        in parent: FakeAXNode? = nil
    ) -> FakeAXNode {
        var inner: FakeAXNode = field
        for (index, nodes) in levels.enumerated() {
            let wrapper = FakeAXNode(
                "wrapper\(index + 1)",
                role: kAXGroupRole,
                frame: CGRect(x: 250, y: 40, width: 950, height: 760)
            )
            for node in nodes + [inner] { wrapper.add(node) }
            inner = wrapper
        }
        (parent ?? window).add(inner)
        return inner
    }

    /// `window > content > [nodes…, composer > [field, send, hint]]`.
    private func layout(_ nodes: FakeAXNode...) {
        window.add(content(nodes))
    }

    private func content(_ nodes: [FakeAXNode]) -> FakeAXNode {
        let send = FakeAXNode(
            "send",
            role: kAXButtonRole,
            frame: CGRect(x: 1_070, y: 710, width: 100, height: 40)
        )
        let hint = staticText("Press Enter to send", name: "hint", y: 760, height: 20)
        let composer = FakeAXNode(
            "composer",
            role: kAXGroupRole,
            frame: CGRect(x: 250, y: 700, width: 950, height: 100)
        ).add(field, send, hint)

        let content = FakeAXNode(
            "content",
            role: kAXGroupRole,
            frame: CGRect(x: 250, y: 40, width: 950, height: 760)
        )
        for node in nodes + [composer] { content.add(node) }
        return content
    }

    private func list(_ items: [FakeAXNode]) -> FakeAXNode {
        let list = FakeAXNode(
            "list",
            role: kAXListRole,
            frame: CGRect(x: 250, y: 90, width: 950, height: 600)
        )
        for item in items { list.add(item) }
        return list
    }

    /// One Slack message: `AXGroup > AXGroup/AXDocument > AXGroup` holding
    /// its texts side by side on one 1 px line, right to left, and a
    /// timestamp link.
    private func messageRow(_ texts: [String]) -> FakeAXNode {
        let body = FakeAXNode("body", role: kAXGroupRole)
        for (index, text) in texts.enumerated() {
            body.add(staticText(
                text,
                x: 1_300 - CGFloat(index) * 300,
                y: 152,
                width: 200,
                height: 1
            ))
        }
        body.add(FakeAXNode(
            "timestamp",
            role: "AXLink",
            frame: CGRect(x: 777, y: 152, width: 31, height: 1)
        ))
        let document = FakeAXNode("document", role: kAXGroupRole).add(body)
        document.strings[kAXSubroleAttribute] = "AXDocument"
        return FakeAXNode(
            "row",
            role: kAXGroupRole,
            frame: CGRect(x: 580, y: 152, width: 1_144, height: 9)
        ).add(document)
    }

    private var textCount = 0

    private func staticText(
        _ value: String,
        name: String? = nil,
        x: CGFloat = 260,
        y: CGFloat,
        width: CGFloat = 800,
        height: CGFloat = 40
    ) -> FakeAXNode {
        textCount += 1
        let node = FakeAXNode(
            name ?? "text\(textCount)",
            role: kAXStaticTextRole,
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
        node.strings[kAXValueAttribute] = value
        return node
    }

    // MARK: - Capture helpers

    private func request(
        mode: AccessibilityContextMode = .fieldAndNearby
    ) -> AccessibilityContextRequest {
        AccessibilityContextRequest(
            mode: mode,
            processID: 42,
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            bundleURL: nil
        )
    }

    private func capture(
        mode: AccessibilityContextMode = .fieldAndNearby
    ) -> AccessibilityContextCapture {
        AccessibilityContextCapturer(reader: reader)
            .capture(request(mode: mode))
    }

    private func usableContext(
        mode: AccessibilityContextMode = .fieldAndNearby,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> AccessibilityContext {
        usableContext(capture(mode: mode), file: file, line: line)
    }

    private func usableContext(
        _ capture: AccessibilityContextCapture,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> AccessibilityContext {
        switch capture.resolve(copiedText: "looks") {
        case .usable(let context):
            return context
        case .unusable(let reason, let partial):
            XCTFail("Unusable: \(reason)", file: file, line: line)
            return partial
        }
    }
}
