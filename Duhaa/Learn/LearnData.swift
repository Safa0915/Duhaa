import Foundation

/// Editorial category of a guide. Kept as-is for the detail-view icon/label;
/// navigation grouping now uses `GuideGroup` (see below).
enum GuideCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
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

/// Navigation grouping for the Learn list. Beginner-first: "Start Here" surfaces
/// the come-back / wudu / how-to-pray essentials before the deeper material.
/// Each guide belongs to exactly one group, so no card is shown twice.
enum GuideGroup: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case startHere
    case purification
    case prayerHelp
    case foundations

    var id: String { rawValue }

    /// Fixed order the sections appear in.
    var displayIndex: Int {
        switch self {
        case .startHere: 0
        case .purification: 1
        case .prayerHelp: 2
        case .foundations: 3
        }
    }

    var title: String {
        switch self {
        case .startHere: "Start Here"
        case .purification: "Purification"
        case .prayerHelp: "Prayer Help"
        case .foundations: "Foundations"
        }
    }

    var icon: String {
        switch self {
        case .startHere: "sparkles"
        case .purification: "drop.fill"
        case .prayerHelp: "figure.mind.and.body"
        case .foundations: "heart.fill"
        }
    }

    /// Fallback mapping when a guide's JSON omits `group`.
    static func fallback(for category: GuideCategory) -> GuideGroup {
        switch category {
        case .purification: .purification
        case .prayer: .prayerHelp
        case .fasting, .foundations: .foundations
        }
    }
}

/// Source-review state for a guide or step. **Never** add a `verified` case here
/// until a qualified scholar has signed off — that is a deliberate guardrail.
enum ReviewStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case sourceBacked = "source_backed"
    case reviewed
    case needsReview = "needs_review"

    var label: String {
        switch self {
        case .sourceBacked: "Source-backed"
        case .reviewed: "Reviewed"
        case .needsReview: "Needs review"
        }
    }
}

/// How madhhab-sensitive a guide or step is. Drives whether a gentle "scholars
/// differ" note should be shown instead of asserting a single ruling.
enum MadhhabSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
    case sharedBasic = "shared_basic"
    case madhhabSensitive = "madhhab_sensitive"
    case scholarDifference = "scholar_difference"
    case needsReview = "needs_review"

    /// `true` when a beginner-safe note about differences is warranted.
    var warrantsNote: Bool {
        switch self {
        case .sharedBasic: false
        case .madhhabSensitive, .scholarDifference, .needsReview: true
        }
    }
}

struct Guide: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let category: GuideCategory
    let group: GuideGroup
    let displayOrder: Int
    let priorityOrder: Int?
    let summary: String
    let estimatedMinutes: Int
    /// Legacy ordering field, retained for back-compat. New ordering = `displayOrder`.
    let sortOrder: Int
    let reviewStatus: ReviewStatus
    let madhhabSensitivity: MadhhabSensitivity
    let scholarReviewStatus: ReviewStatus
    let scholarSources: [String]?
    let steps: [GuideStep]

    var sortedSteps: [GuideStep] { steps }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, category, group, displayOrder, priorityOrder
        case summary, estimatedMinutes, sortOrder
        case reviewStatus, madhhabSensitivity, scholarReviewStatus, scholarSources
        case steps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        category = try c.decode(GuideCategory.self, forKey: .category)
        summary = try c.decode(String.self, forKey: .summary)
        estimatedMinutes = try c.decode(Int.self, forKey: .estimatedMinutes)
        let legacySort = try c.decode(Int.self, forKey: .sortOrder)
        sortOrder = legacySort
        // New ordering/grouping default safely from legacy fields if absent.
        displayOrder = try c.decodeIfPresent(Int.self, forKey: .displayOrder) ?? legacySort
        priorityOrder = try c.decodeIfPresent(Int.self, forKey: .priorityOrder)
        group = try c.decodeIfPresent(GuideGroup.self, forKey: .group)
            ?? GuideGroup.fallback(for: category)
        reviewStatus = try c.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus) ?? .sourceBacked
        madhhabSensitivity = try c.decodeIfPresent(MadhhabSensitivity.self, forKey: .madhhabSensitivity) ?? .sharedBasic
        scholarReviewStatus = try c.decodeIfPresent(ReviewStatus.self, forKey: .scholarReviewStatus) ?? .needsReview
        scholarSources = try c.decodeIfPresent([String].self, forKey: .scholarSources)
        steps = try c.decode([GuideStep].self, forKey: .steps)
            .sorted { $0.order < $1.order }
    }
}

struct GuideStep: Decodable, Identifiable, Sendable {
    let id: String
    let order: Int
    let title: String
    let body: String
    let arabicText: String?
    let transliteration: String?
    let translation: String?
    let reviewStatus: ReviewStatus
    let madhhabSensitivity: MadhhabSensitivity
    /// Gentle, beginner-safe note shown when a detail differs between schools.
    let madhhabNote: String?
    /// Internal pointer for the future scholar-check layer (not user-facing copy).
    let scholarNotes: String?
    /// Short source chip, e.g. "Bukhari 159 · Sahih". "Needs review" when unclear.
    let sourceSummary: String?
    let dalilReferences: [DalilReference]

    private enum CodingKeys: String, CodingKey {
        case id, order, title, body, arabicText, transliteration, translation
        case reviewStatus, madhhabSensitivity, madhhabNote, scholarNotes, sourceSummary
        case dalilReferences
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        arabicText = try c.decodeIfPresent(String.self, forKey: .arabicText)
        transliteration = try c.decodeIfPresent(String.self, forKey: .transliteration)
        translation = try c.decodeIfPresent(String.self, forKey: .translation)
        reviewStatus = try c.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus) ?? .sourceBacked
        madhhabSensitivity = try c.decodeIfPresent(MadhhabSensitivity.self, forKey: .madhhabSensitivity) ?? .sharedBasic
        madhhabNote = try c.decodeIfPresent(String.self, forKey: .madhhabNote)
        scholarNotes = try c.decodeIfPresent(String.self, forKey: .scholarNotes)
        sourceSummary = try c.decodeIfPresent(String.self, forKey: .sourceSummary)
        dalilReferences = try c.decode([DalilReference].self, forKey: .dalilReferences)
    }
}

enum Learn {
    static let guides: [Guide] = load()
    /// Beginner-first navigation grouping (Start Here → Purification → Prayer Help → Foundations).
    static let guidesByGroup: [(group: GuideGroup, guides: [Guide])] = grouped(guides)

    static func guide(id: String) -> Guide? {
        guides.first { $0.id == id }
    }

    static func loadAsync(priority: TaskPriority = .userInitiated) async -> [Guide] {
        await Task.detached(priority: priority) {
            guides
        }.value
    }

    static func grouped(_ guides: [Guide]) -> [(group: GuideGroup, guides: [Guide])] {
        GuideGroup.allCases
            .sorted { $0.displayIndex < $1.displayIndex }
            .compactMap { group in
                let matches = guides
                    .filter { $0.group == group }
                    .sorted { $0.displayOrder < $1.displayOrder }
                return matches.isEmpty ? nil : (group, matches)
            }
    }

    private struct File: Decodable { let guides: [Guide] }
    private final class BundleToken {}

    private static func load() -> [Guide] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "learn_guides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.guides.sorted { $0.displayOrder < $1.displayOrder }
    }

}
