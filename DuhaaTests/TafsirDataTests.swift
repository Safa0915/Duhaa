import XCTest
@testable import Duhaa

/// Guards the bundled offline tafsir: the default edition ships, decodes, and resolves
/// commentary — including Ibn Kathir's grouped (ranged) blocks.
final class TafsirDataTests: XCTestCase {

    func testDefaultEditionIsRegistered() {
        XCTAssertFalse(Tafsir.editions.isEmpty)
        XCTAssertEqual(Tafsir.edition(Tafsir.defaultID).id, Tafsir.defaultID)
        // An unknown id falls back to the first edition, never crashes.
        XCTAssertEqual(Tafsir.edition("does-not-exist").id, Tafsir.editions[0].id)
    }

    func testBundledTafsirLoadsAndResolvesAyah() async {
        let edition = Tafsir.edition(Tafsir.defaultID)
        let file = await TafsirLoader.shared.load(edition)
        let loaded = try? XCTUnwrap(file)
        XCTAssertEqual(loaded?.slug, "en-tafisr-ibn-kathir")
        XCTAssertFalse(loaded?.blocks.isEmpty ?? true)

        // Al-Fatihah 1:1 has commentary.
        let opening = loaded?.block(surah: 1, ayah: 1)
        XCTAssertNotNil(opening)
        XCTAssertFalse(opening?.t.isEmpty ?? true)
    }

    func testGroupedBlockCoversItsWholeRange() async {
        let file = await TafsirLoader.shared.load(Tafsir.edition(Tafsir.defaultID))
        guard let file else { return XCTFail("tafsir failed to load") }
        // Ibn Kathir groups several ayahs under one block; any such block must resolve
        // for every ayah in its range.
        guard let ranged = file.blocks.first(where: { $0.b > $0.a }) else {
            return XCTFail("expected at least one grouped (ranged) block")
        }
        for ayah in ranged.a...ranged.b {
            XCTAssertEqual(file.block(surah: ranged.s, ayah: ayah)?.t, ranged.t)
        }
    }
}
