import SwiftUI

/// About & Acknowledgements — credits every bundled or streamed source.
/// Several licenses require attribution (duas dataset MIT, Adhan MIT, KFGQPC
/// font terms), so this screen is part of being shippable, not just polite.
struct AboutView: View {
    @State private var showingOpening = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Text("ضحى")
                        .duhaaFont(44)
                        .foregroundStyle(Palette.gold)
                    Text("Duhaa")
                        .duhaaFont(20, .semibold)
                        .foregroundStyle(.primary)
                    Text("Version \(version)")
                        .duhaaFont(12)
                        .foregroundStyle(.secondary)
                    Text("Built on hope, never guilt — a gentle return to prayer.")
                        .duhaaFont(13)
                        .foregroundStyle(Palette.blue.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    showingOpening = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sunrise.fill")
                            .duhaaFont(18, .semibold)
                            .foregroundStyle(Palette.gold)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Replay the Duhaa Opening")
                                .duhaaFont(14, .medium)
                                .foregroundStyle(.primary)
                            Text("The first-launch dawn moment")
                                .duhaaFont(12)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Palette.blue)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.card)
            }

            Section("Qur'an") {
                credit("Arabic text",
                       "The Uthmani text of the Qur'an (public heritage of the ummah), via the Quran.com API.")
                credit("English translation",
                       "ClearQuran by Talal Itani (Allah edition), used under its Creative Commons license (BY-NC-ND). ClearQuran.com.")
                credit("Transliteration",
                       "English transliteration of the Qur'an, bundled offline via the alquran.cloud API.")
                credit("Uthmani script font",
                       "KFGQPC HAFS Uthmanic Script — King Fahd Glorious Qur'an Printing Complex, Madinah.")
                credit("Quran page fonts",
                       "QPC Hafs, Indo-Pak Nastaleeq, QCF V2, and Tajweed V4 font assets served by Quran Foundation / Quran.com.")
                credit("Recitation",
                       "Nine renowned reciters — Alafasy, AbdulBaset, Sudais, Minshawi, and others — streamed from the Quran Foundation's audio service (Quran.com).")
                credit("Tafsir",
                       "Ibn Kathir (Abridged), English — bundled offline via the open spa5k/tafsir_api dataset (sourced from Quran.com).")
            }

            Section("Du'as & Adhkar") {
                credit("Hisnul Muslim",
                       "\"Fortress of the Muslim\" by Sa'id ibn Ali ibn Wahf al-Qahtani (رحمه الله), who gave it freely to the ummah.")
                credit("Dataset",
                       "dua-dhikr by Fitrahive — MIT License.")
            }

            Section("Prayer times") {
                credit("Calculation engine",
                       "Adhan Swift by Batoul Apps — MIT License.")
                credit("City database",
                       "Country & city list (for choosing your location offline) from GeoNames — CC BY 4.0.")
            }

            Section {
                Text("May Allah reward everyone whose work this app stands on, and everyone who prays because of it. Please keep its makers in your du'as. 🤍")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingOpening) {
            DuhaaOpeningView(isReplay: true) {
                showingOpening = false
            }
        }
    }

    private func credit(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .duhaaFont(14, .medium)
                .foregroundStyle(.primary)
            Text(detail)
                .duhaaFont(12)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
