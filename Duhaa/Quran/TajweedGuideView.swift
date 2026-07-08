import SwiftUI

/// One colour-coded rule of the Tajweed (QCF V4) mushaf font.
///
/// The hex values are the font's OWN palette entries (CPAL palette 0 = light
/// backgrounds, palette 1 = dark — the same indices the reader renders with),
/// so every swatch matches the page exactly. Rule names and the 8-rule set
/// follow Quran.com's legend for this same font.
struct TajweedRule: Identifiable, Sendable {
    let id: String
    let english: String
    let arabic: String
    let detail: String
    let lightHex: UInt32
    let darkHex: UInt32

    func color(isDark: Bool) -> Color {
        Color(hex: isDark ? darkHex : lightHex)
    }

    static let all: [TajweedRule] = [
        TajweedRule(
            id: "silent",
            english: "Silent letter",
            arabic: "الحرف الساكن",
            detail: "Greyed letters are written but not pronounced — the reading glides past them.",
            lightHex: 0xA5A5A5, darkHex: 0x999999
        ),
        TajweedRule(
            id: "madd-2",
            english: "Normal madd (2)",
            arabic: "مدّ حركتان",
            detail: "Stretch this sound for two counts.",
            lightHex: 0xCE9E00, darkHex: 0xFFC1E0
        ),
        TajweedRule(
            id: "madd-246",
            english: "Separated madd (2/4/6)",
            arabic: "المد المنفصل",
            detail: "The madd ends one word and a hamzah opens the next — stretch two, four or six counts.",
            lightHex: 0xFF7B00, darkHex: 0xFF8E3B
        ),
        TajweedRule(
            id: "madd-45",
            english: "Connected madd (4/5)",
            arabic: "المد المتصل",
            detail: "The madd and a hamzah meet inside one word — stretch four or five counts.",
            lightHex: 0xF40000, darkHex: 0xFF5E8E
        ),
        TajweedRule(
            id: "madd-6",
            english: "Necessary madd (6)",
            arabic: "المد اللازم",
            detail: "The longest stretch — hold for six counts.",
            lightHex: 0xB50000, darkHex: 0xE30000
        ),
        TajweedRule(
            id: "ghunnah",
            english: "Ghunnah / Ikhfāʾ",
            arabic: "غنة / إخفاء",
            detail: "A soft nasal hum, held for about two counts.",
            lightHex: 0x09B000, darkHex: 0x26B55D
        ),
        TajweedRule(
            id: "qalqalah",
            english: "Qalqalah (echo)",
            arabic: "قلقلة",
            detail: "A light bounce or echo on ق ط ب ج د when the letter carries a sukūn.",
            lightHex: 0x2FADFF, darkHex: 0x00DEFF
        ),
        TajweedRule(
            id: "tafkhim",
            english: "Tafkhīm (heavy)",
            arabic: "تفخيم الصوت",
            detail: "A heavy, full-mouthed sound.",
            lightHex: 0x3F48E6, darkHex: 0x3C84D5
        )
    ]
}

/// The "what do the colours mean" guide for the Tajweed mushaf — a small sheet
/// listing the eight rule colours. Styled with the reader's appearance (not the
/// app theme) so every swatch is shown against the background it renders on.
struct TajweedGuideView: View {
    let appearance: MushafAppearance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("In the Tajweed mushaf, every letter is coloured by the recitation rule it carries. These are the eight colours — the page itself teaches you as you read.")
                        .duhaaFont(14)
                        .foregroundStyle(appearance.secondaryText)
                        .lineSpacing(4)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(TajweedRule.all.enumerated()), id: \.element.id) { index, rule in
                            ruleRow(rule)
                            if index < TajweedRule.all.count - 1 {
                                Divider()
                                    .overlay(appearance.border)
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(appearance.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(appearance.border, lineWidth: 1)
                            )
                    )

                    Text("Colours are the tajweed font's own palette (QPC Tajweed Mushaf · Quran Foundation); rule names follow Quran.com's legend for the same font. This is a quick guide — a teacher's ear is the real judge.")
                        .duhaaFont(12)
                        .foregroundStyle(appearance.secondaryText)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .background(appearance.background.ignoresSafeArea())
            .navigationTitle("Tajweed Colours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(appearance.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(appearance.background)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    private func ruleRow(_ rule: TajweedRule) -> some View {
        let color = rule.color(isDark: appearance.isDark)

        return HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(appearance.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.english)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(appearance.text)
                Text(rule.detail)
                    .duhaaFont(12)
                    .foregroundStyle(appearance.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Text(rule.arabic)
                .font(QuranFont.uthmani(16))
                .foregroundStyle(color)
                .environment(\.layoutDirection, .rightToLeft)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rule.english), \(rule.arabic). \(rule.detail)")
    }
}
