import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Interactive toggle styles

/// A vertical, premium prayer "pill" that doubles as an interactive toggle. The
/// whole pill is the tap target; tapping runs the completion intent. Appearance
/// reflects `configuration.isOn` for instant optimistic feedback.
struct PrayerPillToggleStyle: ToggleStyle {
    let theme: WidgetTheme
    let item: PrayerSnapshotItem

    func makeBody(configuration: Configuration) -> some View {
        let done = configuration.isOn
        return VStack(spacing: 3) {
            Image(systemName: done ? "checkmark" : item.id.sfSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(done || item.isNext ? theme.accent : theme.secondaryText)
                .frame(height: 15)
            Text(item.displayName)
                .font(.system(size: 9.5, weight: item.isNext ? .semibold : .medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(item.shortTimeString)
                .font(.system(size: 8.5))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(done ? theme.completedFill : theme.pillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(item.isNext && !done ? theme.accent.opacity(0.6) : theme.pillBorder,
                        lineWidth: item.isNext ? 1.2 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .contentShape(Rectangle())
        .opacity(item.isPast && !done && !item.isNext ? 0.65 : 1)
        .accessibilityLabel(done ? "\(item.displayName) prayed, \(item.shortTimeString)"
                            : "Mark \(item.displayName) as prayed, \(item.shortTimeString)")
    }
}

/// A full-width prayer row that doubles as an interactive toggle, for the large
/// widget: icon · name · time · a trailing check that fills when prayed.
struct PrayerRowToggleStyle: ToggleStyle {
    let theme: WidgetTheme
    let item: PrayerSnapshotItem

    func makeBody(configuration: Configuration) -> some View {
        let done = configuration.isOn
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9)
                .fill(item.isNext ? theme.accent.opacity(0.14) : theme.pillBackground)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: item.id.sfSymbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(item.isNext ? theme.accent : theme.secondaryText))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 15, weight: item.isNext ? .semibold : .medium))
                        .foregroundStyle(theme.primaryText)
                    if item.isNext { NextBadge(theme: theme) }
                }
            }
            Spacer(minLength: 6)
            Text(item.shortTimeString)
                .font(.system(size: 14, weight: item.isNext ? .semibold : .medium))
                .foregroundStyle(item.isNext ? theme.accent : theme.secondaryText)
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(done ? theme.accent : theme.secondaryText.opacity(0.4))
                .frame(width: 30, height: 30)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .opacity(item.isPast && !done && !item.isNext ? 0.62 : 1)
        .accessibilityLabel(done ? "\(item.displayName) prayed, \(item.shortTimeString)"
                            : "Mark \(item.displayName) as prayed, \(item.shortTimeString)")
    }
}

private struct NextBadge: View {
    let theme: WidgetTheme
    var body: some View {
        Text("NEXT")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(theme.colors.onAccent)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(theme.accent, in: Capsule())
    }
}

// MARK: - Small — Next Prayer

struct SmallPrayerView: View {
    let snapshot: PrayerWidgetSnapshot
    let theme: WidgetTheme

    var body: some View {
        if snapshot.status == .unavailable {
            WidgetFallback(theme: theme, message: snapshot.message ?? "Open Duhaa", compact: true)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.accent)
                    Spacer()
                    if snapshot.status == .stale {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                Spacer(minLength: 6)
                NextPrayerHero(theme: theme, snapshot: snapshot, nameSize: 27)
                Spacer(minLength: 8)
                CompletionDots(theme: theme, snapshot: snapshot)
                    .invalidatableContent()
            }
            .padding(15)
        }
    }
}

// MARK: - Medium — Today's Prayers

struct MediumPrayerView: View {
    let snapshot: PrayerWidgetSnapshot
    let theme: WidgetTheme

    var body: some View {
        if snapshot.status == .unavailable {
            WidgetFallback(theme: theme, message: snapshot.message ?? "Open Duhaa to set up prayer times")
        } else {
            VStack(spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    if snapshot.status == .ok {
                        NextPrayerHero(theme: theme, snapshot: snapshot, nameSize: 23)
                    } else {
                        staleHeader
                    }
                    Spacer(minLength: 4)
                    // Count is timeline-frozen — mark it invalidatable so it reads
                    // as "updating" between a tap and the coalesced reload.
                    CompletionRing(theme: theme, count: snapshot.dailyCompletionCount,
                                   total: snapshot.totalPrayerCount, lineWidth: 5)
                        .frame(width: 48, height: 48)
                        .invalidatableContent()
                }
                HStack(spacing: 6) {
                    ForEach(snapshot.prayers) { item in
                        Toggle(isOn: item.isCompleted,
                               intent: SetPrayerCompletionIntent(prayer: item.id, dayKey: snapshot.dayKey)) {
                            Text(item.displayName)
                        }
                        .toggleStyle(PrayerPillToggleStyle(theme: theme, item: item))
                    }
                }
            }
            .padding(14)
        }
    }

    private var staleHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TODAY")
                .font(.system(size: 10, weight: .semibold)).tracking(1.1)
                .foregroundStyle(theme.secondaryText)
            Text(snapshot.message ?? "Open Duhaa to refresh times")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2).minimumScaleFactor(0.85)
        }
    }
}

// MARK: - Large — Prayer Day

struct LargePrayerView: View {
    let snapshot: PrayerWidgetSnapshot
    let theme: WidgetTheme

    var body: some View {
        if snapshot.status == .unavailable {
            WidgetFallback(theme: theme, message: snapshot.message ?? "Open Duhaa to set up prayer times")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider().overlay(theme.pillBorder)
                VStack(spacing: 2) {
                    ForEach(snapshot.prayers) { item in
                        Toggle(isOn: item.isCompleted,
                               intent: SetPrayerCompletionIntent(prayer: item.id, dayKey: snapshot.dayKey)) {
                            Text(item.displayName)
                        }
                        .toggleStyle(PrayerRowToggleStyle(theme: theme, item: item))
                    }
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                if let location = snapshot.locationDisplayName {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill").font(.system(size: 9))
                        Text(location).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(theme.secondaryText)
                }
                if snapshot.status == .ok {
                    NextPrayerHero(theme: theme, snapshot: snapshot, nameSize: 30)
                } else {
                    Text(snapshot.message ?? "Open Duhaa to refresh times")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                }
            }
            Spacer()
            CompletionRing(theme: theme, count: snapshot.dailyCompletionCount,
                           total: snapshot.totalPrayerCount, lineWidth: 6)
                .frame(width: 56, height: 56)
                .invalidatableContent()
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(theme.accent.opacity(0.8))
            Text(gentleMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondaryText)
            Spacer()
        }
    }

    /// Hope-framed, never guilt. Scales gently with how the day is going.
    private var gentleMessage: String {
        switch snapshot.dailyCompletionCount {
        case 0:     return "One prayer at a time"
        case 5:     return "May Allah keep you steadfast"
        case 4:     return "So close — keep going"
        default:    return "Keep going, you’re showing up"
        }
    }
}
