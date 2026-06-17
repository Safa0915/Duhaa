import Foundation

/// Kicks off first-use data decoding away from SwiftUI's render path.
///
/// The Quran bundle is large enough that decoding it on the first screen that
/// touches it can cause a visible debug-build hitch. Prewarming keeps the same
/// in-memory singletons, but lets the work happen on a background executor.
enum AppDataWarmup {
    private static let startOnce: Void = {
        Task.detached(priority: .utility) {
            QiblaDiagnostics.event("App data warmup started")
            async let quran = Quran.loadAsync(priority: .utility)
            async let duas = Duas.loadAsync(priority: .utility)
            async let learn = Learn.loadAsync(priority: .utility)
            async let reciters = Reciters.loadAsync(priority: .utility)

            _ = await (quran, duas, learn, reciters)
            QiblaDiagnostics.event("App data warmup finished")
        }
    }()

    static func start() {
        _ = startOnce
    }
}
