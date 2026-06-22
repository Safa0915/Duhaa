import Foundation
import Observation

/// Permanent, offline-first storage for **per-ayah** recitation. Unlike
/// `QuranAudioCache` (Caches dir — purgeable, budget-limited, fills as you
/// listen), files downloaded here live in Application Support and survive until
/// the user deletes them, so a downloaded surah plays with no network.
///
/// Path helpers are nonisolated/static so the audio resolver can do a fast,
/// synchronous "is this ayah already on disk?" check from its background task.
enum QuranOfflineStore {
    static let folderName = "DuhaaQuranOffline"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    static func ensureDirectory() {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Keep large recitation downloads out of iCloud backups.
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    static func fileName(for remoteURL: URL) -> String {
        let encoded = Data(remoteURL.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return "\(encoded).mp3"
    }

    static func localURL(for remoteURL: URL) -> URL {
        directory.appendingPathComponent(fileName(for: remoteURL))
    }

    /// The on-disk file for this remote URL, only if it has been downloaded.
    static func localURLIfDownloaded(for remoteURL: URL) -> URL? {
        let candidate = localURL(for: remoteURL)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    // MARK: Word-by-word traces (per surah, per reciter)

    /// One JSON file per downloaded surah, keyed `"<ayah>": QuranAyahTrace`, so the
    /// Listen player can show word-by-word Arabic + translation + sync offline.
    static func traceFileURL(reciterID: Int, surah: Int) -> URL {
        directory.appendingPathComponent("trace-\(reciterID)-\(surah).json")
    }

    static func savedTraces(reciterID: Int, surah: Int) -> [String: QuranAyahTrace]? {
        guard let data = try? Data(contentsOf: traceFileURL(reciterID: reciterID, surah: surah)) else { return nil }
        return try? JSONDecoder().decode([String: QuranAyahTrace].self, from: data)
    }

    static func saveTraces(_ traces: [String: QuranAyahTrace], reciterID: Int, surah: Int) {
        guard !traces.isEmpty else { return }
        ensureDirectory()
        guard let data = try? JSONEncoder().encode(traces) else { return }
        try? data.write(to: traceFileURL(reciterID: reciterID, surah: surah), options: .atomic)
    }

    static func removeTraces(reciterID: Int, surah: Int) {
        try? FileManager.default.removeItem(at: traceFileURL(reciterID: reciterID, surah: surah))
    }

    /// Download one ayah file into permanent storage (no-op if already present).
    nonisolated static func fetch(_ remoteURL: URL) async {
        let local = localURL(for: remoteURL)
        if FileManager.default.fileExists(atPath: local.path) { return }
        do {
            ensureDirectory()
            let (tmp, response) = try await URLSession.shared.download(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                try? FileManager.default.removeItem(at: tmp)
                return
            }
            if FileManager.default.fileExists(atPath: local.path) {
                try? FileManager.default.removeItem(at: local)
            }
            try FileManager.default.moveItem(at: tmp, to: local)
        } catch {
            // Best-effort: a failed ayah just stays un-downloaded and streams later.
        }
    }
}

/// Tracks which surahs are saved for offline listening (per reciter) and drives
/// the downloads. Per-ayah reciters only — full-surah reciters can't be tracked
/// ayah-by-ayah, so they aren't offered the offline option.
@MainActor
@Observable
final class QuranOfflineLibrary {
    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
    }

    private let defaults: UserDefaults
    private let downloadedKey = "duhaa.quran.offline.surahs"  // ["<reciterID>:<surah>"]
    private(set) var states: [String: DownloadState] = [:]
    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for key in defaults.stringArray(forKey: downloadedKey) ?? [] {
            states[key] = .downloaded
        }
        QuranOfflineStore.ensureDirectory()
    }

    private func key(surah: Int, reciterID: Int) -> String { "\(reciterID):\(surah)" }

    func state(surah: Int, reciterID: Int) -> DownloadState {
        states[key(surah: surah, reciterID: reciterID)] ?? .notDownloaded
    }

    func isDownloaded(surah: Int, reciterID: Int) -> Bool {
        state(surah: surah, reciterID: reciterID) == .downloaded
    }

    /// Save every ayah of `surah` in `reciter`'s voice for offline playback.
    func download(surah: Surah, reciter: Reciter) {
        guard reciter.supportsAyahAudio else { return }
        let k = key(surah: surah.number, reciterID: reciter.id)
        guard tasks[k] == nil, states[k] != .downloaded else { return }

        let ayahs = surah.ayahs
        let audioURLs = ayahs.compactMap { reciter.ayahURL(surah: surah.number, ayah: $0.number) }
        guard !audioURLs.isEmpty else { return }

        let reciterID = reciter.id
        let surahNumber = surah.number

        states[k] = .downloading(progress: 0)
        tasks[k] = Task { [weak self] in
            guard let self else { return }
            var traces: [String: QuranAyahTrace] = [:]
            var done = 0
            // Per ayah: fetch the audio AND the word-by-word trace (Arabic +
            // translation + timing) so the downloaded surah works offline.
            for chunk in ayahs.chunked(into: 4) {
                if Task.isCancelled { break }
                let fetched = await withTaskGroup(of: (Int, QuranAyahTrace).self) { group -> [(Int, QuranAyahTrace)] in
                    for ayah in chunk {
                        let audioURL = reciter.ayahURL(surah: surahNumber, ayah: ayah.number)
                        group.addTask {
                            if let audioURL { await QuranOfflineStore.fetch(audioURL) }
                            let trace = await QuranWordSegments.fetchTrace(reciterID: reciterID,
                                                                          surah: surahNumber, ayah: ayah.number)
                            return (ayah.number, trace)
                        }
                    }
                    var results: [(Int, QuranAyahTrace)] = []
                    for await result in group { results.append(result) }
                    return results
                }
                for (ayahNumber, trace) in fetched where !trace.isEmpty {
                    traces["\(ayahNumber)"] = trace
                }
                done += chunk.count
                self.states[k] = .downloading(progress: Double(done) / Double(ayahs.count))
            }
            if !Task.isCancelled {
                QuranOfflineStore.saveTraces(traces, reciterID: reciterID, surah: surahNumber)
            }
            self.tasks[k] = nil
            let complete = self.allFilesPresent(audioURLs)
            self.states[k] = complete ? .downloaded : .notDownloaded
            self.persist(k, downloaded: complete)
        }
    }

    /// Cancel an in-flight download and remove any saved files for this surah.
    func remove(surah: Surah, reciter: Reciter) {
        let k = key(surah: surah.number, reciterID: reciter.id)
        tasks[k]?.cancel()
        tasks[k] = nil
        for ayah in surah.ayahs {
            if let url = reciter.ayahURL(surah: surah.number, ayah: ayah.number) {
                try? FileManager.default.removeItem(at: QuranOfflineStore.localURL(for: url))
            }
        }
        QuranOfflineStore.removeTraces(reciterID: reciter.id, surah: surah.number)
        QuranWordSegments.forget(reciterID: reciter.id, surah: surah.number)
        states[k] = .notDownloaded
        persist(k, downloaded: false)
    }

    func toggle(surah: Surah, reciter: Reciter) {
        switch state(surah: surah.number, reciterID: reciter.id) {
        case .notDownloaded:           download(surah: surah, reciter: reciter)
        case .downloading, .downloaded: remove(surah: surah, reciter: reciter)
        }
    }

    /// Total bytes used by all offline recitation (for a Settings display).
    func totalBytes() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: QuranOfflineStore.directory,
            includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return 0 }
        return files.reduce(Int64(0)) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
    }

    func clearAll() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        try? FileManager.default.removeItem(at: QuranOfflineStore.directory)
        states.removeAll()
        defaults.removeObject(forKey: downloadedKey)
        QuranWordSegments.forgetAll()
        QuranOfflineStore.ensureDirectory()
    }

    private func allFilesPresent(_ urls: [URL]) -> Bool {
        urls.allSatisfy { FileManager.default.fileExists(atPath: QuranOfflineStore.localURL(for: $0).path) }
    }

    private func persist(_ key: String, downloaded: Bool) {
        var saved = Set(defaults.stringArray(forKey: downloadedKey) ?? [])
        if downloaded { saved.insert(key) } else { saved.remove(key) }
        defaults.set(Array(saved), forKey: downloadedKey)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
