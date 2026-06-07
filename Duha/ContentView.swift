import SwiftUI
import Adhan

/// Slice 0 placeholder home screen.
///
/// This is throwaway "hello world" — the real Prayer home screen arrives in
/// Slice 2. Its one job today is to prove the app launches on the locked
/// celestial background AND that the Adhan Swift package resolved, linked, and
/// compiles (see `engineCheck`).
struct ContentView: View {
    // Locked palette (DUHA_SPEC.md §6)
    private let background = Color(red: 0.051, green: 0.086, blue: 0.157) // #0D1628
    private let gold = Color(red: 0.941, green: 0.753, blue: 0.251)       // #F0C040
    private let blue = Color(red: 0.557, green: 0.812, blue: 0.910)       // #8ECFE8

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("ضحى")
                    .font(.system(size: 72))
                    .foregroundStyle(gold)
                Text("Duha")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(engineCheck)
                    .font(.footnote)
                    .foregroundStyle(blue)
            }
        }
    }

    /// Touches the Adhan library so a successful build proves the package is
    /// wired in. MWL's Fajr angle is a known constant (18°).
    private var engineCheck: String {
        let params = CalculationMethod.muslimWorldLeague.params
        return "Engine linked · MWL Fajr angle \(Int(params.fajrAngle))°"
    }
}

#Preview {
    ContentView()
}
