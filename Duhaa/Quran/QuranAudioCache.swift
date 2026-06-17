import Foundation

enum QuranAudioCache {
    private static let budgetKey = "duhaa.quran.audioCacheBudgetMB"
    private static let folderName = "DuhaaQuranAudio"
    private static let maxFileBytes: Int64 = 25 * 1_024 * 1_024
    private static let allowedHosts: Set<String> = [
        "verses.quran.com",
        "download.quranicaudio.com"
    ]

    static func playableURL(for remoteURL: URL) async -> URL {
        await Task.detached(priority: .userInitiated) {
            guard budgetBytes > 0, isAllowedRemoteURL(remoteURL) else { return remoteURL }

            let localURL = cacheDirectory.appendingPathComponent(cacheName(for: remoteURL))
            if FileManager.default.fileExists(atPath: localURL.path) {
                touch(localURL)
                return localURL
            }

            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
                guard isValidDownload(response: response, temporaryURL: temporaryURL) else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    return remoteURL
                }
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try? FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: temporaryURL, to: localURL)
                trimToBudget()
                return localURL
            } catch {
                return remoteURL
            }
        }.value
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    static func isAllowedRemoteURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host(percentEncoded: false)?.lowercased(),
              allowedHosts.contains(host) else {
            return false
        }
        return url.pathExtension.lowercased() == "mp3"
    }

    private static func isValidDownload(response: URLResponse, temporaryURL: URL) -> Bool {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let responseURL = http.url,
              isAllowedRemoteURL(responseURL) else {
            return false
        }

        if let mimeType = http.mimeType?.lowercased(), !mimeType.contains("mpeg") && !mimeType.contains("mp3") {
            return false
        }
        if http.expectedContentLength > maxFileBytes {
            return false
        }
        guard let values = try? temporaryURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize,
              size > 0,
              Int64(size) <= maxFileBytes else {
            return false
        }
        return true
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
