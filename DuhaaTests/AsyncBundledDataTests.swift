import XCTest
@testable import Duhaa

final class AsyncBundledDataTests: XCTestCase {
    func testAsyncBundledDataLoadersReturnContent() async {
        async let quran = Quran.loadAsync()
        async let duas = Duas.loadAsync()
        async let learn = Learn.loadAsync()
        async let reciters = Reciters.loadAsync()

        let loaded = await (quran, duas, learn, reciters)

        XCTAssertEqual(loaded.0.surahs.count, 114)
        XCTAssertFalse(loaded.1.isEmpty)
        XCTAssertEqual(loaded.2.count, 9)
        XCTAssertFalse(loaded.3.isEmpty)
    }
}
