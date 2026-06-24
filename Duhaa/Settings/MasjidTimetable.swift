import Foundation

/// A user's local masjid jamāʿah (iqāmah) times — the congregation times posted at
/// their mosque, which differ from the calculated adhān times. Entirely optional:
/// every prayer stays `nil` until the user adds it. Stored as minutes since local
/// midnight (wall-clock), so the times read the same regardless of device time zone.
struct MasjidTimetable: Codable, Equatable, Sendable {
    var name: String = ""
    var fajr: Int?
    var dhuhr: Int?
    var asr: Int?
    var maghrib: Int?
    var isha: Int?
    var jumuah: Int?    // Friday congregation — shown in place of Dhuhr on Fridays

    /// True once at least one jamāʿah time has been entered.
    var hasAnyTime: Bool {
        [fajr, dhuhr, asr, maghrib, isha, jumuah].contains { $0 != nil }
    }

    /// The jamāʿah time (minutes since midnight) for one of the five daily prayers.
    func minutes(for prayer: Prayer) -> Int? {
        switch prayer {
        case .fajr:    fajr
        case .dhuhr:   dhuhr
        case .asr:     asr
        case .maghrib: maghrib
        case .isha:    isha
        }
    }

    /// Format minutes-since-midnight as a 12-hour clock ("6:20 AM"), matching the
    /// app's en_US_POSIX "h:mm a" style and independent of the device locale.
    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        let hour24 = m / 60, minute = m % 60
        let period = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minute, period)
    }
}

// MARK: - Sharing & importing

extension MasjidTimetable {
    /// A friendly, plain-text version of the timetable that the user can copy and
    /// send to anyone (a fellow worshipper, the group chat). It reads naturally and
    /// `parse(_:)` can read it back, so two people at the same masjid only enter the
    /// times once. Only the prayers that are set are listed.
    func shareText() -> String {
        let title = name.trimmingCharacters(in: .whitespaces)
        var lines = [title.isEmpty ? "Jamāʿah times" : "\(title) — Jamāʿah times"]
        func add(_ label: String, _ minutes: Int?) {
            if let minutes { lines.append("\(label) — \(MasjidTimetable.clock(minutes))") }
        }
        add("Fajr", fajr)
        add("Dhuhr", dhuhr)
        add("Asr", asr)
        add("Maghrib", maghrib)
        add("Isha", isha)
        add("Jumuʿah", jumuah)
        lines.append("Shared from Duhaa")
        return lines.joined(separator: "\n")
    }

    /// Reads a pasted timetable back into a `MasjidTimetable`. Deliberately tolerant:
    /// it scans line by line, and for any line that names a prayer *and* carries a
    /// time it fills that prayer — so it also accepts times someone typed by hand.
    /// Returns `nil` only when no prayer time could be found at all.
    static func parse(_ text: String) -> MasjidTimetable? {
        var result = MasjidTimetable()
        var foundTime = false

        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            let lower = line.lowercased()

            guard let minutes = parseClock(line) else {
                // A line with no time may be the masjid's name ("<name> — Jamāʿah …").
                if result.name.isEmpty, let parsedName = parseName(line) {
                    result.name = parsedName
                }
                continue
            }

            // Most-specific keywords first so "Jumuʿah" isn't mistaken for Dhuhr.
            if lower.contains("fajr") {
                result.fajr = minutes
            } else if lower.contains("jumu") || lower.contains("jum'") || lower.contains("friday") {
                result.jumuah = minutes
            } else if lower.contains("dhuhr") || lower.contains("zuhr") || lower.contains("duhr") {
                result.dhuhr = minutes
            } else if lower.contains("asr") {
                result.asr = minutes
            } else if lower.contains("maghrib") {
                result.maghrib = minutes
            } else if lower.contains("isha") {
                result.isha = minutes
            } else {
                continue   // a time we can't attribute to a prayer — ignore it
            }
            foundTime = true
        }

        return foundTime ? result : nil
    }

    /// Parse the first time token on a line ("6:20 AM", "06:20", "13:30") to minutes.
    static func parseClock(_ line: String) -> Int? {
        guard let regex = try? NSRegularExpression(
            pattern: "(\\d{1,2}):(\\d{2})\\s*([AaPp][Mm])?") else { return nil }
        let text = line as NSString
        guard let match = regex.firstMatch(
            in: line, range: NSRange(location: 0, length: text.length)) else { return nil }

        var hour = Int(text.substring(with: match.range(at: 1))) ?? -1
        let minute = Int(text.substring(with: match.range(at: 2))) ?? -1

        let periodRange = match.range(at: 3)
        if periodRange.location != NSNotFound {
            switch text.substring(with: periodRange).lowercased() {
            case "pm": if hour != 12 { hour += 12 }
            default:   if hour == 12 { hour = 0 }   // am
            }
        }

        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// Pull the masjid name from a "<name> — Jamāʿah times" header line, if present.
    private static func parseName(_ line: String) -> String? {
        guard line.lowercased().contains("jam") else { return nil }   // "Jamāʿah"/"Jamaah"
        for separator in ["—", "–", " - "] {
            if let range = line.range(of: separator) {
                let name = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                return name.isEmpty ? nil : name
            }
        }
        return nil
    }
}
