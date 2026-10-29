import XCTest
@testable import Make_It_Sound_Natural

final class CorrectionVariantsJSONTests: XCTestCase {
    func testMarkerContentListsVariantsInMarkerOrder() throws {
        let json = """
        {"concise":"n","formal":"f","casual":"c","balanced":"b"}
        """

        let variants = try JSONDecoder().decode(
            CorrectionVariantsJSON.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(
            variants.markerContent,
            "---BALANCED---\nb\n\n---CASUAL---\nc\n\n" +
            "---FORMAL---\nf\n\n---CONCISE---\nn"
        )
    }

    func testDecodingFailsWhenAKeyIsMissing() {
        let json = """
        {"balanced":"b","casual":"c","formal":"f"}
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CorrectionVariantsJSON.self,
                from: Data(json.utf8)
            )
        )
    }
}
