import Foundation

/// One block of tafsir (commentary). Ibn Kathir groups several ayahs under one
/// block, so a block spans the inclusive ayah range `a...b` within surah `s`.
struct TafsirBlock: Decodable, Sendable {
    let s: Int
    let a: Int
    let b: Int
    let t: String
}

/// A whole bundled tafsir edition's data (decoded from e.g. `tafsir_ibnkathir.json`).
struct TafsirFile: Decodable, Sendable {
    let slug: String
    let name: String
    let author: String
    let source: String
    let blocks: [TafsirBlock]

    /// The block whose range covers this ayah, if any.
    func block(surah: Int, ayah: Int) -> TafsirBlock? {
        blocks.first { $0.s == surah && $0.a <= ayah && ayah <= $0.b }
    }
}

/// One tafsir the reader can choose between. `file` is the bundled JSON resource name.
/// The registry is picker-ready: add an edition (+ its bundled JSON) and it appears
/// automatically. As-Saadi isn't free in English yet — see docs/tafsir-setup.md.
struct TafsirEdition: Identifiable, Sendable {
    let id: String       // slug, also the @AppStorage value
    let name: String
    let author: String
    let file: String     // bundled resource name (no extension)
}

enum Tafsir {
    static let editions: [TafsirEdition] = [
        TafsirEdition(id: "en-tafisr-ibn-kathir",
                      name: "Ibn Kathir (Abridged)",
                      author: "Hafiz Ibn Kathir",
                      file: "tafsir_ibnkathir"),
    ]

    static let defaultID = editions[0].id

    static func edition(_ id: String) -> TafsirEdition {
        editions.first { $0.id == id } ?? editions[0]
    }
}

/// Loads (and caches) bundled tafsir JSON off the main thread — the files are large
/// (Ibn Kathir is ~11 MB), so decoding never blocks the reader. Anchored to the app
/// module bundle so unit tests resolve the same files the app ships.
actor TafsirLoader {
    static let shared = TafsirLoader()
    private var cache: [String: TafsirFile] = [:]

    func load(_ edition: TafsirEdition) async -> TafsirFile? {
        if let cached = cache[edition.id] { return cached }
        let file = decode(edition)
        if let file { cache[edition.id] = file }
        return file
    }

    private nonisolated func decode(_ edition: TafsirEdition) -> TafsirFile? {
        guard let url = Bundle(for: BundleToken.self).url(forResource: edition.file, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TafsirFile.self, from: data) else {
            return nil
        }
        return decoded
    }

    private final class BundleToken {}
}
