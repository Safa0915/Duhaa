import Foundation

enum GuideCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case purification
    case prayer
    case fasting
    case foundations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purification: "Purification"
        case .prayer: "Prayer"
        case .fasting: "Fasting"
        case .foundations: "Foundations"
        }
    }

    var icon: String {
        switch self {
        case .purification: "drop.fill"
        case .prayer: "figure.mind.and.body"
        case .fasting: "sun.haze.fill"
        case .foundations: "sparkles"
        }
    }
}

struct Guide: Decodable, Identifiable {
    let id: String
    let title: String
    let category: GuideCategory
    let summary: String
    let estimatedMinutes: Int
    let sortOrder: Int
    let steps: [GuideStep]

    var sortedSteps: [GuideStep] {
        steps
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, category, summary, estimatedMinutes, sortOrder, steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(GuideCategory.self, forKey: .category)
        summary = try container.decode(String.self, forKey: .summary)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        steps = try container.decode([GuideStep].self, forKey: .steps)
            .sorted { $0.order < $1.order }
    }
}

struct GuideStep: Decodable, Identifiable {
    let id: String
    let order: Int
    let title: String
    let body: String
    let arabicText: String?
    let transliteration: String?
    let translation: String?
    let dalilReferences: [DalilReference]
}

enum Learn {
    static let guides: [Guide] = load()
    static let guidesByCategory: [(category: GuideCategory, guides: [Guide])] = grouped(guides)

    static func guide(id: String) -> Guide? {
        guides.first { $0.id == id }
    }

    private struct File: Decodable { let guides: [Guide] }
    private final class BundleToken {}

    private static func load() -> [Guide] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "learn_guides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.guides.sorted { $0.sortOrder < $1.sortOrder }
    }

    private static func grouped(_ guides: [Guide]) -> [(category: GuideCategory, guides: [Guide])] {
        GuideCategory.allCases.compactMap { category in
            let matches = guides.filter { $0.category == category }
            return matches.isEmpty ? nil : (category, matches)
        }
    }
}
