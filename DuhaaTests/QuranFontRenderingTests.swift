import XCTest
import CoreGraphics
import CoreText
import UIKit
@testable import Duhaa

final class QuranFontRenderingTests: XCTestCase {
    func testFontPreferencesMatchQuranFoundationFields() {
        XCTAssertEqual(QuranFontPreference.kfgqpc.verseTextField, .textQPCHafs)
        XCTAssertEqual(QuranFontPreference.indopak.verseTextField, .textIndopak)
        XCTAssertEqual(QuranFontPreference.qcfV2.lineTextField, .codeV2)
        XCTAssertEqual(QuranFontPreference.tajweedV4.lineTextField, .codeV2)

        XCTAssertEqual(QuranFontPreference.indopak.mushafID, 3)
        XCTAssertEqual(QuranFontPreference.qcfV2.mushafID, 1)
        XCTAssertEqual(QuranFontPreference.tajweedV4.mushafID, 19)
    }

    func testPageFontNamesAndURLs() {
        XCTAssertEqual(QuranFontPreference.qcfV2.pageFontPostScriptName(page: 1), "QCF2001")
        XCTAssertEqual(QuranFontPreference.qcfV2.pageFontPostScriptName(page: 604), "QCF2604")
        XCTAssertEqual(QuranFontPreference.tajweedV4.pageFontPostScriptName(page: 1), "QCF4001_COLOR")
        XCTAssertEqual(QuranFontPreference.tajweedV4.pageFontPostScriptName(page: 604), "QCF4604_COLOR-Regular")

        XCTAssertEqual(QuranFontPreference.qcfV2.pageFontURL(page: 12)?.absoluteString,
                       "https://verses.quran.foundation/fonts/quran/hafs/v2/ttf/p12.ttf")
        XCTAssertEqual(QuranFontPreference.tajweedV4.pageFontURL(page: 12)?.absoluteString,
                       "https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/ttf/p12.ttf")
    }

    func testTajweedV4UsesDarkPaletteOnDarkBackgrounds() {
        XCTAssertEqual(QuranFontPreference.tajweedV4.colorPaletteIndex(isDark: true), 1)
        XCTAssertEqual(QuranFontPreference.tajweedV4.colorPaletteIndex(isDark: false), 0)
        XCTAssertNil(QuranFontPreference.qcfV2.colorPaletteIndex(isDark: true))
    }

    /// The Tajweed guide must document all 8 rules of the QCF V4 legend, complete
    /// in every language layer, with distinct light/dark palette colours.
    func testTajweedGuideCoversAllEightRulesCompletely() {
        let rules = TajweedRule.all
        XCTAssertEqual(rules.count, 8)
        XCTAssertEqual(Set(rules.map(\.id)).count, 8)

        for rule in rules {
            XCTAssertFalse(rule.english.isEmpty, "\(rule.id) missing English name")
            XCTAssertFalse(rule.arabic.isEmpty, "\(rule.id) missing Arabic name")
            XCTAssertFalse(rule.detail.isEmpty, "\(rule.id) missing description")
            XCTAssertNotEqual(rule.lightHex, rule.darkHex,
                              "\(rule.id) light/dark palettes should differ")
        }
    }

    /// A dense line closes its word gaps (negative kern on the spaces) instead of
    /// shrinking the font — every page keeps the same lettering size.
    func testClosingWordGapsNarrowsDenseLineWithoutShrinkingFont() throws {
        let font = try XCTUnwrap(UIFont(name: QuranFont.family, size: 20))
        // Generic Arabic filler words — 4 words, 3 gaps.
        let line = NSAttributedString(string: "كلمة كلمة كلمة كلمة", attributes: [.font: font])
        let originalWidth = Self.lineWidth(line)

        let tightened = MushafLineUIView.closingWordGaps(in: line, by: 3)
        let tightenedWidth = Self.lineWidth(tightened)

        // 3pt deficit over 3 gaps = 1pt cut per space (well under the per-space cap).
        XCTAssertEqual(tightenedWidth, originalWidth - 3, accuracy: 0.5)
        XCTAssertEqual(tightened.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, font)
    }

    /// The cut per gap is capped (a bit over half the space width) so words can
    /// tighten but never collide, no matter how large the deficit.
    func testClosingWordGapsCapsTheCutSoWordsNeverCollide() throws {
        let font = try XCTUnwrap(UIFont(name: QuranFont.family, size: 20))
        let spaceWidth = Self.lineWidth(NSAttributedString(string: " ", attributes: [.font: font]))
        let line = NSAttributedString(string: "كلمة كلمة كلمة كلمة", attributes: [.font: font])
        let originalWidth = Self.lineWidth(line)

        let tightened = MushafLineUIView.closingWordGaps(in: line, by: 500)
        let tightenedWidth = Self.lineWidth(tightened)

        XCTAssertEqual(tightenedWidth, originalWidth - 3 * spaceWidth * 0.55, accuracy: 0.5)
    }

