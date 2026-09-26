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
        for name in ["toolbar", "nav", "react"] {
            XCTAssertFalse(
                reader.readAttributes(of: name).contains(kAXChildrenAttribute),
                name
            )
        }
        XCTAssertTrue(reader.readAttributes(of: "toolbarText").isEmpty)
        XCTAssertTrue(reader.readAttributes(of: "reactText").isEmpty)
        // Beside the field: pruned by frame without reading its children.
        XCTAssertFalse(
            reader.readAttributes(of: "sidebar").contains(kAXChildrenAttribute)
        )
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
        XCTAssertTrue(reader.childrenRequests.allSatisfy {
            $0 <= NearbyTextLimits.nodeBudget
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
