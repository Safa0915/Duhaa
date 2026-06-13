import Foundation

enum QuranAudioCache {
    private static let budgetKey = "duhaa.quran.audioCacheBudgetMB"
    private static let folderName = "DuhaaQuranAudio"

    static func playableURL(for remoteURL: URL) async -> URL {
        guard budgetBytes > 0 else { return remoteURL }

        let localURL = cacheDirectory.appendingPathComponent(cacheName(for: remoteURL))
        if FileManager.default.fileExists(atPath: localURL.path) {
            touch(localURL)
            return localURL
        }

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let (temporaryURL, _) = try await URLSession.shared.download(from: remoteURL)
            if FileManager.default.fileExists(atPath: localURL.path) {
                try? FileManager.default.removeItem(at: localURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: localURL)
            trimToBudget()
            return localURL
        } catch {
            return remoteURL
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private static var budgetBytes: Int64 {
        let megabytes = UserDefaults.standard.integer(forKey: budgetKey)
        return Int64(max(0, megabytes)) * 1_024 * 1_024
    }

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func cacheName(for url: URL) -> String {
        let encoded = Data(url.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return "\(encoded).mp3"
    }

    private static func touch(_ url: URL) {
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    private static func trimToBudget() {
        let budget = budgetBytes
        guard budget > 0,
              let files = try? FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        var entries: [(url: URL, modified: Date, size: Int64)] = files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                return nil
            }
            return (url, values.contentModificationDate ?? .distantPast, Int64(values.fileSize ?? 0))
        }

        var total = entries.reduce(Int64(0)) { $0 + $1.size }
        entries.sort { $0.modified < $1.modified }

        for entry in entries where total > budget {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}
