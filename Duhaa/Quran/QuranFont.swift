import SwiftUI
import CoreText
import Foundation

enum QuranTextField: Sendable {
    case textUthmani
    case textQPCHafs
    case textIndopak
    case codeV2
}

enum QuranFontPreference: String, CaseIterable, Identifiable, Sendable {
    case kfgqpc
    case indopak
    case qcfV2
    case tajweedV4

    static let storageKey = "duhaa.quran.readerFont"

    var id: String { rawValue }

    init(storageValue: String) {
        self = QuranFontPreference(rawValue: storageValue) ?? .kfgqpc
    }

    var title: String {
        switch self {
        case .kfgqpc: return "QPC Hafs"
        case .indopak: return "Indo-Pak"
        case .qcfV2: return "QCF V2"
        case .tajweedV4: return "Tajweed V4"
        }
    }

    var subtitle: String {
        switch self {
        case .kfgqpc:
            return "Uthmanic Hafs Unicode"
        case .indopak:
            return "South Asian Nastaleeq script"
        case .qcfV2:
            return "Quran.com page glyph font"
        case .tajweedV4:
            return "Colored Tajweed page font"
        }
    }

    /// Quran Foundation mushaf ids for the matching text/font mode.
    var mushafID: Int {
        switch self {
        case .kfgqpc: return 5
        case .indopak: return 3
        case .qcfV2: return 1
        case .tajweedV4: return 19
        }
    }

    var lineTextField: QuranTextField {
        switch self {
        case .kfgqpc: return .textQPCHafs
        case .indopak: return .textIndopak
        case .qcfV2, .tajweedV4: return .codeV2
        }
    }

    var verseTextField: QuranTextField {
        switch self {
        case .indopak: return .textIndopak
        case .kfgqpc, .qcfV2, .tajweedV4: return .textQPCHafs
        }
    }

    var unicodeFontName: String? {
        switch self {
        case .kfgqpc: return QuranFont.family
        case .indopak: return QuranFont.indoPakFamily
        case .qcfV2, .tajweedV4: return nil
        }
    }

    var isPageFont: Bool {
        switch self {
        case .qcfV2, .tajweedV4: return true
        case .kfgqpc, .indopak: return false
        }
    }

    /// The Indo-Pak Nastaleeq font ships blank glyphs for the standard
    /// Arabic-Indic digits (U+0660–0669) and renders numbers with the Extended
    /// Arabic-Indic (Urdu) set (U+06F0–06F9) instead, so ayah-number markers must
    /// use those digits — otherwise they show up empty.
    var usesEasternArabicDigits: Bool { self == .indopak }

    /// Tajweed V4 is a multi-palette COLR colour font. Its default palette (0) is
    /// tuned for a white page. When a dark palette is needed, the page-font loader
    /// bakes palette 1 into a cached copy of the font so renderers that ignore
    /// `kCTFontPaletteAttribute` still draw white base ink.
    func colorPaletteIndex(isDark: Bool) -> Int? {
        self == .tajweedV4 ? (isDark ? 1 : 0) : nil
    }

    var fallbackUnicodePreference: QuranFontPreference {
        isPageFont ? .kfgqpc : self
    }

    var apiWordFields: String {
        "text_uthmani,text_qpc_hafs,text_indopak,code_v2,line_number,page_number"
    }

    var apiVerseFields: String {
        "text_uthmani,text_qpc_hafs,text_indopak,juz_number,page_number"
    }

    func pageFontPostScriptName(page: Int) -> String? {
        let clamped = min(max(page, 1), 604)
        switch self {
        case .qcfV2:
            return String(format: "QCF2%03d", clamped)
        case .tajweedV4:
            let base = String(format: "QCF4%03d_COLOR", clamped)
            return clamped >= 100 ? "\(base)-Regular" : base
        case .kfgqpc, .indopak:
            return nil
        }
    }

    func pageFontURL(page: Int) -> URL? {
        let clamped = min(max(page, 1), 604)
        let path: String
        switch self {
        case .qcfV2:
            path = "hafs/v2/ttf/p\(clamped).ttf"
        case .tajweedV4:
            path = "hafs/v4/colrv1/ttf/p\(clamped).ttf"
        case .kfgqpc, .indopak:
            return nil
        }
        return URL(string: "https://verses.quran.foundation/fonts/quran/\(path)")
    }
}

/// The bundled KFGQPC HAFS Uthmanic Script font — designed for Quranic Uthmani
/// text, so it places every harakah/dagger-alif correctly (the system Arabic
/// font does not). Registered once at launch; used for all Quran Arabic.
enum QuranFont {
    static let family = "KFGQPC HAFS Uthmanic Script"
    static let indoPakFamily = "AlQuran IndoPak by QuranWBW"

    static func register() {
        registerFont(resource: "UthmanicHafs1Ver18")
        registerFont(resource: "indopak-nastaleeq-waqf-lazim-v4.2.1")
    }

