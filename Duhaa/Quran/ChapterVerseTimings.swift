import Foundation

/// Supplies the start time (ms) of an ayah within a full-surah "chapter"
/// recording, so the player can begin a chapter recitation at a chosen ayah by
/// seeking — rather than only from the start. Injected into `AyahPlayer` so it's
/// testable without hitting the network.
protocol ChapterVerseTimingProviding: Sendable {
    /// Start time (ms) of `ayah` in the surah recording for the given reciter, or
    /// nil when the reciter publishes no gapless timing (then play from the start).
    func startMilliseconds(reciterID: Int, surah: Int, ayah: Int) async -> Int?
}

/// Live provider backed by Quran.com's gapless verse-timing API, with
/// mp3quran.net's ayah-timing API covering reciters Quran.com doesn't time.
struct LiveChapterVerseTimings: ChapterVerseTimingProviding {
    func startMilliseconds(reciterID: Int, surah: Int, ayah: Int) async -> Int? {
        guard let reciter = Reciters.byID(reciterID) else { return nil }
        if let timingID = reciter.chapterTimingID {
            return await ChapterVerseTimings.timings(timingID: timingID, surah: surah)[ayah]
        }
        if let read = reciter.mp3quranTimingRead {
            return await ChapterVerseTimings.mp3quranTimings(read: read, surah: surah)[ayah]
        }
        return nil
    }
}

/// Fetches + caches Quran.com's per-ayah timestamps for a chapter (gapless)
/// recitation. The data maps each ayah to where it begins inside the one surah
/// MP3, which is what lets a full-surah recording start mid-surah.
@MainActor
enum ChapterVerseTimings {
    private static var cache: [String: [Int: Int]] = [:]

    /// `[ayahNumber: startMs]` for a surah, fetched once and cached. Returns an
    /// empty map (never throws) so the caller falls back to playing from the start.
    static func timings(timingID: Int, surah: Int) async -> [Int: Int] {
        let cacheKey = "\(timingID):\(surah)"
        if let cached = cache[cacheKey] { return cached }
        guard let url = URL(string:
            "https://api.quran.com/api/v4/chapter_recitations/\(timingID)/\(surah)?segments=true") else { return [:] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let map = parse(data)
            if !map.isEmpty { cache[cacheKey] = map }
            return map
        } catch {
            return [:]
        }
    }

    /// `[ayahNumber: startMs]` for a surah from mp3quran.net's ayat-timing API,
    /// for reciters whose chapter audio streams from an mp3quran folder. Same
    /// fetch-once cache and empty-map fallback as the Quran.com path.
    static func mp3quranTimings(read: Int, surah: Int) async -> [Int: Int] {
        let cacheKey = "mp3quran:\(read):\(surah)"
        if let cached = cache[cacheKey] { return cached }
        guard let url = URL(string:
            "https://www.mp3quran.net/api/v3/ayat_timing?surah=\(surah)&read=\(read)") else { return [:] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let map = parseMP3Quran(data)
            if !map.isEmpty { cache[cacheKey] = map }
            return map
        } catch {
            return [:]
        }
    }

    /// Decode mp3quran's `[{ayah, start_time}]` into `[ayahNumber: startMs]`.
    nonisolated static func parseMP3Quran(_ data: Data) -> [Int: Int] {
        guard let entries = try? JSONDecoder().decode([MP3QuranTiming].self, from: data) else { return [:] }
        var map: [Int: Int] = [:]
        for entry in entries {
            if let ayah = entry.ayah, let start = entry.startTime { map[ayah] = start }
        }
        return map
    }

    private struct MP3QuranTiming: Decodable {
        let ayah: Int?
        let startTime: Int?
        enum CodingKeys: String, CodingKey {
            case ayah
            case startTime = "start_time"
        }
    }

    /// Decode Quran.com's `audio_file.timestamps` into `[ayahNumber: startMs]`.
    nonisolated static func parse(_ data: Data) -> [Int: Int] {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return [:] }
        var map: [Int: Int] = [:]
        for entry in response.audioFile.timestamps ?? [] {
            if let ayah = entry.ayahNumber { map[ayah] = entry.timestampFrom }
        }
        return map
    }

    private struct Response: Decodable {
        let audioFile: AudioFile
        enum CodingKeys: String, CodingKey { case audioFile = "audio_file" }
    }

    private struct AudioFile: Decodable {
        let timestamps: [Timestamp]?
    }

    private struct Timestamp: Decodable {
        let verseKey: String
        let timestampFrom: Int
        enum CodingKeys: String, CodingKey {
            case verseKey = "verse_key"
            case timestampFrom = "timestamp_from"
        }
        /// "8:1" → 1 (the ayah number within its surah).
        var ayahNumber: Int? { verseKey.split(separator: ":").last.flatMap { Int($0) } }
    }
}
