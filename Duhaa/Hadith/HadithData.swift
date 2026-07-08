import Foundation

/// One hadith in Duhaa's "Hadith of the Day" rotation — hope-framed and
/// motivational (the Ad-Duhaa spirit: mercy and encouragement, never guilt).
///
/// Per the project's religious-content rules every entry is source-backed and
/// carries an authenticity `grade` plus the `grader` whose grading it is. We show
/// the source + grade plainly and never label content "Verified". Only sahih /
/// hasan narrations are included; weak ones are omitted.
struct Hadith: Decodable, Identifiable, Sendable {
    let arabic: String
    let latin: String        // transliteration
    let en: String           // English translation — the motivational message
    let narrator: String     // e.g. "Abu Hurayrah (RA)"
    let source: String       // e.g. "Bukhari 6464 · Muslim 783"
    let grade: String        // e.g. "Sahih" / "Hasan"
    let grader: String       // whose grading — e.g. "al-Bukhari & Muslim", "al-Albani"
    let id = UUID()

    enum CodingKeys: String, CodingKey {
        case arabic, latin, en, narrator, source, grade, grader
    }

    /// Compact "grade · grader" line, so a grade is never shown without saying
    /// whose grading it is (matches the app's evidence convention).
    var gradeLine: String { "\(grade) · \(grader)" }
}

/// Loads `hadith_of_day.json` from the app bundle once and exposes today's pick.
/// App-target only: the widget reads a lightweight `HadithStamp` from the shared
/// snapshot (it never decodes this library), just like the Daily Du'a widget.
enum Hadiths {
    static let all: [Hadith] = load()

    static func loadAsync(priority: TaskPriority = .userInitiated) async -> [Hadith] {
        await Task.detached(priority: priority) { all }.value
    }

    /// Today's hadith as a stable daily rotation over the library, so the app and
    /// the widget agree on the same pick for a given day. `index` is the stable
    /// position used by the `duhaa://hadith` deep link / round-tripping.
    ///
    /// Uses day-of-year in `calendar` (mirrors how the Daily Du'a widget rotates),
    /// so the pick changes at local midnight.
    static func today(_ now: Date = Date(), calendar: Calendar = .current) -> (index: Int, hadith: Hadith)? {
        guard !all.isEmpty else { return nil }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let index = (dayOfYear - 1) % all.count
        return (index, all[index])
    }

    private struct File: Decodable { let hadiths: [Hadith] }
    /// Anchors the lookup to the app module's bundle (not Bundle.main) so unit
    /// tests resolve the same JSON the app ships.
    private final class BundleToken {}

    private static func load() -> [Hadith] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "hadith_of_day", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.hadiths
    }
}
