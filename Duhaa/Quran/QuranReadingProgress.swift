import Foundation
import Observation

/// Tracks how much of the Quran has been read — a per-surah furthest-ayah marker,
/// rolled up into overall khatmah (completion) progress. Pure encouragement: it
/// only ever moves forward as you read, it never nags, and you can reset to begin a
/// fresh khatmah. A lifetime count of completed khatmahs is kept as a quiet badge.
///
/// `defaults` and `surahLengths` are injectable so tests run against an isolated
/// suite with a small synthetic mushaf.
@Observable
final class QuranReadingProgress {
    /// surah number → furthest ayah reached in that surah.
    private var furthest: [Int: Int]
    /// Lifetime count of full reads of the Quran.
    private(set) var completedKhatmahs: Int
    /// Whether the *current* cycle has already been credited as complete, so each
    /// khatmah counts exactly once even as the final ayah is re-read.
    private var creditedComplete: Bool

    @ObservationIgnored private let defaults: UserDefaults
    /// surah number → its total ayah count, for clamping and the roll-up total.
    @ObservationIgnored private let surahLengths: [Int: Int]

    init(defaults: UserDefaults = .standard, surahLengths: [Int: Int]? = nil) {
        self.defaults = defaults
        self.surahLengths = surahLengths ?? Self.bundledLengths()
        furthest = Self.decode(defaults.data(forKey: Key.furthest))
        completedKhatmahs = defaults.integer(forKey: Key.khatmahs)
        creditedComplete = defaults.bool(forKey: Key.credited)
    }

    /// Surah lengths from the bundled mushaf (6236 ayahs across 114 surahs).
    private static func bundledLengths() -> [Int: Int] {
        var map: [Int: Int] = [:]
        for s in Quran.shared.surahs { map[s.number] = s.ayahs.count }
        return map
    }

    // MARK: Roll-ups

    var totalVerses: Int { surahLengths.values.reduce(0, +) }

    /// Total ayahs read across all surahs (each surah clamped to its length).
    var versesRead: Int {
        furthest.reduce(0) { sum, pair in
            let length = surahLengths[pair.key] ?? pair.value
            return sum + min(pair.value, length)
        }
    }

    /// Overall completion, 0...1.
    var overallProgress: Double {
        let total = totalVerses
        return total > 0 ? min(1, Double(versesRead) / Double(total)) : 0
    }

    var hasProgress: Bool { versesRead > 0 }

    // MARK: Per-surah

    func furthestAyah(surah: Int) -> Int { furthest[surah] ?? 0 }

    /// How far through a single surah you've read, 0...1.
    func progress(surah: Int) -> Double {
        guard let length = surahLengths[surah], length > 0 else { return 0 }
        return min(1, Double(min(furthest[surah] ?? 0, length)) / Double(length))
    }

    func isComplete(surah: Int) -> Bool {
        guard let length = surahLengths[surah], length > 0 else { return false }
        return (furthest[surah] ?? 0) >= length
    }

    // MARK: Recording

    /// Advance the furthest-read marker for a surah. Only ever moves forward; when
    /// the whole mushaf is finished it credits one khatmah (once per cycle).
    func recordRead(surah: Int, ayah: Int) {
        let clamped = surahLengths[surah].map { min(ayah, $0) } ?? ayah
        let existing = furthest[surah] ?? 0
        guard clamped > existing else { return }
        furthest[surah] = clamped
        if !creditedComplete, totalVerses > 0, versesRead >= totalVerses {
            completedKhatmahs += 1
            creditedComplete = true
        }
        persist()
    }

    /// Clear the current khatmah's progress to begin a new one. The lifetime
    /// completed-khatmah count is kept.
    func reset() {
        furthest = [:]
        creditedComplete = false
        persist()
    }

    // MARK: Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(furthest) {
            defaults.set(data, forKey: Key.furthest)
        }
        defaults.set(completedKhatmahs, forKey: Key.khatmahs)
        defaults.set(creditedComplete, forKey: Key.credited)
    }

    private static func decode(_ data: Data?) -> [Int: Int] {
        guard let data,
              let decoded = try? JSONDecoder().decode([Int: Int].self, from: data)
        else { return [:] }
        return decoded
    }

    private enum Key {
        static let furthest = "duhaa.quran.progress.furthest"
        static let khatmahs = "duhaa.quran.progress.khatmahs"
        static let credited = "duhaa.quran.progress.credited"
    }
}
