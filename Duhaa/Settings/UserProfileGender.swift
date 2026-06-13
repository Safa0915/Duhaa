import Foundation

enum UserProfileGender: String, CaseIterable, Identifiable, Codable {
    case notSet, brother, sister

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notSet: "Not set"
        case .brother: "Brother"
        case .sister: "Sister"
        }
    }

    var showsSistersFeatures: Bool {
        self != .brother
    }

    static func from(_ rawValue: String) -> UserProfileGender {
        UserProfileGender(rawValue: rawValue) ?? .notSet
    }
}
