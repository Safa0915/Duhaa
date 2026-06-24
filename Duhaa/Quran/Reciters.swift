import Foundation

/// A Quran audio option. Most entries are ayah-by-ayah recitations from
/// verses.quran.com; Quran.com media-reciter IDs can also point at full-surah
/// chapter recordings, which are deliberately modeled separately.
struct Reciter: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let audioKind: AudioKind
    let prefix: String?
    let chapterPrefix: String?
    /// Profile photo (Quran.com CDN). Optional — the gallery falls back to a
    /// themed monogram when absent or if the image fails to load.
    let imageURL: URL?
    /// Bundled profile photo asset. Preferred over the remote URL when present.
    let imageAssetName: String?
    /// Whether chapter audio filenames are zero-padded to 3 digits (008.mp3).
    /// Most QuranicAudio paths are; the newer `qdc` streaming paths use bare
    /// numbers (8.mp3). Defaults to true so existing reciters are unaffected.
    let chapterPadded: Bool
    /// Quran.com recitation id whose gapless verse-timing data lets a full-surah
    /// recording start at a chosen ayah (by seeking). Nil for chapter recordings
    /// without published timing — those can only play from the start.
    let chapterTimingID: Int?

    enum AudioKind: String, Decodable, Sendable {
        case ayah
        case chapter
    }

    /// Two-letter monogram for the avatar fallback (first + last name word,
    /// parentheticals like "(Murattal)" stripped).
    var initials: String {
        let cleaned = name.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
        let words = cleaned.split { $0 == " " || $0 == "-" }.map(String.init).filter { !$0.isEmpty }
        guard let first = words.first?.first else { return "?" }
        if words.count > 1, let last = words.last?.first { return String([first, last]).uppercased() }
        return String(first).uppercased()
    }

    var supportsAyahAudio: Bool {
        audioKind == .ayah && prefix != nil
    }

    var supportsChapterAudio: Bool {
        audioKind == .chapter && chapterPrefix != nil
    }

    /// A full-surah recording that can begin at a chosen ayah (has timing data).
    var supportsAyahSeek: Bool {
        supportsChapterAudio && chapterTimingID != nil
    }

    func ayahURL(surah: Int, ayah: Int) -> URL? {
        guard supportsAyahAudio, let prefix else { return nil }
        let name = String(format: "%03d%03d", surah, ayah)
        return URL(string: "https://verses.quran.com/\(prefix)\(name).mp3")
    }

    func chapterURL(surah: Int) -> URL? {
        guard supportsChapterAudio, let chapterPrefix else { return nil }
        // Zero-padded to 3 digits (008.mp3) for most paths; bare (8.mp3) for qdc.
        let number = chapterPadded ? String(format: "%03d", surah) : String(surah)
        return URL(string: "\(chapterPrefix)\(number).mp3")
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, audioKind, prefix, chapterPrefix, imageURL, imageAssetName, chapterPadded, chapterTimingID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        chapterPrefix = try container.decodeIfPresent(String.self, forKey: .chapterPrefix)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        imageAssetName = try container.decodeIfPresent(String.self, forKey: .imageAssetName)
        chapterPadded = try container.decodeIfPresent(Bool.self, forKey: .chapterPadded) ?? true
        chapterTimingID = try container.decodeIfPresent(Int.self, forKey: .chapterTimingID)
        audioKind = try container.decodeIfPresent(AudioKind.self, forKey: .audioKind)
            ?? (chapterPrefix == nil ? .ayah : .chapter)
    }
}

enum Reciters {
    static let all: [Reciter] = load()

    /// Mishary Rashid Alafasy — Duhaa's original voice, kept as the default.
    static let defaultID = 7

    static func byID(_ id: Int) -> Reciter? { all.first { $0.id == id } }

    static func loadAsync(priority: TaskPriority = .utility) async -> [Reciter] {
        await Task.detached(priority: priority) {
            all
        }.value
    }

    private struct File: Decodable { let reciters: [Reciter] }
    private final class BundleToken {}

    private static func load() -> [Reciter] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "reciters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.reciters
    }
}