    private static func registerFont(resource: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "ttf")
            ?? Bundle.main.url(forResource: resource, withExtension: "ttf", subdirectory: "Quran/Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// The Uthmani font at a given point size (falls back to the system font if
    /// registration ever fails).
    static func uthmani(_ size: CGFloat) -> Font { .custom(family, size: size, relativeTo: .body) }

    static func reader(_ preference: String, size: CGFloat, pageFontName: String? = nil) -> Font {
        if let pageFontName {
            return .custom(pageFontName, size: size, relativeTo: .body)
        }

        let font = QuranFontPreference(storageValue: preference).fallbackUnicodePreference
        guard let name = font.unicodeFontName else {
            return .system(size: size, weight: .regular)
        }
        return .custom(name, size: size, relativeTo: .body)
    }

    static func bismillah(for preference: String) -> String {
        switch QuranFontPreference(storageValue: preference).fallbackUnicodePreference {
        case .indopak:
            return "بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ"
        case .kfgqpc, .qcfV2, .tajweedV4:
            return "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
        }
    }
}

actor QuranPageFontLoader {
    static let shared = QuranPageFontLoader()

    private var loadedFontNames: [String: String] = [:]

    func fontName(forPage page: Int, preference: QuranFontPreference, palette: Int? = nil) async -> String? {
        guard let fontName = preference.pageFontPostScriptName(page: page),
              let remoteURL = preference.pageFontURL(page: page) else {
            return preference.unicodeFontName
        }

        let clampedPage = min(max(page, 1), 604)
        let bakedPalette = preference == .tajweedV4 ? palette : nil
        let cacheKey = "\(preference.rawValue)-\(clampedPage)-palette\(bakedPalette ?? 0)"
        if let loaded = loadedFontNames[cacheKey] {
            return loaded
        }

        do {
            let localURL = try localFontURL(forPage: page, preference: preference)
            if !FileManager.default.fileExists(atPath: localURL.path) {
                let (downloaded, response) = try await URLSession.shared.download(from: remoteURL)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    return nil
                }
                try FileManager.default.moveItem(at: downloaded, to: localURL)
            }

            let registrationURL = try fontURLForRegistration(originalURL: localURL,
                                                             page: page,
                                                             preference: preference,
                                                             palette: bakedPalette)
            CTFontManagerRegisterFontsForURL(registrationURL as CFURL, .process, nil)
            let registeredName = Self.postScriptName(in: registrationURL) ?? fontName
            loadedFontNames[cacheKey] = registeredName
            return registeredName
        } catch {
            return nil
        }
    }

