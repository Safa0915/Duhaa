import SwiftUI
import WidgetKit

/// The widget extension's entry point. Lists every Duhaa widget the user can add.
///
/// ⚠️ `@main` lives in the **widget extension target only**. This file (and every
/// other file under `DuhaaWidgets/`) must NOT be added to the app target.
@main
struct DuhaaWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen (full color)
        NextPrayerWidget()           // small  · Next Prayer
        TodaysPrayersWidget()        // medium · Today's Prayers (interactive, Widget 2 color)
        PrayerDayWidget()            // large  · Prayer Day (interactive, Widget 2 color)
        WeeklyGridWidget()           // small + accessory · 7-day consistency (Widget 5)
        DailyDuaWidget()             // medium · Daily Du'a (Widget 6)
        DailyReflectionWidget()      // medium + large · Quran verse + hadith (Widget 7)

        // Lock Screen (monochrome-safe)
        NextPrayerCountdownWidget()  // circular + rectangular · countdown (Widget 1)
        PrayerTrackerWidget()        // circular + rectangular · tappable tracker (Widget 2)
        MorningPrayerTimesWidget()   // rectangular + circular · Fajr/Sunrise/Dhuhr (Widget 3)
        EveningPrayerTimesWidget()   // rectangular + circular · Asr/Maghrib/Isha (Widget 3)
        HijriDateWidget()            // circular + inline · Hijri date (Widget 4)
    }
}
