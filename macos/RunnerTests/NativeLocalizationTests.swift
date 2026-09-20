import Foundation
import XCTest

final class NativeLocalizationTests: XCTestCase {
    func testMenuBarLabelsResolveForEverySupportedNativeLocale() throws {
        let bundle = Bundle.main
        let locales = try XCTUnwrap(
            bundle.object(forInfoDictionaryKey: "CFBundleLocalizations")
                as? [String]
        )
        XCTAssertFalse(locales.isEmpty)
        let resources = try XCTUnwrap(bundle.resourceURL)

        for locale in locales {
            let directory = resources.appendingPathComponent("\(locale).lproj")
            let stringsURL = directory.appendingPathComponent(
                "Localizable.strings"
            )
            // Read the exact locale resource so English fallback cannot hide
            // an omitted translation or an unbundled localization.
            let data = try Data(contentsOf: stringsURL)
            let strings = try XCTUnwrap(
                PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: String]
            )
            let localizedBundle = try XCTUnwrap(Bundle(url: directory))

            for key in ["MenuBar.Open", "MenuBar.Quit"] {
                let expected = try XCTUnwrap(strings[key], "\(locale): \(key)")
                XCTAssertFalse(
                    expected.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty,
                    "\(locale): \(key)"
                )
                XCTAssertNotEqual(expected, key, "\(locale): \(key)")
                XCTAssertEqual(
                    localizedBundle.localizedString(
                        forKey: key,
                        value: "Missing translation",
                        table: nil
                    ),
                    expected,
                    "\(locale): \(key)"
                )
            }
        }
    }
}
