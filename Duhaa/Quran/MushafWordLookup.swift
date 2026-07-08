import SwiftUI
import UIKit
import CoreText
import AVFoundation

/// Holds the word a reader tapped in the Mushaf, so the page (deep inside a
/// `UIPageViewController`) can surface its meaning in a sheet owned at the top.
@MainActor
@Observable
final class MushafWordSelection {
    var word: MushafWord?
}

/// A tiny one-shot player for a single word's recitation (word-by-word audio).
/// Kept separate from `AyahPlayer` — there's no surah/queue here, just one mp3.
@MainActor
@Observable
final class MushafWordPlayer {
    private(set) var isPlaying = false
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    func toggle(_ url: URL) {
        if isPlaying { stop() } else { play(url) }
    }

    func play(_ url: URL) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
        let player = AVPlayer(playerItem: item)
        self.player = player
        isPlaying = true
        player.play()
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }
}

/// The hold-to-lookup card: the word's Arabic, transliteration, English meaning, and
/// a button to hear just that word recited. Shown as a small bottom sheet.
struct MushafWordMeaningCard: View {
    let word: MushafWord
    let readerFont: String
    /// The sheet's background follows the Mushaf appearance (not the app theme),
    /// so every foreground colour must come from the same appearance to stay readable.
    let appearance: MushafAppearance

    @State private var player = MushafWordPlayer()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(word.arabicText)
                .font(QuranFont.reader(QuranFontPreference(storageValue: readerFont).fallbackUnicodePreference.rawValue, size: 46))
                .foregroundStyle(appearance.accent)
                .environment(\.layoutDirection, .rightToLeft)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(word.arabicText)

