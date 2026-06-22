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
                VStack(alignment: .leading, spacing: 18) {
                    ayahContext
                    Divider().overlay(Palette.cardBorder)
                    commentary
                    if !loading { credit }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
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
            VStack(alignment: .leading, spacing: 14) {
                if block.b > block.a {
                    Label("On verses \(block.a)–\(block.b)", systemImage: "text.justify.left")
                        .duhaaFont(12, .medium)
                        .foregroundStyle(Palette.blue.opacity(0.8))
                }
                ForEach(Array(paragraphs(block.t).enumerated()), id: \.offset) { _, para in
                    Text(para)
                        .duhaaFont(15)
                        .lineSpacing(4)
                        .foregroundStyle(.primary.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// Split the commentary into paragraphs on blank lines for comfortable reading.
    private func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
