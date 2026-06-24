import SwiftUI

/// A sheet showing the tafsir (commentary) for one ayah. The edition is chosen from a
/// picker in the toolbar (Ibn Kathir today; the registry is ready for more). The
/// commentary is offline/bundled, so it reads with no connection.
struct TafsirView: View {
    let surah: Surah
    let ayah: Ayah

    @AppStorage("duhaa.quran.tafsir") private var editionID = Tafsir.defaultID
    @AppStorage("duhaa.quran.readerFont") private var readerFont = "kfgqpc"
    @Environment(\.dismiss) private var dismiss

    @State private var file: TafsirFile?
    @State private var loading = true

    private var edition: TafsirEdition { Tafsir.edition(editionID) }
    private var block: TafsirBlock? { file?.block(surah: surah.number, ayah: ayah.number) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ayahContext
                    Divider().overlay(Palette.cardBorder)
                    commentary
                    if !loading { credit }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .textSelection(.enabled)
            .navigationTitle("Tafsir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Palette.blue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    editionMenu
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .task(id: editionID) {
            loading = true
            file = await TafsirLoader.shared.load(edition)
            loading = false
        }
    }

    // The verse the commentary is about, for context at the top of the sheet.
    private var ayahContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(surah.englishName) · \(surah.number):\(ayah.number)")
                .duhaaFont(12, .semibold).tracking(1)
                .foregroundStyle(Palette.gold)
            Text(ayah.arabic)
                .font(QuranFont.reader(readerFont, size: 24))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .foregroundStyle(.primary)
            Text(ayah.english)
                .duhaaFont(14)
                .foregroundStyle(.primary.opacity(0.7))
        }
    }

    @ViewBuilder
    private var commentary: some View {
        if loading {
            HStack {
                Spacer()
                ProgressView().tint(Palette.gold)
                Spacer()
            }
            .padding(.vertical, 40)
        } else if let block, !block.t.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                if block.b > block.a {
                    Label("On verses \(block.a)–\(block.b)", systemImage: "text.justify.left")
                        .duhaaFont(12, .medium)
                        .foregroundStyle(Palette.blue.opacity(0.8))
                }
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(readingBlocks(block.t)) { block in
                        commentaryBlock(block)
                    }
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .duhaaFont(26)
                    .foregroundStyle(Palette.blue.opacity(0.5))
                Text("No tafsir available for this verse.")
                    .duhaaFont(14)
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    @ViewBuilder
    private func commentaryBlock(_ block: TafsirReadingBlock) -> some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .duhaaFont(18, .semibold)
                .lineSpacing(5)
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
        case .arabic:
            Text(block.text)
                .font(QuranFont.reader(readerFont, size: 23))
                .lineSpacing(10)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Palette.blue.opacity(0.96))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .background(Palette.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.blue.opacity(0.18), lineWidth: 1))
                .environment(\.layoutDirection, .rightToLeft)
        case .quote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Palette.gold.opacity(0.55))
                    .frame(width: 2)
                Text(block.text)
                    .duhaaFont(16)
                    .lineSpacing(7)
                    .foregroundStyle(.primary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Palette.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.gold.opacity(0.14), lineWidth: 1))
        case .body:
            Text(block.text)
                .duhaaFont(16)
                .lineSpacing(7)
                .foregroundStyle(.primary.opacity(0.90))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var credit: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tafsir: \(edition.name) — \(edition.author)")
                .duhaaFont(12, .medium)
                .foregroundStyle(Palette.blue.opacity(0.7))
            Text("An English rendering of the classical tafsir. Read for understanding; rulings and detail belong with qualified scholars.")
                .duhaaFont(11)
                .foregroundStyle(Palette.blue.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    /// A picker for the active tafsir. Shows even with one edition, so adding more
    /// later needs no UI change.
    private var editionMenu: some View {
        Menu {
            Picker("Tafsir", selection: $editionID) {
                ForEach(Tafsir.editions) { edition in
                    Text(edition.name).tag(edition.id)
                }
            }
        } label: {
            Image(systemName: "book")
                .foregroundStyle(Palette.gold)
        }
        .accessibilityLabel("Choose tafsir")
    }

    /// Split the commentary into display blocks while keeping the source text intact.
    private func readingBlocks(_ text: String) -> [TafsirReadingBlock] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { offset, paragraph in
                TafsirReadingBlock(id: offset, text: paragraph, kind: readingKind(for: paragraph))
            }
    }

    private func readingKind(for paragraph: String) -> TafsirReadingBlock.Kind {
        if isMostlyArabic(paragraph) {
            return .arabic
        }

        if isLikelyHeading(paragraph) {
            return .heading
        }

        if isTranslationQuote(paragraph) {
            return .quote
        }

        return .body
    }

    private func isLikelyHeading(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), trimmed.count <= 90 else { return false }
        if trimmed.contains(":") || trimmed.contains("\"") || trimmed.hasPrefix("(") { return false }
        return !trimmed.hasSuffix(".") && !trimmed.hasSuffix("?") && !trimmed.hasSuffix("!") && !trimmed.hasSuffix(")")
    }

    private func isTranslationQuote(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("(") && trimmed.hasSuffix(")")
    }

    private func isMostlyArabic(_ paragraph: String) -> Bool {
        let scalars = paragraph.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard scalars.count >= 6 else { return false }
        let arabicScalars = scalars.filter { scalar in
            (0x0600...0x06FF).contains(Int(scalar.value)) ||
            (0x0750...0x077F).contains(Int(scalar.value)) ||
            (0x08A0...0x08FF).contains(Int(scalar.value))
        }
        return Double(arabicScalars.count) / Double(scalars.count) > 0.45
    }

    private struct TafsirReadingBlock: Identifiable {
        enum Kind {
            case heading
            case arabic
            case quote
            case body
        }

        let id: Int
        let text: String
        let kind: Kind
    }
}