            if !word.transliteration.isEmpty {
                Text(word.transliteration)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(appearance.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if !word.translation.isEmpty {
                Text(word.translation)
                    .duhaaFont(18, .medium)
                    .foregroundStyle(appearance.text)
                    .multilineTextAlignment(.center)
            }

            if let url = word.audioURL {
                Button {
                    player.toggle(url)
                    DuhaaHaptics.tap()
                } label: {
                    Label(player.isPlaying ? "Playing…" : "Hear this word",
                          systemImage: player.isPlaying ? "speaker.wave.2.fill" : "play.circle.fill")
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(appearance.controlForeground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(appearance.controlFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hear this word")
            }

            Text("Surah \(word.surah) · Ayah \(word.ayah)")
                .duhaaFont(12, .medium)
                .foregroundStyle(appearance.secondaryText)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 18)
        .onDisappear { player.stop() }
    }
}

/// Renders one mushaf line with CoreText so it can be JUSTIFIED to fill the page
/// width edge-to-edge (like a printed Madani mushaf) — a UITextView refuses to
/// justify a single line. Keeps the authentic shaped run + hold-a-word hit-testing,
/// and only shrinks the font if a line is too wide to fit even unjustified.
struct MushafTappableLineView: UIViewRepresentable {
    let words: [MushafWord]
    let fontName: String
    let baseSize: CGFloat
    let textColor: UIColor
    /// Justify to fill the page width (normal pages) vs. centre each line (the special
    /// framed opening pages — Al-Fātiḥah and the start of Al-Baqarah).
    var justify: Bool = true
    var isWordLookupEnabled: Bool = true
    let onSelectWord: (MushafWord) -> Void

    func makeUIView(context: Context) -> MushafLineUIView {
        let view = MushafLineUIView()
        // Touch-and-hold looks a word up, so a plain tap stays free for the reader's
        // show/hide-controls gesture.
        let hold = UILongPressGestureRecognizer(target: view, action: #selector(MushafLineUIView.handleLongPress(_:)))
        hold.minimumPressDuration = 0.35
        view.addGestureRecognizer(hold)
        return view
    }

    func updateUIView(_ view: MushafLineUIView, context: Context) {
        view.onSelectWord = onSelectWord
        view.isUserInteractionEnabled = isWordLookupEnabled
        view.configure(words: words, fontName: fontName, baseSize: baseSize,
                       textColor: textColor, justify: justify)
    }

    /// Force the line to exactly the page width SwiftUI proposes (never its natural
    /// text width), so it justifies/shrinks to fit instead of overflowing the page.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MushafLineUIView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 320, height: 44))
    }
}

/// A CoreText-backed mushaf line: builds a `CTLine`, justifies it to the page width,
/// draws it vertically centred and right-aligned, and maps a touch-and-hold back
/// to the word under the finger.
final class MushafLineUIView: UIView {
    var onSelectWord: ((MushafWord) -> Void)?

    private var spans: [(range: NSRange, word: MushafWord)] = []
    private var content = NSAttributedString()
    private var baseSize: CGFloat = 26
    private var fontName = "kfgqpc"
    private var justify = true

    // The line actually drawn (justified/scaled) + its placement, for hit-testing.
    private var drawnLine: CTLine?
    private var drawnXOffset: CGFloat = 0
    private var drawnSqueeze: CGFloat = 1
    private var laidOutWidth: CGFloat = -1

    private static let minimumInkPadding: CGFloat = 3
    private static let inkPaddingScale: CGFloat = 0.12

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("created in code") }

    func configure(words: [MushafWord], fontName: String, baseSize: CGFloat,
                   textColor: UIColor, justify: Bool) {
        self.fontName = fontName
        self.baseSize = baseSize
        self.justify = justify

        let mutable = NSMutableAttributedString()
        var newSpans: [(NSRange, MushafWord)] = []
        for (index, word) in words.enumerated() {
            if index > 0 { mutable.append(NSAttributedString(string: " ")) }
            let start = mutable.length
            mutable.append(NSAttributedString(string: word.text))
            let length = (word.text as NSString).length
            if word.isWord, length > 0 {
                newSpans.append((NSRange(location: start, length: length), word))
            }
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft

        let full = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: scaledFont(size: baseSize), range: full)
        mutable.addAttribute(.paragraphStyle, value: paragraph, range: full)
        mutable.addAttribute(.foregroundColor, value: textColor, range: full)

        content = mutable
        spans = newSpans
        laidOutWidth = -1
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.width - laidOutWidth) > 0.5 {
            laidOutWidth = bounds.width
            setNeedsDisplay()
        }
    }

    /// Build the CTLine for the current width. The whole mushaf shares ONE font size
    /// (so every page matches), so we never rescale here. A line too wide for the
    /// page first CLOSES ITS WORD GAPS; a narrow one justifies to fill the width.
    /// A genuinely short line (e.g. the last line of a surah) is left right-aligned
    /// rather than stretched across the whole page.
    private func makeLine(width: CGFloat) -> CTLine? {
        guard content.length > 0, width > 0 else { return nil }

        let line = CTLineCreateWithAttributedString(content as CFAttributedString)
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)

        if lineWidth > Double(width) {
            // Dense line: tighten the spaces between words instead of shrinking the
            // font. Whatever still overflows is condensed slightly in draw().
            let tightened = Self.closingWordGaps(in: content, by: CGFloat(lineWidth) - width)
            return CTLineCreateWithAttributedString(tightened as CFAttributedString)
        }

        guard justify else { return line }   // centred pages draw the line as-is

        if lineWidth > 0, Double(width) / lineWidth < 1.7 {
            return CTLineCreateJustifiedLine(line, 1.0, Double(width)) ?? line
        }
        return line
    }

    /// Close the gaps on an overflowing line: spread the deficit as negative kern
    /// across the spaces, cutting each by at most a bit over half its width so
    /// words never touch. Keeps the font size identical on every page — dense
    /// pages get tighter word spacing, exactly like the printed mushaf.
    static func closingWordGaps(in content: NSAttributedString, by deficit: CGFloat) -> NSAttributedString {
        let text = content.string as NSString
        var spaceLocations: [Int] = []
        for index in 0..<text.length where text.character(at: index) == 0x20 {
            spaceLocations.append(index)
        }
        guard deficit > 0, !spaceLocations.isEmpty,
              let font = content.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
            return content
        }

        let spaceWidth = CGFloat(CTLineGetTypographicBounds(
            CTLineCreateWithAttributedString(
                NSAttributedString(string: " ", attributes: [.font: font]) as CFAttributedString),
            nil, nil, nil))
        let cut = min(deficit / CGFloat(spaceLocations.count), spaceWidth * 0.55)
        guard cut > 0 else { return content }

