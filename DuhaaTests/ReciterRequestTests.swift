import XCTest
@testable import Duhaa

/// Covers the reciter-request email builder: validation, subject, body and the
/// `mailto:` URL targeting the developer.
final class ReciterRequestTests: XCTestCase {
    func testRequiresName() {
        var draft = ReciterRequest()
        XCTAssertFalse(draft.isValid, "Empty draft must be invalid")
        draft.name = "   "
        XCTAssertFalse(draft.isValid, "Whitespace-only name must be invalid")
        draft.name = "Mishary Alafasy"
        XCTAssertTrue(draft.isValid)
    }

    func testSubjectUsesName() {
        var draft = ReciterRequest()
        draft.name = "Abdul Basit"
        XCTAssertEqual(draft.subject, "Duhaa Reciter Request: Abdul Basit")
    }

    func testSubjectFallsBackWhenNoName() {
        let draft = ReciterRequest()
        XCTAssertEqual(draft.subject, "Duhaa Reciter Request")
    }

    func testBodyAndMailtoTargetTheDev() {
        var draft = ReciterRequest()
        draft.name = "Abdul Basit"
        draft.detail = "Mujawwad style"
        draft.contact = "person@example.com"
        XCTAssertTrue(draft.body.contains("Reciter: Abdul Basit"))
        XCTAssertTrue(draft.body.contains("Mujawwad style"))
        XCTAssertTrue(draft.body.contains("Contact: person@example.com"))

        let url = draft.mailtoURL(to: FeedbackStore.recipientEmail)
        XCTAssertEqual(url?.scheme, "mailto")
        XCTAssertEqual(url?.path, "duhaaapp@gmail.com")
        XCTAssertTrue(url?.query?.contains("subject=") == true)
    }
}
