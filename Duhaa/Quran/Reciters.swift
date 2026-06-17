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

    enum AudioKind: String, Decodable, Sendable {
        case ayah
        case chapter
    }

    var supportsAyahAudio: Bool {
        audioKind == .ayah && prefix != nil
    }

    var supportsChapterAudio: Bool {
        audioKind == .chapter && chapterPrefix != nil
    }

    func ayahURL(surah: Int, ayah: Int) -> URL? {
        guard supportsAyahAudio, let prefix else { return nil }
        let name = String(format: "%03d%03d", surah, ayah)
        return URL(string: "https://verses.quran.com/\(prefix)\(name).mp3")
    }

    func chapterURL(surah: Int) -> URL? {
        guard supportsChapterAudio, let chapterPrefix else { return nil }
        return URL(string: "\(chapterPrefix)\(surah).mp3")
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, audioKind, prefix, chapterPrefix
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        chapterPrefix = try container.decodeIfPresent(String.self, forKey: .chapterPrefix)
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