        let tightened = NSMutableAttributedString(attributedString: content)
        for location in spaceLocations {
            tightened.addAttribute(.kern, value: -cut, range: NSRange(location: location, length: 1))
        }
        return tightened
    }

    /// Natural (unjustified) width of a line's text at a given size — used by the page
    /// to choose one uniform font size that fits every line. Matches `scaledFont`.
    static func naturalWidth(text: String, fontName: String, size: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let base = UIFont(name: fontName, size: size)
            ?? UIFont(name: QuranFont.family, size: size)
            ?? .systemFont(ofSize: size, weight: .regular)
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font]) as CFAttributedString)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(),
              let line = makeLine(width: bounds.width) else {
            drawnLine = nil
            return
        }

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        ctx.textMatrix = .identity
        let inkBounds = Self.inkBounds(for: line, context: ctx, lineWidth: lineWidth, ascent: ascent, descent: descent)

        // A line still wider than the page after gap-closing is condensed
        // horizontally to fit — same font size everywhere, slightly narrower
        // glyphs — so Quran text is never clipped and never rendered smaller.
        let squeeze = lineWidth > bounds.width && lineWidth > 0 ? bounds.width / lineWidth : 1

        // Justified/normal lines right-align (Arabic): a full line fills the width, a
        // short one hugs the right edge. Centred (special) pages sit in the middle.
        let inkLeft = min(0, inkBounds.minX) * squeeze
        let inkRight = max(lineWidth, inkBounds.maxX) * squeeze
        let inkWidth = inkRight - inkLeft
        let xOffset = justify
            ? max(0, bounds.width - inkWidth) - inkLeft
            : max(0, (bounds.width - inkWidth) / 2) - inkLeft
        let verticalPadding = max(Self.minimumInkPadding, scaledFont(size: baseSize).pointSize * Self.inkPaddingScale)
        let baselineY = Self.baselineY(boundsHeight: bounds.height, inkBounds: inkBounds, padding: verticalPadding)

        drawnLine = line
        drawnXOffset = xOffset
        drawnSqueeze = squeeze

        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        if squeeze < 1 {
            ctx.scaleBy(x: squeeze, y: 1)
        }
        ctx.textPosition = CGPoint(x: xOffset / squeeze, y: baselineY)
        CTLineDraw(line, ctx)
    }

    static func baselineY(boundsHeight: CGFloat, inkBounds: CGRect, padding: CGFloat) -> CGFloat {
        let centered = boundsHeight / 2 - inkBounds.midY
        let minimum = padding - inkBounds.minY
        let maximum = boundsHeight - padding - inkBounds.maxY

        guard minimum <= maximum else {
            return centered
        }
        return min(max(centered, minimum), maximum)
    }

    private static func inkBounds(for line: CTLine, context: CGContext, lineWidth: CGFloat, ascent: CGFloat, descent: CGFloat) -> CGRect {
        let measured = CTLineGetImageBounds(line, context)
        guard measured.isUsableInkBounds else {
            return CGRect(x: 0, y: -descent, width: lineWidth, height: ascent + descent)
        }
        return measured
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let line = drawnLine else { return }
        let point = gesture.location(in: self)
        // CTLineGetStringIndexForPosition measures x from the line origin; subtract
        // the right-align offset and undo any condensing. It handles RTL glyph
        // ordering internally.
        let index = CTLineGetStringIndexForPosition(line, CGPoint(x: (point.x - drawnXOffset) / drawnSqueeze, y: 0))
        guard index != kCFNotFound, index >= 0, index < content.length else { return }
        for span in spans where NSLocationInRange(index, span.range) {
            onSelectWord?(span.word)
            return
        }
    }

    private func scaledFont(size: CGFloat) -> UIFont {
        let base = UIFont(name: fontName, size: size)
            ?? UIFont(name: QuranFont.family, size: size)
            ?? .systemFont(ofSize: size, weight: .regular)
        // QuranFont.reader renders `relativeTo: .body`, so match that Dynamic Type scaling.
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }
}

private extension CGRect {
    var isUsableInkBounds: Bool {
        !isNull &&
            !isEmpty &&
            minX.isFinite &&
            minY.isFinite &&
            maxX.isFinite &&
            maxY.isFinite
    }
}
