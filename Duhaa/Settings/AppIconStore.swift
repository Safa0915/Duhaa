import SwiftUI
import UIKit

/// One selectable home-screen icon. `alternateName == nil` is the primary
/// (shipping) icon; the others are alternate app icons compiled from the asset
/// catalog (`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`).
///
/// `previewAsset` is a normal image asset shown inside the picker because iOS
/// does not let us load an `*.appiconset` via `UIImage(named:)`.
struct AppIconOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let alternateName: String?
    let previewAsset: String

    static let all: [AppIconOption] = [
        .init(id: "navyGold", title: "Navy Gold", subtitle: "Classic moon",
              alternateName: nil, previewAsset: "IconPreview-Default"),
        .init(id: "mint", title: "Mint", subtitle: "Soft teal glow",
              alternateName: "AppIcon-Mint", previewAsset: "IconPreview-Mint"),
        .init(id: "lavender", title: "Lavender", subtitle: "Purple night",
              alternateName: "AppIcon-Lavender", previewAsset: "IconPreview-Lavender"),
        .init(id: "blackGold", title: "Black Gold", subtitle: "Warm metallic",
              alternateName: "AppIcon-BlackGold", previewAsset: "IconPreview-BlackGold"),
        .init(id: "cream", title: "Cream", subtitle: "Gentle glow",
              alternateName: "AppIcon-Cream", previewAsset: "IconPreview-Cream"),
        .init(id: "ink", title: "Ink", subtitle: "Clean contrast",
              alternateName: "AppIcon-Ink", previewAsset: "IconPreview-Ink"),
        .init(id: "ocean", title: "Ocean", subtitle: "Blue moonlight",
              alternateName: "AppIcon-Ocean", previewAsset: "IconPreview-Ocean"),
        .init(id: "sunset", title: "Sunset", subtitle: "Warm horizon",
              alternateName: "AppIcon-Sunset", previewAsset: "IconPreview-Sunset"),
        .init(id: "shadow", title: "Shadow", subtitle: "Low-light black",
              alternateName: "AppIcon-Shadow", previewAsset: "IconPreview-Shadow"),
        .init(id: "emerald", title: "Emerald", subtitle: "Deep green",
              alternateName: "AppIcon-Emerald", previewAsset: "IconPreview-Emerald"),
        .init(id: "cloud", title: "Cloud", subtitle: "Night clouds",
              alternateName: "AppIcon-Cloud", previewAsset: "IconPreview-Cloud"),
        .init(id: "copper", title: "Copper", subtitle: "Warm bronze",
              alternateName: "AppIcon-Copper", previewAsset: "IconPreview-Copper"),
        .init(id: "twilight", title: "Twilight", subtitle: "Pink dusk",
              alternateName: "AppIcon-Twilight", previewAsset: "IconPreview-Twilight"),
        .init(id: "sage", title: "Sage", subtitle: "Quiet green",
              alternateName: "AppIcon-Sage", previewAsset: "IconPreview-Sage"),
        .init(id: "sky", title: "Sky", subtitle: "Light clouds",
              alternateName: "AppIcon-Sky", previewAsset: "IconPreview-Sky"),
        .init(id: "silver", title: "Silver", subtitle: "Monochrome shine",
              alternateName: "AppIcon-Silver", previewAsset: "IconPreview-Silver"),
        .init(id: "lightPink", title: "Light Pink", subtitle: "Soft pink sky",
              alternateName: "AppIcon-LightPink", previewAsset: "IconPreview-LightPink"),
    ]

    static func option(forAlternateName name: String?) -> AppIconOption {
        all.first { $0.alternateName == name } ?? all[0]
    }
}

/// Tracks and switches the live home-screen icon. The system itself is the
/// source of truth (`UIApplication.alternateIconName`); we mirror it so the
/// picker and the Settings row stay in step.
@Observable
final class AppIconStore {
    private(set) var currentID: String
    /// Set when iOS rejects an icon change, surfaced gently in the picker.
    var lastError: String?

    var supported: Bool { UIApplication.shared.supportsAlternateIcons }

    init() {
        currentID = AppIconOption.option(forAlternateName:
            UIApplication.shared.alternateIconName).id
    }

    var current: AppIconOption {
        AppIconOption.all.first { $0.id == currentID } ?? AppIconOption.all[0]
    }

    @MainActor
    func select(_ option: AppIconOption) {
        guard option.id != currentID, supported else { return }
        // Already live (e.g. user changed it elsewhere) — just sync our mirror.
        if UIApplication.shared.alternateIconName == option.alternateName {
            currentID = option.id
            return
        }
        UIApplication.shared.setAlternateIconName(option.alternateName) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                } else {
                    self.lastError = nil
                    self.currentID = option.id
                    DuhaaHaptics.success()
                }
            }
        }
    }
}
