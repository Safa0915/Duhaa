import XCTest
@testable import Duhaa

/// Covers the user-added mosque model (pure URL builders), its on-device store
/// (add / update / remove / persistence), and the email-suggestion builder.
final class CustomMosqueTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let name = "test.customMosques.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Model: callURL

    func testCallURLBuildsTelFromValidNumber() {
        let m = CustomMosque(name: "Masjid A", address: "1 St", phoneNumber: "+1 (555) 123-4567")
        XCTAssertEqual(m.callURL?.absoluteString, "tel://+15551234567")
    }

    func testCallURLNilWhenTooFewDigits() {
        let m = CustomMosque(name: "Masjid A", address: "1 St", phoneNumber: "123")
        XCTAssertNil(m.callURL)
    }

    func testCallURLNilWhenNoPhone() {
        let m = CustomMosque(name: "Masjid A", address: "1 St")
        XCTAssertNil(m.callURL)
    }

    // MARK: - Model: websiteURL

    func testWebsiteURLPrependsHTTPS() {
        XCTAssertEqual(CustomMosque.normalizedWebURL("masjid.org")?.absoluteString,
                       "https://masjid.org")
    }

    func testWebsiteURLKeepsExistingScheme() {
        XCTAssertEqual(CustomMosque.normalizedWebURL("http://masjid.org")?.absoluteString,
                       "http://masjid.org")
    }

    func testWebsiteURLNilWhenEmptyOrHostless() {
        XCTAssertNil(CustomMosque.normalizedWebURL(""))
        XCTAssertNil(CustomMosque.normalizedWebURL("   "))
        XCTAssertNil(CustomMosque.normalizedWebURL(nil))
    }

    // MARK: - Model: directionsURL

    func testDirectionsURLTargetsAppleMaps() {
        let m = CustomMosque(name: "Masjid An-Noor", address: "123 Main St")
        let url = m.directionsURL
        XCTAssertEqual(url?.host, "maps.apple.com")
        XCTAssertTrue(url?.query?.contains("daddr=") == true)
        // Both name and address feed the destination so Maps can geocode it.
        XCTAssertTrue(url?.absoluteString.contains("Masjid") == true)
        XCTAssertTrue(url?.absoluteString.contains("Main") == true)
    }

    // MARK: - Store

    func testStoreAddPersistsAcrossReload() {
        let defaults = freshDefaults()
        let store = CustomMosqueStore(defaults: defaults)
        store.add(CustomMosque(name: "Masjid A", address: "1 St"))
        store.add(CustomMosque(name: "Masjid B", address: "2 St"))
        XCTAssertEqual(store.mosques.count, 2)

        let reloaded = CustomMosqueStore(defaults: defaults)
        XCTAssertEqual(reloaded.mosques.map(\.name), ["Masjid A", "Masjid B"])
    }

    func testStoreUpdateReplacesInPlace() {
        let defaults = freshDefaults()
        let store = CustomMosqueStore(defaults: defaults)
        let original = CustomMosque(name: "Masjid A", address: "1 St")
        store.add(original)

        var edited = original
        edited.name = "Masjid A (Renamed)"
        store.update(edited)

        XCTAssertEqual(store.mosques.count, 1)
        XCTAssertEqual(store.mosques.first?.name, "Masjid A (Renamed)")
        XCTAssertEqual(store.mosques.first?.id, original.id)
    }

    func testStoreRemove() {
        let defaults = freshDefaults()
        let store = CustomMosqueStore(defaults: defaults)
        let a = CustomMosque(name: "Masjid A", address: "1 St")
        let b = CustomMosque(name: "Masjid B", address: "2 St")
        store.add(a)
        store.add(b)
        store.remove(a)
        XCTAssertEqual(store.mosques.map(\.name), ["Masjid B"])
    }

    // MARK: - Email suggestion

    func testSuggestionRequiresDirections() {
        var draft = MosqueSuggestion()
        XCTAssertFalse(draft.isValid, "Empty draft must be invalid")
        draft.address = "  "
        XCTAssertFalse(draft.isValid, "Whitespace-only directions must be invalid")
        draft.address = "Behind the central market"
        XCTAssertTrue(draft.isValid)
    }

    func testSuggestionSubjectUsesName() {
        var draft = MosqueSuggestion()
        draft.name = "Masjid An-Noor"
        draft.address = "123 Main St"
        XCTAssertEqual(draft.subject, "Duhaa Mosque Suggestion: Masjid An-Noor")
    }

    func testSuggestionSubjectFallsBackToAddress() {
        var draft = MosqueSuggestion()
        draft.address = "123 Main St"
        XCTAssertEqual(draft.subject, "Duhaa Mosque Suggestion: 123 Main St")
    }

    func testSuggestionBodyAndMailtoTargetTheDev() {
        var draft = MosqueSuggestion()
        draft.address = "123 Main St"
        draft.contact = "person@example.com"
        XCTAssertTrue(draft.body.contains("Directions / address: 123 Main St"))
        XCTAssertTrue(draft.body.contains("Contact: person@example.com"))

        let url = draft.mailtoURL(to: FeedbackStore.recipientEmail)
        XCTAssertEqual(url?.scheme, "mailto")
        XCTAssertEqual(url?.path, "duhaaapp@gmail.com")
        XCTAssertTrue(url?.query?.contains("subject=") == true)
    }
}
