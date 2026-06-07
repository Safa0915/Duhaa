import Foundation
import Observation

/// A bookmarked ayah.
struct BookmarkRef: Identifiable {
    let surah: Int
    let ayah: Int
    var id: String { "\(surah):\(ayah)" }
}

/// Persists bookmarked ayahs (UserDefaults). Shared via the environment.
@Observable
final class QuranBookmarks {
    private var keys: Set<String>
    @ObservationIgnored private let defaultsKey = "duha.quran.bookmarks"

    init() {
        keys = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }

    func isBookmarked(_ surah: Int, _ ayah: Int) -> Bool { keys.contains(key(surah, ayah)) }

    func toggle(_ surah: Int, _ ayah: Int) {
        let k = key(surah, ayah)
        if keys.contains(k) { keys.remove(k) } else { keys.insert(k) }
        UserDefaults.standard.set(Array(keys), forKey: defaultsKey)
    }

    /// All bookmarks, sorted by surah then ayah.
    var all: [BookmarkRef] {
        keys.compactMap { k -> BookmarkRef? in
            let parts = k.split(separator: ":")
            guard parts.count == 2, let s = Int(parts[0]), let a = Int(parts[1]) else { return nil }
            return BookmarkRef(surah: s, ayah: a)
        }
        .sorted { $0.surah != $1.surah ? $0.surah < $1.surah : $0.ayah < $1.ayah }
    }

    private func key(_ surah: Int, _ ayah: Int) -> String { "\(surah):\(ayah)" }
}
