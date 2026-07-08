import Foundation
import Observation

/// Private, on-device reflections the reader can jot against a surah — a quiet
/// journaling space, never synced or shared. Persisted to UserDefaults.
///
/// `defaults` is injectable so tests run against an isolated suite.
@Observable
final class QuranNotes {
    /// surah number → the user's reflection text.
    private var notes: [Int: String]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notes = Self.decode(defaults.data(forKey: Key.notes))
    }

    func note(forSurah surah: Int) -> String { notes[surah] ?? "" }

    func hasNote(forSurah surah: Int) -> Bool {
        !(notes[surah]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Save (or, when blank, clear) the reflection for a surah.
    func setNote(_ text: String, forSurah surah: Int) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes[surah] = nil
        } else {
            notes[surah] = text
        }
        persist()
    }

    /// Surah numbers that currently hold a reflection, in order.
    var surahsWithNotes: [Int] { notes.keys.sorted() }

    // MARK: Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: Key.notes)
        }
    }

    private static func decode(_ data: Data?) -> [Int: String] {
        guard let data,
              let decoded = try? JSONDecoder().decode([Int: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private enum Key {
        static let notes = "duhaa.quran.reflections"
    }
}

/// A small rotating set of gentle, source-free journaling prompts. Picked by surah
/// number so each surah keeps a stable prompt. These are reflection cues only — no
/// religious ruling or claim is made.
enum ReflectionPrompt {
    static let all = [
        "What touched your heart in this surah?",
        "What will you carry from these verses today?",
        "Which verse do you want to remember?",
        "How does this surah meet you, right now?",
        "What is one thing you'll act on after reading this?",
        "What are you grateful for as you read this?"
    ]

    static func forSurah(_ surah: Int) -> String {
        all[abs(surah) % all.count]
    }
}
