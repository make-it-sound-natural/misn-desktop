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

    func testBlankSelectedVariantIsNotPasteable() throws {
        let json = """
        {"balanced":"  ","casual":"c","formal":"f","concise":"n"}
        """
        let content = try JSONDecoder().decode(
            CorrectionVariantsJSON.self,
            from: Data(json.utf8)
        ).markerContent
        let service = LLMService()

        XCTAssertNil(service.pasteableVariant(from: content, variant: "Balanced"))
        XCTAssertEqual(
            service.pasteableVariant(from: content, variant: "Casual"),
            "c"
        )
    }
}
