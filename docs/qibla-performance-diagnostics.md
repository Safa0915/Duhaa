# First-Use Performance Diagnostics

Use this when checking a first-use freeze or jank around the Qibla compass or
Quran audio playback.

## Qibla Checklist

1. Run Duhaa on a real iPhone. Do not rely only on Simulator because Simulator has no real magnetometer and does not reproduce CoreHaptics startup cost.
2. Test both a Debug build and a Release/TestFlight-style build. Debug SwiftUI and signposts can exaggerate stalls.
3. Open Instruments from Xcode and choose Time Profiler.
4. Add Points of Interest so the Qibla signposts appear on the timeline.
5. Launch the app fresh, open Qibla for the first time, then slowly rotate the phone until it enters the aligned zone.
6. If a freeze happens, inspect the main thread during that exact 4-second window.
7. Compare the stall with these signposts:
   - Qibla screen appears
   - Qibla first frame placeholder visible
   - Qibla first async startup begins
   - Qibla CLLocationManager creation
   - Location authorization requested / resolved
   - Qibla heading updates start
   - Qibla first heading update received
   - Qibla first compass UI update
   - Qibla heading update
   - Qibla bearing calculation
   - Qibla alignment entered / exited
   - Qibla haptic generator created / prepared / fired
   - Qibla alignment animation started / ended
   - App data warmup started / finished
8. If the freeze lines up with the first haptic, verify `Qibla haptic generator prepared` happened before `Qibla alignment entered`.
9. If the freeze lines up with heading updates, check whether many `Qibla heading update` intervals cluster inside one frame.
10. If the freeze lines up with background drawing, compare Classic Duhaa and Light Pink with Reduce Motion on and off.
11. Save the trace before closing Instruments so the main-thread stack can be compared between builds.

Expected healthy behavior: the aligned transition should emit one alignment-enter signpost, one haptic fire, and one alignment animation start for a single entry into the threshold. It should not repeat while the phone remains aligned.

## Quran Audio Checklist

1. Run Duhaa on a real iPhone and test with a fresh install or after deleting the app so the first reciter/cache path is cold.
2. Open Instruments with Time Profiler and Points of Interest.
3. Launch Duhaa, open Quran, open a surah, and tap the first ayah play button.
4. The UI should switch to the loading spinner immediately, before audio session activation, cache lookup, network download, or AVPlayer item readiness.
5. Compare any stall with these signposts:
   - Quran reader view first appear
   - Quran feature first async startup begins
   - Quran audio controller init start / end
   - Quran play button tapped
   - Quran loading UI shown
   - Quran first async startup begins
   - Quran audio session configure
   - Quran audio session activate
   - Quran reciter/audio URL resolve
   - Quran cache lookup
   - Quran buffering started
   - Quran AVPlayerItem creation
   - Quran AVPlayer creation
   - Quran player item ready / failed / waiting
   - Quran first audio ready
   - Quran play() called
   - Quran first playback observed
   - Quran audio failed
6. If the freeze lines up before `Quran loading UI shown`, inspect the play-button call path and SwiftUI invalidation.
7. If it lines up with `Quran audio session configure` or `Quran audio session activate`, verify the AVAudioSession work remains off the main actor.
8. If it lines up with `Quran cache lookup`, inspect file I/O and download behavior.
9. If it lines up with AVPlayer item creation or readiness, inspect the main thread and network stack around that interval.

Expected healthy behavior: the first tap emits `Quran loading UI shown`
immediately, then the async startup signposts continue while the reader remains
responsive.