    private static func postScriptName(in url: URL) -> String? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first else {
            return nil
        }
        return CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
    }

    private func localFontURL(forPage page: Int, preference: QuranFontPreference) throws -> URL {
        let directory = try fontDirectory(for: preference)
        return directory.appendingPathComponent("p\(min(max(page, 1), 604)).ttf")
    }

    /// "v2" marks copies whose PostScript name was rewritten alongside the palette —
    /// older "-palette1.ttf" bakes kept the original name and clashed with it.
    private func paletteFontURL(forPage page: Int, preference: QuranFontPreference, palette: Int) throws -> URL {
        let directory = try fontDirectory(for: preference)
        return directory.appendingPathComponent("p\(min(max(page, 1), 604))-palette\(palette)-v2.ttf")
    }

    private func fontURLForRegistration(originalURL: URL, page: Int,
                                        preference: QuranFontPreference,
                                        palette: Int?) throws -> URL {
        guard preference == .tajweedV4, let palette, palette > 0 else {
            return originalURL
        }

        let variantURL = try paletteFontURL(forPage: page, preference: preference, palette: palette)
        if !needsPaletteVariantRefresh(originalURL: originalURL, variantURL: variantURL) {
            return variantURL
        }

        let originalData = try Data(contentsOf: originalURL)
        guard let paletteData = OpenTypePaletteFont.dataByMakingPaletteDefault(originalData, palette: palette) else {
            return originalURL
        }
        try paletteData.write(to: variantURL, options: .atomic)
        return variantURL
    }

    private func needsPaletteVariantRefresh(originalURL: URL, variantURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: variantURL.path) else { return true }
        let originalDate = (try? fileManager.attributesOfItem(atPath: originalURL.path)[.modificationDate]) as? Date
        let variantDate = (try? fileManager.attributesOfItem(atPath: variantURL.path)[.modificationDate]) as? Date
        guard let originalDate, let variantDate else { return true }
        return originalDate > variantDate
    }

    private func fontDirectory(for preference: QuranFontPreference) throws -> URL {
        let caches = try FileManager.default.url(for: .cachesDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true)
        let directory = caches
            .appendingPathComponent("QuranPageFonts", isDirectory: true)
            .appendingPathComponent(preference.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum OpenTypePaletteFont {
    private struct Table {
        let recordOffset: Int
        let offset: Int
        let length: Int
    }

    static func dataByMakingPaletteDefault(_ data: Data, palette: Int) -> Data? {
        guard palette > 0,
              let cpal = table(named: "CPAL", in: data),
              cpal.length >= 14 else {
            return nil
        }

        let tableStart = cpal.offset
        let numPaletteEntries = Int(readUInt16(data, at: tableStart + 2))
        let numPalettes = Int(readUInt16(data, at: tableStart + 4))
        let firstColorRecordOffset = Int(readUInt32(data, at: tableStart + 8))
        let paletteIndicesOffset = tableStart + 12

        guard palette < numPalettes,
              numPaletteEntries > 0,
              paletteIndicesOffset + (palette + 1) * 2 <= tableStart + cpal.length else {
            return nil
        }

        let defaultRecordIndex = Int(readUInt16(data, at: paletteIndicesOffset))
        let sourceRecordIndex = Int(readUInt16(data, at: paletteIndicesOffset + palette * 2))
        let colorRecordsOffset = tableStart + firstColorRecordOffset
        let byteCount = numPaletteEntries * 4
        let defaultOffset = colorRecordsOffset + defaultRecordIndex * 4
        let sourceOffset = colorRecordsOffset + sourceRecordIndex * 4

        guard defaultOffset >= tableStart,
              sourceOffset >= tableStart,
              defaultOffset + byteCount <= tableStart + cpal.length,
              sourceOffset + byteCount <= tableStart + cpal.length else {
            return nil
        }

        var output = data
        for index in 0..<byteCount {
            output[defaultOffset + index] = data[sourceOffset + index]
        }
        renameForPalette(in: &output, palette: palette)
        updateChecksums(in: &output)
        return output
    }

    /// CoreText resolves fonts by PostScript name process-wide, and it won't
    /// reliably re-register a different file under a name that's already in use —
    /// so a baked palette copy sharing the original's name means whichever variant
    /// registered first wins forever (dark ink on dark pages, or white on light).
    /// Renaming the copy ("_COLOR" → "_DARKn", same byte length so no offsets
    /// shift) lets both variants stay registered side by side.
    private static func renameForPalette(in data: inout Data, palette: Int) {
        guard let name = table(named: "name", in: data) else { return }

        let pattern = Array("_COLOR".utf8)
        let replacement = Array("_DARK\(palette)".utf8)
        guard replacement.count == pattern.count else { return }

        let range = name.offset..<(name.offset + name.length)
        replaceOccurrences(of: pattern, with: replacement, in: &data, range: range)
        replaceOccurrences(of: pattern.flatMap { [UInt8(0), $0] },
                           with: replacement.flatMap { [UInt8(0), $0] },
                           in: &data,
                           range: range)
    }

    private static func replaceOccurrences(of pattern: [UInt8], with replacement: [UInt8],
                                           in data: inout Data, range: Range<Int>) {
        guard !pattern.isEmpty, pattern.count == replacement.count,
              range.lowerBound >= 0, range.upperBound <= data.count else { return }

        var cursor = range.lowerBound
        while cursor + pattern.count <= range.upperBound {
            var matches = true
            for index in 0..<pattern.count where data[cursor + index] != pattern[index] {
                matches = false
                break
            }
            if matches {
                for index in 0..<replacement.count {
                    data[cursor + index] = replacement[index]
                }
                cursor += pattern.count
            } else {
                cursor += 1
            }
        }
    }

    private static func updateChecksums(in data: inout Data) {
        guard let head = table(named: "head", in: data),
              head.length >= 12 else {
            return
        }

        for tag in ["CPAL", "name"] {
            guard let touched = table(named: tag, in: data) else { continue }
            writeUInt32(checksum(data, offset: touched.offset, length: touched.length),
                        to: &data,
                        at: touched.recordOffset + 4)
        }
        writeUInt32(0, to: &data, at: head.offset + 8)
        let adjustment = UInt32(0xB1B0AFBA) &- checksum(data, offset: 0, length: data.count)
        writeUInt32(adjustment, to: &data, at: head.offset + 8)
    }

    private static func table(named name: String, in data: Data) -> Table? {
        guard data.count >= 12 else { return nil }
        let numTables = Int(readUInt16(data, at: 4))
        let wantedTag = tagValue(name)

        for index in 0..<numTables {
            let recordOffset = 12 + index * 16
            guard recordOffset + 16 <= data.count else { return nil }
            guard readUInt32(data, at: recordOffset) == wantedTag else { continue }

            let offset = Int(readUInt32(data, at: recordOffset + 8))
            let length = Int(readUInt32(data, at: recordOffset + 12))
            guard offset >= 0, length >= 0, offset + length <= data.count else { return nil }
            return Table(recordOffset: recordOffset, offset: offset, length: length)
        }
        return nil
    }

    private static func checksum(_ data: Data, offset: Int, length: Int) -> UInt32 {
        var sum: UInt32 = 0
        var cursor = offset
        let end = offset + length

        while cursor < end {
            var word: UInt32 = 0
            for byteIndex in 0..<4 {
                let index = cursor + byteIndex
                if index < end {
                    word |= UInt32(data[index]) << UInt32(24 - byteIndex * 8)
                }
            }
            sum = sum &+ word
            cursor += 4
        }

        return sum
    }

    private static func tagValue(_ tag: String) -> UInt32 {
        tag.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func writeUInt32(_ value: UInt32, to data: inout Data, at offset: Int) {
        guard offset + 4 <= data.count else { return }
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }
}
