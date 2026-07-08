import SwiftUI
import UIKit

enum MushafAppearance: String, CaseIterable, Identifiable {
    case duhaa
    case light
    case cream
    case sepia
    case dark
    case lightGray
    case warm

    static let displayCases: [MushafAppearance] = [.light, .cream, .sepia, .dark, .lightGray, .warm, .duhaa]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duhaa: return "Duhaa"
        case .light: return "Light"
        case .cream: return "Cream"
        case .sepia: return "Sepia"
        case .dark: return "Dark"
        case .lightGray: return "Light Gray"
        case .warm: return "Warm"
        }
    }

    var background: Color {
        switch self {
        case .duhaa: return Palette.appBg
        case .light: return Color(hex: 0xFBFAF6)
        case .cream: return Color(hex: 0xF5ECD7)
        case .sepia: return Color(hex: 0xE8D6B8)
        case .dark: return Color(hex: 0x171719)
        case .lightGray: return Color(hex: 0xF2F3F5)
        case .warm: return Color(hex: 0xEFE3D0)
        }
    }

    var isDark: Bool {
        switch self {
        case .duhaa: return Palette.active.isDark
        case .dark: return true
        case .light, .cream, .sepia, .lightGray, .warm: return false
        }
    }

    var preferredColorScheme: ColorScheme { isDark ? .dark : .light }

    var text: Color {
        switch self {
        case .duhaa: return Palette.primaryText
        case .dark: return Color.white.opacity(0.94)
        case .light, .cream, .sepia, .lightGray, .warm: return Color.black.opacity(0.92)
        }
    }

    var secondaryText: Color {
        switch self {
        case .duhaa: return Palette.secondaryText.opacity(isDark ? 0.78 : 0.72)
        case .dark: return Color.white.opacity(0.52)
        case .light, .cream, .sepia, .lightGray, .warm: return Color.black.opacity(0.48)
        }
    }

    var accent: Color {
        switch self {
        case .duhaa: return Palette.gold
        case .dark: return Color(hex: 0x8ECFE8)
        case .light, .cream, .sepia, .lightGray, .warm: return Color(hex: 0x6CA8E8)
        }
    }

    var controlFill: Color {
        switch self {
        case .duhaa: return Palette.gold
        case .dark: return Color(hex: 0x2A2A2D)
        case .light, .cream, .sepia, .lightGray, .warm: return Color(hex: 0x111113)
        }
    }

    var controlForeground: Color {
        switch self {
        case .duhaa: return Palette.onAccent
        case .dark, .light, .cream, .sepia, .lightGray, .warm: return Color.white.opacity(0.92)
        }
    }

    var card: Color {
        switch self {
        case .duhaa: return Palette.card
        case .dark: return Color.white.opacity(0.07)
        case .light, .cream, .sepia, .lightGray, .warm: return Color.black.opacity(0.045)
        }
    }

    var border: Color {
        switch self {
        case .duhaa: return Palette.cardBorder
        case .dark: return Color.white.opacity(0.13)
        case .light, .cream, .sepia, .lightGray, .warm: return Color.black.opacity(0.12)
        }
    }

    var controlShadow: Color {
        switch self {
        case .duhaa:
            return isDark ? Palette.glow.opacity(0.16) : Color.black.opacity(0.14)
        case .dark:
            return Color.black.opacity(0.28)
        case .light, .cream, .sepia, .lightGray, .warm:
            return Color.black.opacity(0.14)
        }
    }
}

/// Whether the reader's top controls are shown. Pages deep inside the
/// `UIPageViewController` toggle this on a plain tap; the reader observes it —
/// same ownership pattern as `MushafWordSelection`.
@MainActor
@Observable
final class MushafChromeVisibility {
    var isVisible = true

    func toggle() {
        isVisible.toggle()
    }
}

/// Full-page mushaf reader: one Madani page per screen, Quran.com page-line
/// layout when available, bundled Quran data as the offline fallback.
struct MushafReaderView: View {
    /// Page to open on (1...604) - usually the reader's current position.
    let startPage: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(QuranBookmarks.self) private var bookmarks
    @Environment(QuranReadingProgress.self) private var readingProgress
    @AppStorage("duhaa.quran.readerFont") private var readerFont = "kfgqpc"
    @AppStorage("duhaa.quran.mushafArabicSize") private var arabicSize = 26.0
    @AppStorage("duhaa.quran.mushafBackground") private var mushafBackground = MushafAppearance.duhaa.rawValue
    @AppStorage("duhaa.quran.mushafWordLookup") private var wordLookup = true
    @State private var page: Int
    @State private var showingSurahPicker = false
    @State private var showingMushafSettings = false
    @State private var showingTajweedGuide = false
    @State private var wordSelection = MushafWordSelection()
    @State private var chrome = MushafChromeVisibility()

