import Foundation

/// One word's audio timing within an ayah, from Quran.com's word-by-word
/// "segments" data. `word` is the 1-based position of the word in the ayah.
struct QuranWordSegment: Equatable, Sendable, Codable {
    let word: Int
    let startMs: Int
    let endMs: Int
}

/// One Arabic word plus its English gloss (Quran.com word-by-word translation).
struct QuranAyahWord: Equatable, Sendable, Codable {
    let arabic: String
    let translation: String
}

/// Everything the Listen player needs for one ayah, from a single Quran.com call:
/// the per-word Arabic + translation, and the per-word audio timing.
struct QuranAyahTrace: Equatable, Sendable, Codable {
    let words: [QuranAyahWord]
    let segments: [QuranWordSegment]

    var isEmpty: Bool { words.isEmpty && segments.isEmpty }
    static let empty = QuranAyahTrace(words: [], segments: [])
}

/// Fetches + caches Quran.com word-by-word data (Arabic, translation, timing) so
/// the Listen player can show the exact word being recited with its meaning —
/// true karaoke sync instead of the linear `QuranWordTrace` estimate.
///
/// Offline-first: when a surah has been downloaded, its traces are saved to disk
/// (by `QuranOfflineLibrary`) and read back here, so word-by-word works with no
/// network. Online ayahs are fetched on demand and cached in memory. Reciters /
/// ayahs without published data return an empty trace and the player falls back
/// to the bundled text + linear estimate.
///
/// For per-ayah reciters our `Reciter.id` IS the Quran.com recitation id.
@MainActor
enum QuranWordSegments {
    private static var cache: [String: QuranAyahTrace] = [:]
    private static var hydratedSurahs: Set<String> = []

    private static func key(reciterID: Int, surah: Int, ayah: Int) -> String {
        "\(reciterID):\(surah):\(ayah)"
    }

    /// Pull a downloaded surah's saved traces into the in-memory cache (once).
    private static func hydrateFromDisk(reciterID: Int, surah: Int) {
        let surahKey = "\(reciterID):\(surah)"
        guard !hydratedSurahs.contains(surahKey) else { return }
        hydratedSurahs.insert(surahKey)
        guard let saved = QuranOfflineStore.savedTraces(reciterID: reciterID, surah: surah) else { return }
        for (ayahString, trace) in saved {
            guard let ayah = Int(ayahString) else { continue }
            cache[key(reciterID: reciterID, surah: surah, ayah: ayah)] = trace
        }
    }

    /// Already-available trace (memory, or a downloaded surah's disk file). No network.
    static func cachedTrace(reciterID: Int, surah: Int, ayah: Int) -> QuranAyahTrace? {
        hydrateFromDisk(reciterID: reciterID, surah: surah)
        return cache[key(reciterID: reciterID, surah: surah, ayah: ayah)]
    }

    /// Disk (downloaded) → memory → network. Empty trace = unavailable.
    static func loadTrace(reciterID: Int, surah: Int, ayah: Int) async -> QuranAyahTrace {
        hydrateFromDisk(reciterID: reciterID, surah: surah)
        let cacheKey = key(reciterID: reciterID, surah: surah, ayah: ayah)
        if let cached = cache[cacheKey] { return cached }

        let trace = await fetchTrace(reciterID: reciterID, surah: surah, ayah: ayah)
        cache[cacheKey] = trace  // cache even when empty, so we don't refetch
        return trace
    }

    /// Forget cached/hydrated traces for a surah (called when its download is removed).
    static func forget(reciterID: Int, surah: Int) {
        hydratedSurahs.remove("\(reciterID):\(surah)")
        let prefix = "\(reciterID):\(surah):"
        for cacheKey in cache.keys where cacheKey.hasPrefix(prefix) {
            cache.removeValue(forKey: cacheKey)
        }
    }

    static func forgetAll() {
        cache.removeAll()
        hydratedSurahs.removeAll()
    }

    /// Network fetch + parse only (no cache). Safe to call off the main actor — used
    /// by the offline downloader to save traces for the whole surah.
    nonisolated static func fetchTrace(reciterID: Int, surah: Int, ayah: Int) async -> QuranAyahTrace {
        guard let url = URL(string:
            "https://api.quran.com/api/v4/verses/by_key/\(surah):\(ayah)"
            + "?words=true&word_fields=text_uthmani&word_translation_language=en&audio=\(reciterID)") else {
            return .empty
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .empty
            }
            return parseTrace(data)
        } catch {
            return .empty
        }
    }

    /// 0-based index of the word being recited at `ms` (the last word whose
    /// segment has started). `nil` before the first word begins.
    nonisolated static func activeWordIndex(atMs ms: Int, segments: [QuranWordSegment], wordCount: Int) -> Int? {
        guard !segments.isEmpty, wordCount > 0 else { return nil }
        var index: Int?
        for segment in segments where ms >= segment.startMs {
            index = segment.word - 1
        }
        guard let index else { return nil }
        return min(max(index, 0), wordCount - 1)
    }

    /// Segments only (kept for callers/tests that just need the timing).
    nonisolated static func parse(_ data: Data) -> [QuranWordSegment] {
        parseTrace(data).segments
    }

    /// Decodes `{ verse: { words: [{ text_uthmani, translation:{text}, char_type_name }],
    /// audio: { segments: [[…]] } } }`. Segment tuples are `[segIndex, word, startMs, endMs]`
    /// (4) or `[word, startMs, endMs]` (3). The verse-number marker (`char_type_name == "end"`)
    /// is dropped so word indices line up with the segments.
    nonisolated static func parseTrace(_ data: Data) -> QuranAyahTrace {
        struct Root: Decodable { let verse: Verse }
        struct Verse: Decodable { let words: [Word]?; let audio: Audio? }
        struct Word: Decodable {
            let charTypeName: String?
            let textUthmani: String?
            let translation: Translation?
        }
        struct Translation: Decodable { let text: String? }
        struct Audio: Decodable { let segments: [[Int]]? }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let root = try? decoder.decode(Root.self, from: data) else { return .empty }

        let words: [QuranAyahWord] = (root.verse.words ?? [])
            .filter { ($0.charTypeName ?? "word") == "word" }
            .map { QuranAyahWord(arabic: $0.textUthmani ?? "", translation: $0.translation?.text ?? "") }

        let segments: [QuranWordSegment] = (root.verse.audio?.segments ?? []).compactMap { tuple in
            if tuple.count >= 4 {
                return QuranWordSegment(word: tuple[1], startMs: tuple[2], endMs: tuple[3])
            } else if tuple.count == 3 {
                return QuranWordSegment(word: tuple[0], startMs: tuple[1], endMs: tuple[2])
            }
            return nil
        }

        return QuranAyahTrace(words: words, segments: segments)
    }
}