    private static func lineWidth(_ text: NSAttributedString) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(
            CTLineCreateWithAttributedString(text as CFAttributedString), nil, nil, nil))
    }

    func testMushafLineBaselineKeepsLowInkInsideLineBox() {
        let inkBounds = CGRect(x: 0, y: -18, width: 120, height: 42)
        let baseline = MushafLineUIView.baselineY(boundsHeight: 54, inkBounds: inkBounds, padding: 4)

        XCTAssertEqual(baseline, 24, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(baseline + inkBounds.minY, 4 - 0.001)
        XCTAssertLessThanOrEqual(baseline + inkBounds.maxY, 50 + 0.001)
    }

    func testPaletteRewriteCopiesRequestedPaletteToDefault() throws {
        let fontData = Self.syntheticPaletteFont()
        let rewritten = try XCTUnwrap(OpenTypePaletteFont.dataByMakingPaletteDefault(fontData, palette: 1))

        let cpalOffset = 44
        let colorRecordsOffset = cpalOffset + 16
        let defaultPaletteRange = colorRecordsOffset..<(colorRecordsOffset + 8)
        let sourcePaletteRange = (colorRecordsOffset + 8)..<(colorRecordsOffset + 16)

        XCTAssertEqual(Array(rewritten[defaultPaletteRange]), Array(fontData[sourcePaletteRange]))
    }

    /// Both palette bakes of a page font must NOT share a PostScript name —
    /// CoreText resolves names process-wide and won't re-register a taken name,
    /// so a shared name made whichever palette loaded first stick forever
    /// (white base ink on light pages after visiting a dark background).
    func testPaletteRewriteRenamesFontSoVariantsCanCoexist() throws {
        let fontData = Self.syntheticPaletteFontWithNameTable()
        let rewritten = try XCTUnwrap(OpenTypePaletteFont.dataByMakingPaletteDefault(fontData, palette: 1))

        let nameOffset = 104
        let asciiName = String(decoding: rewritten[nameOffset..<(nameOffset + 13)], as: UTF8.self)
        XCTAssertEqual(asciiName, "QCF4001_DARK1")

        let utf16Bytes = Array(rewritten[(nameOffset + 13)..<(nameOffset + 39)])
        let expectedUTF16 = Array("QCF4001_DARK1".utf8).flatMap { [UInt8(0), $0] }
        XCTAssertEqual(utf16Bytes, expectedUTF16)

        // The palette copy still happens alongside the rename.
        let colorRecordsOffset = 60 + 16
        XCTAssertEqual(Array(rewritten[colorRecordsOffset..<(colorRecordsOffset + 8)]),
                       Array(fontData[(colorRecordsOffset + 8)..<(colorRecordsOffset + 16)]))
    }

    func testDecoderUsesIndoPakTextAndReadableArabic() throws {
        let page = try QuranComMushafPageAPI.decodePage(Self.fixture, page: 1, preference: .indopak)
        let line = try XCTUnwrap(page.lines.first)

        // The Indo-Pak font draws ayah numbers with the Extended Arabic-Indic
        // (Urdu) digits — its standard U+0660–0669 glyphs are blank — so the
        // marker is ﴿۱﴾ (U+06F1), not ﴿١﴾ (U+0661).
        XCTAssertEqual(line.text, "بِسۡمِ اللهِ ﴿۱﴾")
        XCTAssertEqual(line.accessibilityText, "بِسۡمِ اللهِ ﴿۱﴾")
        XCTAssertEqual(line.words.first?.text, "بِسۡمِ")
        XCTAssertEqual(line.words.first?.arabicText, "بِسۡمِ")
        XCTAssertFalse(try XCTUnwrap(line.words.last).isWord)
    }

    func testDecoderUsesQCFGlyphsButKeepsReadableArabic() throws {
        let page = try QuranComMushafPageAPI.decodePage(Self.fixture, page: 1, preference: .qcfV2)
        let line = try XCTUnwrap(page.lines.first)

        XCTAssertEqual(line.text, "ﱁ ﱂ ﱅ")
        XCTAssertEqual(line.accessibilityText, "بِسۡمِ ٱللَّهِ ﴿١﴾")
        XCTAssertEqual(line.words.first?.text, "ﱁ")
        XCTAssertEqual(line.words.first?.arabicText, "بِسۡمِ")
        XCTAssertEqual(line.words.last?.text, "ﱅ")
        XCTAssertEqual(line.words.last?.arabicText, "﴿١﴾")
    }

    private static let fixture = #"""
    {
      "verses": [
        {
          "id": 1,
          "verse_number": 1,
          "verse_key": "1:1",
          "text_uthmani": "بِسْمِ ٱللَّهِ",
          "text_qpc_hafs": "بِسۡمِ ٱللَّهِ ١",
          "text_indopak": "بِسۡمِ اللهِ",
          "code_v2": "ﱁ ﱂ ﱅ",
          "page_number": 1,
          "juz_number": 1,
          "words": [
            {
              "id": 1,
              "position": 1,
              "audio_url": "wbw/001_001_001.mp3",
              "char_type_name": "word",
              "text_uthmani": "بِسْمِ",
              "text_qpc_hafs": "بِسۡمِ",
              "text_indopak": "بِسۡمِ",
              "code_v2": "ﱁ",
              "line_number": 2,
              "page_number": 1,
              "translation": {"text": "In (the) name"},
              "transliteration": {"text": "bis'mi"}
            },
            {
              "id": 2,
              "position": 2,
              "audio_url": "wbw/001_001_002.mp3",
              "char_type_name": "word",
              "text_uthmani": "ٱللَّهِ",
              "text_qpc_hafs": "ٱللَّهِ",
              "text_indopak": "اللهِ",
              "code_v2": "ﱂ",
              "line_number": 2,
              "page_number": 1,
              "translation": {"text": "(of) Allah"},
              "transliteration": {"text": "l-lahi"}
            },
            {
              "id": 5,
              "position": 3,
              "audio_url": null,
              "char_type_name": "end",
              "text_uthmani": "١",
              "text_qpc_hafs": "١",
              "text_indopak": "١",
              "code_v2": "ﱅ",
              "line_number": 2,
              "page_number": 1,
              "translation": {"text": "(1)"},
              "transliteration": {"text": null}
            }
          ]
        }
      ]
    }
    """#.data(using: .utf8)!

    private static func syntheticPaletteFont() -> Data {
        var data = Data()

        appendUInt32(0x0001_0000, to: &data)
        appendUInt16(2, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(0, to: &data)

        appendTag("CPAL", to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(44, to: &data)
        appendUInt32(32, to: &data)

        appendTag("head", to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(76, to: &data)
        appendUInt32(12, to: &data)

        appendUInt16(0, to: &data)  // version
        appendUInt16(2, to: &data)  // entries per palette
        appendUInt16(2, to: &data)  // palette count
        appendUInt16(4, to: &data)  // color record count
        appendUInt32(16, to: &data) // first color record offset
        appendUInt16(0, to: &data)  // default palette starts at record 0
        appendUInt16(2, to: &data)  // palette 1 starts at record 2

        data.append(contentsOf: [0x00, 0x00, 0x00, 0xFF, 0x01, 0x02, 0x03, 0xFF])
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0x33, 0x22, 0x11, 0xFF])

        data.append(contentsOf: Array(repeating: UInt8(0), count: 12))
        return data
    }

    /// Like `syntheticPaletteFont`, plus a `name` table at offset 104 holding
    /// "QCF4001_COLOR" once in ASCII and once in UTF-16BE.
    private static func syntheticPaletteFontWithNameTable() -> Data {
        var data = Data()

        appendUInt32(0x0001_0000, to: &data)
        appendUInt16(3, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(0, to: &data)

        appendTag("CPAL", to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(60, to: &data)
        appendUInt32(32, to: &data)

        appendTag("head", to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(92, to: &data)
        appendUInt32(12, to: &data)

        appendTag("name", to: &data)
        appendUInt32(0, to: &data)
        appendUInt32(104, to: &data)
        appendUInt32(39, to: &data)

        appendUInt16(0, to: &data)  // version
        appendUInt16(2, to: &data)  // entries per palette
        appendUInt16(2, to: &data)  // palette count
        appendUInt16(4, to: &data)  // color record count
        appendUInt32(16, to: &data) // first color record offset
        appendUInt16(0, to: &data)  // default palette starts at record 0
        appendUInt16(2, to: &data)  // palette 1 starts at record 2

        data.append(contentsOf: [0x00, 0x00, 0x00, 0xFF, 0x01, 0x02, 0x03, 0xFF])
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0x33, 0x22, 0x11, 0xFF])

        data.append(contentsOf: Array(repeating: UInt8(0), count: 12))

        data.append(contentsOf: Array("QCF4001_COLOR".utf8))
        data.append(contentsOf: Array("QCF4001_COLOR".utf8).flatMap { [UInt8(0), $0] })
        return data
    }

    private static func appendTag(_ tag: String, to data: inout Data) {
        data.append(contentsOf: tag.utf8.prefix(4))
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }
}