    /// Small breathing room only — the controls are a tap-toggled overlay now, so
    /// the page text gets (almost) the full screen height, like a printed mushaf.
    private static let readerTopInset: CGFloat = 10

    init(startPage: Int) {
        self.startPage = startPage
        _page = State(initialValue: min(max(startPage, 1), max(Mushaf.pages.count, 1)))
    }

    private var appearance: MushafAppearance {
        MushafAppearance(rawValue: mushafBackground) ?? .duhaa
    }

    private var currentPage: MushafPage? {
        Mushaf.page(page)
    }

    private var currentSurahName: String {
        guard let surah = currentPage?.primarySurah,
              let name = Quran.surah(surah)?.englishName else { return "Mushaf" }
        return name
    }

    private var firstVisibleRef: QuranVerseRef? {
        currentPage?.firstAyahRef
    }

    private var isBookmarked: Bool {
        guard let ref = firstVisibleRef else { return false }
        return bookmarks.isBookmarked(ref.surah, ref.ayah)
    }

    var body: some View {
        let appearance = appearance
        @Bindable var wordSelection = wordSelection

        ZStack {
            appearance.background.ignoresSafeArea()

            MushafPageCurlPager(
                pages: Mushaf.pages,
                currentPage: $page,
                readerFont: readerFont,
                arabicSize: arabicSize,
                appearance: appearance,
                topContentInset: Self.readerTopInset,
                wordLookupEnabled: wordLookup,
                wordSelection: wordSelection,
                chrome: chrome
            )

            VStack(spacing: 0) {
                if chrome.isVisible {
                    topChrome
                        .transition(reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .zIndex(1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: chrome.isVisible)
        }
        .preferredColorScheme(appearance.preferredColorScheme)
        .tint(appearance.accent)
        .sheet(item: $wordSelection.word) { word in
            MushafWordMeaningCard(word: word, readerFont: readerFont, appearance: appearance)
                .presentationDetents([.height(300)])
                .presentationBackground(appearance.background)
                .presentationDragIndicator(.visible)
                .preferredColorScheme(appearance.preferredColorScheme)
        }
        .sheet(isPresented: $showingSurahPicker) {
            MushafSurahPickerView(currentSurah: currentPage?.primarySurah) { surah in
                page = Mushaf.pageNumber(surah: surah.number, ayah: 1)
            }
        }
        .sheet(isPresented: $showingMushafSettings) {
            MushafSettingsView(
                readerFont: $readerFont,
                mushafBackground: $mushafBackground,
                wordLookup: $wordLookup
            )
        }
        .sheet(isPresented: $showingTajweedGuide) {
            TajweedGuideView(appearance: appearance)
        }
        .onChange(of: page) {
            recordVisiblePage()
        }
        .onAppear {
            recordVisiblePage()
        }
    }

    /// Shared height for every top-bar control so the close/bookmark pill, the
    /// surah-title button and the settings button all sit on one aligned row.
    private static let topControlHeight: CGFloat = 46

    private var topChrome: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    leadingPill
                    Spacer()
                    settingsButton
                }

                surahPickerButton
                    .padding(.horizontal, 108)
            }
            .frame(height: Self.topControlHeight)

            // Reading colour-coded tajweed without knowing the colours teaches
            // nothing — surface the legend right where the colours are seen.
            if readerFont == QuranFontPreference.tajweedV4.rawValue {
                tajweedGuideChip
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        // The controls float over the page text now, so fade the page background in
        // behind them — solid at the top, dissolving just below the controls.
        .background(alignment: .top) {
            LinearGradient(
                colors: [
                    appearance.background,
                    appearance.background.opacity(0.94),
                    appearance.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -34)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    private var tajweedGuideChip: some View {
        Button {
            showingTajweedGuide = true
            DuhaaHaptics.tap()
        } label: {
            Label("Tajweed colours", systemImage: "paintpalette.fill")
                .duhaaFont(13, .semibold)
                .foregroundStyle(appearance.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(appearance.card))
                .overlay(Capsule().stroke(appearance.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tajweed colour guide")
    }

    /// The "where am I" line under the surah title — juz, page and first verse on
    /// the page, mirroring the footer's page-numbering convention (Al-Fātiḥah is
    /// the unnumbered opening).
    private var pageIndicatorText: String {
        guard let current = currentPage else { return "" }
        var parts = ["Juz \(current.juzNumber)"]
        parts.append(current.page <= 1 ? "The Opening" : "Page \(current.page - 1)")
        if let ref = firstVisibleRef {
            parts.append("Verse \(ref.ayah)")
        }
        return parts.joined(separator: " · ")
    }

    private var leadingPill: some View {
        HStack(spacing: 6) {
            Button {
                dismiss()
                DuhaaHaptics.tap()
            } label: {
                Image(systemName: "xmark")
                    .duhaaFont(17, .bold)
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("Close mushaf")

            Button {
                toggleCurrentPageBookmark()
                DuhaaHaptics.tap()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .duhaaFont(18, .semibold)
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel(isBookmarked ? "Remove page bookmark" : "Bookmark this page")
        }
        .foregroundStyle(appearance.controlForeground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(appearance.controlFill))
        .shadow(color: appearance.controlShadow, radius: 18, y: 8)
    }

    private var surahPickerButton: some View {
        Button {
            showingSurahPicker = true
            DuhaaHaptics.tap()
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(currentSurahName)
                        .duhaaFont(17, .bold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.78)
                        .layoutPriority(1)
                    Image(systemName: "chevron.down")
                        .duhaaFont(12, .bold)
                        .foregroundStyle(appearance.secondaryText)
                }
                .foregroundStyle(appearance.text)

                Text(pageIndicatorText)
                    .duhaaFont(11, .semibold)
                    .monospacedDigit()
                    .foregroundStyle(appearance.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // Fill the whole middle of the top bar and make every point of it
            // tappable — without contentShape only the text + chevron register
            // taps, so taps in the surrounding space were being missed.
            .frame(maxWidth: .infinity, minHeight: Self.topControlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Surah \(currentSurahName), \(pageIndicatorText)")
    }

    private var settingsButton: some View {
        Button {
            showingMushafSettings = true
            DuhaaHaptics.tap()
        } label: {
            Image(systemName: "ellipsis")
                .duhaaFont(18, .heavy)
                .foregroundStyle(appearance.controlForeground)
                .frame(width: Self.topControlHeight, height: Self.topControlHeight)
                .background(Circle().fill(appearance.controlFill))
                .shadow(color: appearance.controlShadow, radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mushaf settings")
    }

    private func toggleCurrentPageBookmark() {
        guard let ref = firstVisibleRef else { return }
        bookmarks.toggle(ref.surah, ref.ayah)
    }

    private func recordVisiblePage() {
        guard let ref = currentPage?.lastAyahRef else { return }
        bookmarks.recordRead(surah: ref.surah, ayah: ref.ayah)
        readingProgress.recordRead(surah: ref.surah, ayah: ref.ayah)
    }
}

private struct MushafPageCurlPager: UIViewControllerRepresentable {
    let pages: [MushafPage]
    @Binding var currentPage: Int
    let readerFont: String
    let arabicSize: Double
    let appearance: MushafAppearance
    let topContentInset: CGFloat
    let wordLookupEnabled: Bool
    let wordSelection: MushafWordSelection
    let chrome: MushafChromeVisibility

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue]
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        // Opaque so the curl never reveals a see-through gap behind the page.
        controller.view.backgroundColor = UIColor(appearance.background)
        controller.isDoubleSided = false

        // Turn pages by swiping the curl — disable the built-in tap-to-turn so a
        // plain tap reliably shows/hides the reader controls instead of flipping
        // the page.
        for recognizer in controller.gestureRecognizers {
            if let tap = recognizer as? UITapGestureRecognizer {
                tap.isEnabled = false
            }
        }

        if let opening = context.coordinator.controller(for: currentPage) {
            controller.setViewControllers([opening], direction: .forward, animated: false)
        }

        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.update(parent: self)
        controller.view.backgroundColor = UIColor(appearance.background)

        let visible = controller.viewControllers?.first as? MushafPageHostingController
        guard let desired = context.coordinator.controller(for: currentPage) else { return }

        // Replace when the page changed OR when the cached page was rebuilt after a
        // font / size change (the visible instance is no longer the cached one).
        guard visible !== desired else { return }

        let samePage = visible?.pageNumber == currentPage
        let direction = visible.map { context.coordinator.direction(from: $0.pageNumber, to: currentPage) } ?? .forward
        controller.setViewControllers([desired], direction: direction, animated: !samePage)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        private var parent: MushafPageCurlPager
        private var cachedReaderFont: String
        private var cachedArabicSize: Double
        private var cachedAppearance: MushafAppearance
        private var cachedTopContentInset: CGFloat
        private var cachedWordLookupEnabled: Bool
        private var cache: [Int: MushafPageHostingController] = [:]

        init(parent: MushafPageCurlPager) {
            self.parent = parent
            cachedReaderFont = parent.readerFont
            cachedArabicSize = parent.arabicSize
            cachedAppearance = parent.appearance
            cachedTopContentInset = parent.topContentInset
            cachedWordLookupEnabled = parent.wordLookupEnabled
        }

        func update(parent: MushafPageCurlPager) {
            self.parent = parent
            // Rebuild cached pages when visual settings change.
            if cachedReaderFont != parent.readerFont ||
                cachedArabicSize != parent.arabicSize ||
                cachedAppearance != parent.appearance ||
                cachedTopContentInset != parent.topContentInset ||
                cachedWordLookupEnabled != parent.wordLookupEnabled {
                cache.removeAll()
                cachedReaderFont = parent.readerFont
                cachedArabicSize = parent.arabicSize
                cachedAppearance = parent.appearance
                cachedTopContentInset = parent.topContentInset
                cachedWordLookupEnabled = parent.wordLookupEnabled
            }
        }

        func controller(for page: Int) -> MushafPageHostingController? {
            // Out of range (before Al-Fatiha / past the last page) returns nil so the
            // page-curl can't swipe beyond the mushaf at either end.
            guard page >= 1, page <= parent.pages.count else { return nil }
            if let cached = cache[page] { return cached }

            let host = MushafPageHostingController(
                page: parent.pages[page - 1],
                readerFont: parent.readerFont,
                arabicSize: parent.arabicSize,
                appearance: parent.appearance,
                topContentInset: parent.topContentInset,
                wordLookupEnabled: parent.wordLookupEnabled,
                wordSelection: parent.wordSelection,
                chrome: parent.chrome
            )
            cache[page] = host
            return host
        }

        func direction(from oldPage: Int, to newPage: Int) -> UIPageViewController.NavigationDirection {
            // Quran pages advance right-to-left, so moving to a higher page uses
            // the visual reverse direction of a left-to-right book.
            newPage > oldPage ? .reverse : .forward
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? MushafPageHostingController else { return nil }
            return controller(for: host.pageNumber + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? MushafPageHostingController else { return nil }
            return controller(for: host.pageNumber - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let host = pageViewController.viewControllers?.first as? MushafPageHostingController else { return }
            parent.currentPage = host.pageNumber
            DuhaaHaptics.tap()
        }
    }
}

private final class MushafPageHostingController: UIHostingController<MushafPageView> {
    let pageNumber: Int

    init(page: MushafPage, readerFont: String, arabicSize: Double, appearance: MushafAppearance, topContentInset: CGFloat, wordLookupEnabled: Bool, wordSelection: MushafWordSelection, chrome: MushafChromeVisibility) {
        pageNumber = page.page
        super.init(rootView: MushafPageView(
            page: page,
            readerFont: readerFont,
            arabicSize: arabicSize,
            appearance: appearance,
            topContentInset: topContentInset,
            wordLookupEnabled: wordLookupEnabled,
            wordSelection: wordSelection,
            chrome: chrome
        ))
        // Opaque page background — keeps the page-curl turning a solid sheet instead
        // of letting the next page show through (the "glass" look).
        view.backgroundColor = UIColor(appearance.background)
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("MushafPageHostingController is created in code.")
    }
}

private struct MushafPageView: View {
    let page: MushafPage
    let readerFont: String
    /// User-chosen base Arabic size, applied uniformly to every page.
    let arabicSize: Double
    let appearance: MushafAppearance
    let topContentInset: CGFloat
    let wordLookupEnabled: Bool
    let wordSelection: MushafWordSelection
    let chrome: MushafChromeVisibility

    @State private var quranComPage: QuranComMushafPage?
    @State private var loadFailed = false
    @State private var pageFontName: String?
    @State private var pageFontFailed = false

    private enum PageSlotKind {
        case text(QuranComMushafLine)
        case surahHeader(name: String)
        case bismillah
        case empty
    }

    private struct PageSlot: Identifiable {
        let number: Int
        let kind: PageSlotKind

        var id: Int { number }
        var isEmpty: Bool {
            if case .empty = kind { return true }
            return false
        }
    }

    private var juzNumber: Int {
        quranComPage?.juzNumber ?? page.juzNumber
    }

    private var requestedFont: QuranFontPreference {
        QuranFontPreference(storageValue: readerFont)
    }

    private var renderFont: QuranFontPreference {
        requestedFont.isPageFont && pageFontName == nil ? requestedFont.fallbackUnicodePreference : requestedFont
    }

    private var activeFontName: String {
        pageFontName ?? renderFont.unicodeFontName ?? QuranFont.family
    }

    /// Quran iOS treats Arabic mushaf pages as a fixed 15-line canvas. Quran.com
    /// exposes the same line numbers; surah starts occupy the empty line(s)
    /// immediately before their first text line.
    private var pageSlots: [PageSlot]? {
        guard let quranComPage else { return nil }

        var slotKinds = Dictionary(uniqueKeysWithValues: quranComPage.lines.map {
            ($0.number, PageSlotKind.text($0))
        })

        for segment in page.segments {
            guard case .surahHeader(let surah, let arabicName, _, let showsBismillah) = segment,
                  let firstTextLine = quranComPage.firstLineNumber(forSurah: surah) else {
                continue
            }

            let reservedLines = showsBismillah ? 2 : 1
            let headerLine = max(1, min(15, firstTextLine - reservedLines))
            slotKinds[headerLine] = .surahHeader(name: arabicName)

            if showsBismillah, headerLine + 1 <= 15 {
                slotKinds[headerLine + 1] = .bismillah
            }
        }

        return (1...15).map { PageSlot(number: $0, kind: slotKinds[$0] ?? .empty) }
    }

    /// Page-font (QCF) sizing: one size per page, chosen so the WIDEST line exactly
    /// FILLS the page width. QCF pages are typeset per page, so their lines are
    /// near-uniform and this lands on (almost) the same size for every page.
    /// `maxSize` (from the line height) keeps tall diacritics from overlapping rows.
    private static func uniformLineSize(slots: [PageSlot], fontName: String, baseSize: CGFloat, width: CGFloat, maxSize: CGFloat) -> CGFloat {
        guard width > 0 else { return baseSize }
        var widest: CGFloat = 0
        for slot in slots {
            if case .text(let line) = slot.kind {
                widest = max(widest, MushafLineUIView.naturalWidth(text: line.text, fontName: fontName, size: baseSize))
            }
        }
        guard widest > 0 else { return baseSize }
        let fillSize = baseSize * width / widest
        return min(max(fillSize, baseSize * 0.4), maxSize)
    }

    /// Unicode-font sizing: ONE lettering size for the ENTIRE mushaf — a dense page
    /// must never render smaller than a sparse one (dev ask 2026-07-04). The factor
    /// 0.050 × width is the median full-line fill size, measured with CoreText over
    /// real QPC-HAFS and Indo-Pak line data across the mushaf. Denser lines close
    /// their word gaps (and condense slightly at the extreme) in `MushafLineUIView`;
    /// sparser lines justify wider — the size itself never changes. Dynamic Type is
    /// divided back out because this fixed 15-line canvas cannot reflow, exactly
    /// like the printed page.
    private static func fixedUniformSize(width: CGFloat, lineHeight: CGFloat) -> CGFloat {
        let target = min(lineHeight * 0.72, width * 0.050)
        let dynamicTypeScale = UIFontMetrics(forTextStyle: .body).scaledValue(for: 100) / 100
        return max(12, target / max(dynamicTypeScale, 0.1))
    }

    var body: some View {
        GeometryReader { proxy in
            pageContent(size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque so the page-curl turns a solid sheet (no bleed-through "glass").
        .background(appearance.background)
        .contentShape(Rectangle())
        // A plain tap anywhere on the page shows/hides the reader controls —
        // looking a word up is touch-and-hold, so the two never collide.
        .onTapGesture {
            chrome.toggle()
            DuhaaHaptics.tap()
        }
        .task(id: "\(page.page)-\(readerFont)") {
            await loadPageResources()
        }
    }

    private func pageContent(size: CGSize) -> some View {
        // Slim print-like margins — the lettering runs almost edge to edge.
        let horizontalPadding: CGFloat = 12
        let topPadding: CGFloat = topContentInset
        let bottomPadding: CGFloat = 12
        let footerHeight: CGFloat = 28
        let availableHeight = max(size.height - topPadding - bottomPadding - footerHeight, 1)
        let lineHeight = availableHeight / 15
        let effectiveArabicSize = fittedArabicSize(lineHeight: lineHeight, width: size.width - horizontalPadding * 2)

        return VStack(spacing: 0) {
            Spacer(minLength: topPadding)

            if let pageSlots {
                // One size shared by every line. Page fonts fit themselves per page;
                // Unicode fonts use one FIXED size for the whole mushaf, so no page
                // ever renders smaller than another.
                let lineWidth = size.width - horizontalPadding * 2 - 6
                let uniformSize = renderFont.isPageFont
                    ? Self.uniformLineSize(
                        slots: pageSlots, fontName: activeFontName,
                        baseSize: effectiveArabicSize, width: lineWidth,
                        maxSize: max(18, lineHeight * 0.72))
                    : Self.fixedUniformSize(width: lineWidth, lineHeight: lineHeight)

                if isOpeningPage {
                    // Al-Fātiḥah and the opening of Al-Baqarah are short, special
                    // "framed" pages — centre them on the page, not justified.
                    centeredOpeningContent(slots: pageSlots, lineHeight: lineHeight,
                                           arabicSize: uniformSize)
                } else {
                    mushafCanvas(slots: pageSlots, lineHeight: lineHeight, arabicSize: uniformSize)
                }
            } else if loadFailed {
                fallbackPageContent(height: availableHeight, arabicSize: effectiveArabicSize)
            } else {
                loadingCanvas(lineHeight: lineHeight)
            }

            Spacer(minLength: 4)

            footer
                .frame(height: footerHeight)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mushafCanvas(slots: [PageSlot], lineHeight: CGFloat, arabicSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(slots) { slot in
                slotView(slot, lineHeight: lineHeight, arabicSize: arabicSize)
                    .frame(maxWidth: .infinity)
                    .frame(height: lineHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: lineHeight * 15)
        .padding(.horizontal, 2)
    }

    /// The mushaf's two opening pages — Al-Fātiḥah (page 1) and the start of
    /// Al-Baqarah (page 2) — are short framed pages. Centre their lines on the page
    /// (vertically and horizontally) rather than spreading them over 15 justified rows.
    private var isOpeningPage: Bool { page.page <= 2 }

    private func centeredOpeningContent(slots: [PageSlot], lineHeight: CGFloat, arabicSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(slots.filter { !$0.isEmpty }) { slot in
                slotView(slot, lineHeight: lineHeight, arabicSize: arabicSize, justify: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: lineHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func slotView(_ slot: PageSlot, lineHeight: CGFloat, arabicSize: CGFloat, justify: Bool = true) -> some View {
        switch slot.kind {
        case .text(let line):
            quranLine(line, arabicSize: arabicSize, justify: justify)
        case .surahHeader(let name):
            surahBanner(name, height: lineHeight * 0.84, arabicSize: arabicSize)
        case .bismillah:
            arabicDisplayText(QuranFont.bismillah(for: renderFont.rawValue))
                .font(QuranFont.reader(renderFont.fallbackUnicodePreference.rawValue, size: arabicSize * 0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .environment(\.layoutDirection, .rightToLeft)
                .accessibilityLabel(Quran.shared.bismillah.arabic)
        case .empty:
            Color.clear
        }
    }

    @ViewBuilder
    private func quranLine(_ line: QuranComMushafLine, arabicSize: CGFloat, justify: Bool = true) -> some View {
        if !line.words.isEmpty {
            // Touch and hold any word to look up its meaning + hear it, while the line
            // stays a single shaped run so the authentic page layout is preserved.
            MushafTappableLineView(
                words: line.words,
                fontName: activeFontName,
                baseSize: arabicSize,
                textColor: UIColor(appearance.text),
                justify: justify,
                isWordLookupEnabled: wordLookupEnabled && line.words.contains(where: { $0.isWord }),
                onSelectWord: { word in
                    wordSelection.word = word
                    DuhaaHaptics.tap()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(line.accessibilityText)
        } else {
            arabicDisplayText(line.text)
                .font(QuranFont.reader(renderFont.rawValue, size: arabicSize, pageFontName: pageFontName))
                .lineLimit(1)
                .minimumScaleFactor(0.52)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .environment(\.layoutDirection, .rightToLeft)
                .accessibilityLabel(line.accessibilityText)
        }
    }

    private func loadingCanvas(lineHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(1...15, id: \.self) { line in
                RoundedRectangle(cornerRadius: 3)
                    .fill(appearance.card.opacity(line.isMultiple(of: 4) ? 0.90 : 0.60))
                    .frame(width: line.isMultiple(of: 3) ? 170 : 245, height: 2)
                    .frame(maxWidth: .infinity)
                    .frame(height: lineHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: lineHeight * 15)
    }

    private func fallbackPageContent(height: CGFloat, arabicSize: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            fallbackContent(arabicSize: arabicSize)
                .frame(maxWidth: .infinity)
                .frame(height: height)
            ScrollView(.vertical, showsIndicators: false) {
                fallbackContent(arabicSize: arabicSize)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func fallbackContent(arabicSize: CGFloat) -> some View {
        VStack(spacing: arabicSize * 0.42) {
            ForEach(page.segments) { segment in
                switch segment {
                case .surahHeader(_, let arabicName, _, let showsBismillah):
                    surahBanner(arabicName, height: arabicSize * 1.75, arabicSize: arabicSize)
                    if showsBismillah {
                        arabicDisplayText(Quran.shared.bismillah.arabic)
                            .font(QuranFont.reader(renderFont.fallbackUnicodePreference.rawValue, size: arabicSize * 0.8))
                            .multilineTextAlignment(.center)
                            .environment(\.layoutDirection, .rightToLeft)
                            .accessibilityLabel(Quran.shared.bismillah.arabic)
                    }
                case .ayahRun(_, let ayahs):
                    fallbackRun(ayahs, arabicSize: arabicSize)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func surahBanner(_ arabicName: String, height: CGFloat, arabicSize: CGFloat) -> some View {
        let clampedHeight = max(24, min(height, 48))
        let cornerRadius = min(10, clampedHeight * 0.24)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.card.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(appearance.accent.opacity(0.78), lineWidth: 1.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius - 3)
                        .stroke(appearance.accent.opacity(0.24), lineWidth: 0.8)
                        .padding(4)
                )

            HStack {
                sideOrnament(height: clampedHeight)
                Spacer(minLength: 18)
                sideOrnament(height: clampedHeight)
            }
            .padding(.horizontal, 16)

            Text(arabicName)
                .font(QuranFont.uthmani(min(arabicSize * 0.88, clampedHeight * 0.46)))
                .foregroundStyle(appearance.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 24)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(appearance.background)
                        .overlay(Capsule().stroke(appearance.accent.opacity(0.42), lineWidth: 0.9))
                )
                .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(height: clampedHeight)
        .accessibilityLabel(arabicName)
    }

    private func sideOrnament(height: CGFloat) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(appearance.accent.opacity(0.34))
                .frame(width: max(18, height * 0.56), height: 1)
            Circle()
                .stroke(appearance.accent.opacity(0.72), lineWidth: 1)
                .frame(width: height * 0.32, height: height * 0.32)
            Capsule()
                .fill(appearance.accent.opacity(0.34))
                .frame(width: max(18, height * 0.56), height: 1)
        }
    }

    /// Offline fallback (no Quran.com page): the bundled Uthmani text as one
    /// justified block, with a single bracketed ayah number per verse.
    private func fallbackRun(_ ayahs: [Ayah], arabicSize: CGFloat) -> some View {
        let easternDigits = renderFont.usesEasternArabicDigits
        let joined = ayahs
            .map { "\(QuranArabicText.display($0.arabic)) \(MushafPage.verseMarker($0.number, easternDigits: easternDigits))" }
            .joined(separator: " ")

        return arabicDisplayText(joined)
            .font(QuranFont.reader(renderFont.fallbackUnicodePreference.rawValue, size: arabicSize))
            .lineSpacing(arabicSize * 0.4)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel(ayahs.map(\.arabic).joined(separator: " "))
    }

    private func fittedArabicSize(lineHeight: CGFloat, width: CGFloat) -> CGFloat {
        let heightFit = max(18, lineHeight * 0.72)
        let widthFit = max(20, width * 0.08)
        return min(CGFloat(arabicSize), heightFit, widthFit)
    }

    private var footer: some View {
        Text(footerText)
            .duhaaFont(15, .bold)
            .monospacedDigit()
            .foregroundStyle(appearance.secondaryText)
            .accessibilityLabel(footerAccessibilityLabel)
    }

    /// Al-Fātiḥah (real page 1) is the opening and isn't counted; Al-Baqarah's first
    /// page reads as "page 1", so every numbered page is the real mushaf page minus one.
    private var footerText: String {
        if page.page <= 1 {
            return "juz \(juzNumber)  ·  the opening"
        }
        return "juz \(juzNumber)  ·  page  \(page.page - 1)"
    }

    private var footerAccessibilityLabel: String {
        if page.page <= 1 {
            return "Juz \(juzNumber), the opening"
        }
        return "Juz \(juzNumber), page \(page.page - 1)"
    }

    private func arabicDisplayText(_ raw: String) -> Text {
        let display = QuranArabicText.display(raw)
        return Text(display).foregroundColor(appearance.text)
    }

    @MainActor
    private func loadPageResources() async {
        quranComPage = nil
        loadFailed = false
        pageFontName = nil
        pageFontFailed = false

        let selectedFont = requestedFont
        var dataFont = selectedFont

        if selectedFont.isPageFont {
            let palette = selectedFont.colorPaletteIndex(isDark: appearance.isDark)
            if let loaded = await QuranPageFontLoader.shared.fontName(forPage: page.page,
                                                                      preference: selectedFont,
                                                                      palette: palette) {
                pageFontName = loaded
            } else {
                pageFontFailed = true
                dataFont = selectedFont.fallbackUnicodePreference
            }
        }

        do {
            quranComPage = try await QuranComMushafPageAPI.shared.page(page.page, preference: dataFont)
        } catch {
            loadFailed = true
        }
    }
}

private struct MushafSurahPickerView: View {
    let currentSurah: Int?
    let onSelect: (Surah) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredSurahs: [Surah] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Quran.shared.surahs }

        return Quran.shared.surahs.filter { surah in
            "\(surah.number)".contains(query) ||
                surah.englishName.localizedCaseInsensitiveContains(query) ||
                surah.translation.localizedCaseInsensitiveContains(query) ||
                surah.arabicName.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredSurahs) { surah in
                Button {
                    onSelect(surah)
                    DuhaaHaptics.tap()
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text("\(surah.number)")
                            .duhaaFont(13, .bold)
                            .monospacedDigit()
                            .foregroundStyle(Palette.gold)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Palette.gold.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(surah.englishName)
                                .duhaaFont(16, .semibold)
                                .foregroundStyle(.primary)
                            Text("\(surah.translation) · page \(Mushaf.pageNumber(surah: surah.number, ayah: 1))")
                                .duhaaFont(12)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(surah.arabicName)
                            .font(QuranFont.uthmani(20))
                            .foregroundStyle(.secondary)
                            .environment(\.layoutDirection, .rightToLeft)

                        if currentSurah == surah.number {
                            Image(systemName: "checkmark")
                                .duhaaFont(15, .bold)
                                .foregroundStyle(Palette.gold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search surahs")
            .navigationTitle("Surahs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.appBg)
        .preferredColorScheme(Palette.active.colorScheme)
    }
}

private struct MushafSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var readerFont: String
    @Binding var mushafBackground: String
    @Binding var wordLookup: Bool
    @State private var showingTajweedGuide = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    settingsSection(title: "Reader") {
                        VStack(spacing: 0) {
                            let fonts = QuranFontPreference.allCases
                            ForEach(Array(fonts.enumerated()), id: \.element.id) { index, font in
                                readerRow(
                                    title: font.title,
                                    subtitle: font.subtitle,
                                    selected: readerFont == font.rawValue
                                ) {
                                    readerFont = font.rawValue
                                    DuhaaHaptics.tap()
                                }

                                if index < fonts.count - 1 {
                                    divider
                                }
                            }

                            // The colour-coded font is only useful if the reader
                            // knows the colours — offer the legend at the moment
                            // Tajweed V4 is the chosen font.
                            if readerFont == QuranFontPreference.tajweedV4.rawValue {
                                divider

                                readerRow(
                                    title: "Tajweed colour guide",
                                    subtitle: "What each colour means",
                                    selected: false
                                ) {
                                    showingTajweedGuide = true
                                    DuhaaHaptics.tap()
                                }
                            }

                            divider

                            readerRow(
                                title: "Hold a word for meaning",
                                subtitle: "Touch & hold any word to see its meaning & hear it",
                                selected: wordLookup
                            ) {
                                wordLookup.toggle()
                                DuhaaHaptics.tap()
                            }
                        }
                        .background(cardShape)
                    }

                    settingsSection(title: "Background") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(MushafAppearance.displayCases) { appearance in
                                    backgroundSwatch(appearance)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                        }
                        .background(cardShape)
                    }

                    settingsSection(title: "Audio sync") {
                        Text("To listen with synced word highlighting, open the Quran audio player and tap a surah from a reciter.")
                            .duhaaFont(14)
                            .foregroundStyle(Palette.secondaryText)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(cardShape)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Mushaf Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(Palette.gold)
                }
            }
        }
        .sheet(isPresented: $showingTajweedGuide) {
            TajweedGuideView(appearance: MushafAppearance(rawValue: mushafBackground) ?? .duhaa)
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.appBg)
        .preferredColorScheme(Palette.active.colorScheme)
    }

    /// The app's standard card: translucent fill over the celestial background,
    /// with a hairline border — so this sheet matches every other Duhaa surface.
    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Palette.card)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.cardBorder, lineWidth: 1)
            )
    }

    private var divider: some View {
        Divider()
            .overlay(Palette.cardBorder)
            .padding(.leading, 18)
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .duhaaFont(12, .semibold)
                .tracking(1.4)
                .foregroundStyle(Palette.gold)
                .padding(.leading, 4)
            content()
        }
    }

    private func readerRow(
        title: String,
        subtitle: String,
        selected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(Palette.primaryText)
                    Text(subtitle)
                        .duhaaFont(12, .medium)
                        .foregroundStyle(Palette.secondaryText)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .duhaaFont(16, .bold)
                        .foregroundStyle(Palette.gold)
                }
            }
            .contentShape(Rectangle())
            .padding(18)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func backgroundSwatch(_ appearance: MushafAppearance) -> some View {
        let selected = mushafBackground == appearance.rawValue

        return Button {
            mushafBackground = appearance.rawValue
            DuhaaHaptics.tap()
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(appearance.background)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Palette.cardBorder, lineWidth: 1))
                    .overlay(
                        Circle()
                            .stroke(Palette.gold, lineWidth: selected ? 3 : 0)
                            .padding(-5)
                    )

                Text(appearance.title)
                    .duhaaFont(12, .semibold)
                    .foregroundStyle(selected ? Palette.gold : Palette.secondaryText)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
    }
}
