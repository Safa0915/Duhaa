import Foundation

/// One question-and-answer in the Sisters' learning section.
struct SistersQA: Decodable, Identifiable {
    let q: String
    let a: String
    let source: String
    let id = UUID()
    enum CodingKeys: String, CodingKey { case q, a, source }
}

/// A topic (Wudu, Salah, Menstruation) with its Q&A.
struct SistersTopic: Decodable, Identifiable {
    let name: String
    let icon: String
    let items: [SistersQA]
    var id: String { name }
}

/// Loads `sisters_qa.json` once. Content is general fiqh guidance with sources.
/// ⚠️ Pre-launch: have a knowledgeable person review for accuracy.
enum SistersContent {
    static let disclaimer: String = file?.disclaimer ?? ""
    static let topics: [SistersTopic] = file?.categories ?? []

    private struct File: Decodable {
        let disclaimer: String
        let categories: [SistersTopic]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "sisters_qa", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()
}
