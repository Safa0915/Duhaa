import Foundation

enum QuranArabicText {
    private static let hiddenDisplayScalars: Set<UnicodeScalar> = [
        UnicodeScalar(0x06DF)!, // ARABIC SMALL HIGH ROUNDED ZERO
        UnicodeScalar(0x06E0)!  // ARABIC SMALL HIGH UPRIGHT RECTANGULAR ZERO
    ]

    /// The bundled Uthmani data stays intact, but this font/iOS combination can
    /// render Quranic zero marks as large dotted-circle placeholders. Hide only
    /// those display marks so they do not look like fake ayah stops.
    static func display(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars where !hiddenDisplayScalars.contains(scalar) {
            scalars.append(scalar)
        }
        return String(scalars)
    }
}
