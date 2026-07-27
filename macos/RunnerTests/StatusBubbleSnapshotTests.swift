import Cocoa
import XCTest

@testable import Make_It_Sound_Natural

/// Renders the status bubble in each state to PNG files for design review.
///
/// The bubble is an `NSPanel` that auto-dismisses after 1.5 s, which makes it
/// impractical to photograph from a running app. Rendering the view offscreen
/// gives the same AppKit output without taking over the screen.
final class StatusBubbleSnapshotTests: XCTestCase {

    /// Set `MISN_WRITE_BUBBLE_SNAPSHOTS=1` to also dump PNGs for design
    /// review. Off by default so `make test` stays free of side effects.
    private static var shouldWriteFiles: Bool {
        ProcessInfo.processInfo.environment["MISN_WRITE_BUBBLE_SNAPSHOTS"] == "1"
    }

    /// Per-user private directory (`$TMPDIR`), not the world-writable `/tmp`,
    /// where another local process could pre-create a symlink and redirect
    /// the write onto a file of its choosing.
    private static var outputDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("misn-bubble-snapshots", isDirectory: true)
    }

    func testRendersEveryState() throws {
        let bubble = StatusBubble.shared
        bubble.setupUI()

        let writeFiles = Self.shouldWriteFiles
        let directory = Self.outputDirectory
        if writeFiles {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        var renderedByName: [String: NSBitmapImageRep] = [:]

        let states: [(String, StatusBubble.State)] = [
            ("processing", .processing),
            ("success", .success),
            ("cancelled", .cancelled),
            ("error", .error(message: "preview")),
        ]

        for (name, state) in states {
            switch state {
            case .processing:
                bubble.showProcessing()
            case .success:
                bubble.showSuccess()
            case .cancelled:
                bubble.showCancelled()
            case .error(let message):
                bubble.showError(message: message)
            }

            // Let the layer tree pick up the state change before capturing.
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            let view = bubble.containerView
            let bounds = view.bounds
            XCTAssertGreaterThan(bounds.width, 0, "container has no size")

            guard
                let rep = view.bitmapImageRepForCachingDisplay(in: bounds)
            else {
                XCTFail("could not create a bitmap for \(name)")
                return
            }
            view.cacheDisplay(in: bounds, to: rep)
            renderedByName[name] = rep

            guard let data = rep.representation(using: .png, properties: [:])
            else {
                XCTFail("could not encode \(name)")
                return
            }

            if writeFiles {
                let url = directory.appendingPathComponent("\(name).png")
                // .atomic writes via a temporary file and renames, so a
                // pre-existing symlink at the destination cannot be followed.
                try data.write(to: url, options: .atomic)
                print("bubble snapshot written: \(url.path)")
            }
        }

        XCTAssertEqual(renderedByName.count, states.count)

        // The states must be visually distinct — a bubble that renders the
        // same pixels for success and error tells the user nothing.
        let pixels = renderedByName.mapValues { $0.representation(
            using: .png, properties: [:]
        ) }
        for (left, right) in [
            ("processing", "success"),
            ("success", "cancelled"),
            ("success", "error"),
        ] {
            XCTAssertNotEqual(
                pixels[left] ?? nil,
                pixels[right] ?? nil,
                "\(left) and \(right) render identically"
            )
        }
    }
}
