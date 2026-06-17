import SwiftUI
import WidgetKit

// MARK: - Background

/// The calm, premium widget background: a theme gradient + a faint accent glow +
/// a low-opacity crescent watermark, and (Light Pink only) a couple of static,
/// barely-there hearts. No animation — widgets render statically and we keep them
/// elegant, never flashy.
struct WidgetBackdrop: View {
    let theme: WidgetTheme
    var showsCrescent = true

    var body: some View {
        ZStack {
            theme.backgroundGradient
            theme.glowGradient
            if showsCrescent {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 150))
                    .foregroundStyle(theme.accent)
                    .opacity(theme.motifOpacity)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 70, y: -46)
                    .accessibilityHidden(true)
            }
            if theme.heartOpacity > 0 {
                HeartMotif(color: theme.secondaryAccent, opacity: theme.heartOpacity)
            }
        }
    }
}

/// A few static, faint hearts for the Light Pink theme — a soft background motif,
/// never a heavy or animated effect.
private struct HeartMotif: View {
    let color: Color
    let opacity: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                heart(size: 34).position(x: geo.size.width * 0.16, y: geo.size.height * 0.82)
                heart(size: 22).position(x: geo.size.width * 0.86, y: geo.size.height * 0.30)
                heart(size: 16).position(x: geo.size.width * 0.62, y: geo.size.height * 0.92)
            }
        }
        .accessibilityHidden(true)
    }

    private func heart(size: CGFloat) -> some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(color)
            .opacity(opacity)
    }
}

// MARK: - Progress ring

/// A miniature completion ring: an accent arc over a soft track, with the count
/// in the middle. Conveys progress without color alone (the number carries it too).
struct CompletionRing: View {
    let theme: WidgetTheme
    let count: Int
    let total: Int
    var lineWidth: CGFloat = 6
    var showsLabel = true

    private var progress: Double { total > 0 ? Double(count) / Double(total) : 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.ringTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    AngularGradient(colors: [theme.accent.opacity(0.7), theme.accent],
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                VStack(spacing: -1) {
                    Text("\(count)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.primaryText)
                    Text("of \(total)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(count) of \(total) prayers prayed today")
    }
}

// MARK: - Next-prayer hero

/// The "next prayer" headline block reused across families: small label, big name,
/// time, and a relative countdown rendered with WidgetKit's self-updating date
/// text (no fake per-second timer — the system advances it).
struct NextPrayerHero: View {
    let theme: WidgetTheme
    let snapshot: PrayerWidgetSnapshot
    var nameSize: CGFloat = 30
    var showsCountdown = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.nextPrayerIsTomorrow ? "NEXT · TOMORROW" : "NEXT PRAYER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(theme.secondaryText)
            Text(snapshot.nextDisplayName ?? "—")
                .font(.system(size: nameSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let time = snapshot.nextPrayerTime {
                HStack(spacing: 5) {
                    Text(time, style: .time)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    if showsCountdown && time > snapshot.date {
                        // "· in 2 hr" — Text concatenation keeps the relative date
                        // self-updating (WidgetKit advances it); never interpolate a
                        // Text into a string literal.
                        (Text("· ") + Text(time, style: .relative))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let name = snapshot.nextDisplayName, let time = snapshot.nextPrayerTime else {
            return "Next prayer unavailable"
        }
        let f = DateFormatter(); f.timeStyle = .short
        let when = snapshot.nextPrayerIsTomorrow ? "tomorrow at" : "at"
        return "Next prayer \(name), \(when) \(f.string(from: time))"
    }
}

// MARK: - Completion dots (small-widget glance)

/// Five dots showing which prayers are done, plus a "2 / 5" label. The label and
/// VoiceOver text carry the meaning so completion is never conveyed by color alone.
struct CompletionDots: View {
    let theme: WidgetTheme
    let snapshot: PrayerWidgetSnapshot

    var body: some View {
        HStack(spacing: 5) {
            ForEach(snapshot.prayers) { item in
                Circle()
                    .fill(item.isCompleted ? theme.accent : theme.ringTrack)
                    .frame(width: 7, height: 7)
                    .overlay {
                        if item.isNext {
                            Circle().stroke(theme.accent, lineWidth: 1).frame(width: 12, height: 12)
                        }
                    }
            }
            Spacer(minLength: 4)
            Text(snapshot.progressText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryText)
        }
        .accessibilityElement()
        .accessibilityLabel("\(snapshot.dailyCompletionCount) of \(snapshot.totalPrayerCount) prayers prayed today")
    }
}

// MARK: - Empty / fallback

/// The graceful no-data state: never blank, never crashing.
struct WidgetFallback: View {
    let theme: WidgetTheme
    let message: String
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            Image(systemName: "moon.stars")
                .font(.system(size: compact ? 22 : 30))
                .foregroundStyle(theme.accent.opacity(0.8))
            Text(message)
                .font(.system(size: compact ? 12 : 14, weight: .medium))
                .foregroundStyle(theme.primaryText.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
