import Foundation

/// Shared authenticity grades for religious evidence used by curated content.
/// Keep this small and explicit: Duhaa should show sources plainly, not as a
/// vague "verified" label that hides what was verified.
enum EvidenceGrade: String, Codable, CaseIterable, Hashable {
    case quranic
    case sahih
    case hasan
    case daif
    case mawdu

    var displayName: String {
        switch self {
        case .quranic: "Quran"
        case .sahih: "Sahih"
        case .hasan: "Hasan"
        case .daif: "Da'if"
        case .mawdu: "Mawdu'"
        }
    }
}

/// A source/grade pair attached to a guide step. `graderAttribution` is required
/// so the UI never shows a grade without telling the user whose grading it is.
struct DalilReference: Codable, Hashable, Identifiable {
    let sourceText: String
    let grade: EvidenceGrade
    let graderAttribution: String
    let note: String?

    var id: String {
        [sourceText, grade.rawValue, graderAttribution, note ?? ""]
            .joined(separator: "|")
    }
}
