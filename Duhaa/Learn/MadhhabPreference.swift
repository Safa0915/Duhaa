/// User-facing copy for madhhab-sensitive Learn content. Kept here so the wording
/// stays consistent and calm wherever it is shown.
enum MadhhabGuidance {
    /// Shown when Duhaa is teaching shared beginner-safe basics.
    static let sharedBasics =
        "Duhaa teaches the shared beginner-safe basics first. Some details differ between scholars and madhhabs. For specifics, follow a trusted scholar, local imam, or the madhhab you study with."

    /// Generic note for a madhhab-sensitive detail. Steps may override this with
    /// their own `madhhabNote`; this is the fallback.
    static let madhhabSensitive =
        "Scholars differ on some details here. Duhaa shows a beginner-safe summary. Follow the position you were taught by a trusted scholar or your madhhab."
}
