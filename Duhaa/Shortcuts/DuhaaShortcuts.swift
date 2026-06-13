import AppIntents
import Foundation

private enum ShortcutTarget {
    static let key = "duhaa.shortcut.targetTab"
}

struct OpenPrayerShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Prayer Times"
    static var description = IntentDescription("Open Duhaa to the Prayer tab.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(DuhaaTab.prayer.rawValue, forKey: ShortcutTarget.key)
        return .result()
    }
}

struct OpenQuranShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Quran"
    static var description = IntentDescription("Open Duhaa to the Quran reader.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(DuhaaTab.quran.rawValue, forKey: ShortcutTarget.key)
        return .result()
    }
}

struct OpenQiblaShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Qibla"
    static var description = IntentDescription("Open Duhaa to the Qibla compass.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(DuhaaTab.qibla.rawValue, forKey: ShortcutTarget.key)
        return .result()
    }
}

struct DuhaaShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPrayerShortcutIntent(),
            phrases: [
                "Open prayer times in \(.applicationName)",
                "Show my prayers in \(.applicationName)"
            ],
            shortTitle: "Prayer Times",
            systemImageName: "moon.stars.fill"
        )

        AppShortcut(
            intent: OpenQuranShortcutIntent(),
            phrases: [
                "Open Quran in \(.applicationName)",
                "Read Quran in \(.applicationName)"
            ],
            shortTitle: "Quran",
            systemImageName: "book.closed.fill"
        )

        AppShortcut(
            intent: OpenQiblaShortcutIntent(),
            phrases: [
                "Open Qibla in \(.applicationName)",
                "Show Qibla in \(.applicationName)"
            ],
            shortTitle: "Qibla",
            systemImageName: "location.north.line.fill"
        )
    }
}
