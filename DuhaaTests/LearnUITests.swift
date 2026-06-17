import XCTest
@testable import Duhaa

/// Tests for the Learn UI view-model layer — the pure helpers that decide what a
/// card/step shows. The SwiftUI views themselves stay thin and declarative, so
/// these cover the behaviour without a UI-testing dependency.
final class LearnUITests: XCTestCase {

    private func step(_ guideID: String, _ stepID: String) -> GuideStep? {
        Learn.guide(id: guideID)?.steps.first { $0.id == stepID }
    }

    // MARK: - Grouping / load (still works after the redesign)

    func testAllNineGuidesStillLoadAndGroup() {
        XCTAssertEqual(Learn.guides.count, 9)
        let grouped = Learn.guidesByGroup
        let ids = grouped.flatMap { $0.guides.map(\.id) }
        XCTAssertEqual(Set(ids), Set(Learn.guides.map(\.id)), "grouping dropped or duplicated a guide")
    }

    // MARK: - Guide card status chips

    func testEveryGuideCardHasAReadableStatusLabel() {
        let allowed = Set(["Source-backed", "Reviewed", "Needs review"])
        for guide in Learn.guides {
            XCTAssertTrue(allowed.contains(guide.reviewStatus.label), "\(guide.id): \(guide.reviewStatus.label)")
        }
    }

    func testNoStatusLabelEverSaysVerified() {
        for status in ReviewStatus.allCases {
            XCTAssertNotEqual(status.label.lowercased(), "verified")
        }
        for sens in MadhhabSensitivity.allCases {
            XCTAssertNotEqual(sens.chipLabel.lowercased(), "verified")
        }
    }

    func testMadhhabChipWordingStaysCalmAndNonSectarian() {
        // "Scholars differ" — never "Salafi", never a school label.
        XCTAssertEqual(MadhhabSensitivity.scholarDifference.chipLabel, "Scholars differ")
        XCTAssertFalse(MadhhabSensitivity.scholarDifference.chipLabel.localizedCaseInsensitiveContains("salafi"))
    }

    // MARK: - Arabic presence

    func testStepWithArabicIsDetected() {
        let s = step("wudu", "wudu-intention")           // has بِسْمِ اللَّهِ
        XCTAssertNotNil(s)
        XCTAssertTrue(s?.hasArabic == true)
    }

    func testStepWithoutArabicIsDetected() {
        let s = step("wudu", "wudu-hands")               // plain instruction, no Arabic
        XCTAssertNotNil(s)
        XCTAssertFalse(s?.hasArabic == true)
    }

    // MARK: - Meaning (transliteration/translation) gating

    func testMeaningSectionAppearsOnlyWhenThereIsMeaning() {
        XCTAssertTrue(step("wudu", "wudu-intention")?.hasMeaning == true)   // translit + translation
        XCTAssertFalse(step("wudu", "wudu-hands")?.hasMeaning == true)      // neither
    }

    // MARK: - Evidence / source chip

    func testEveryStepHasAnExpandableEvidenceChip() {
        for guide in Learn.guides {
            for s in guide.steps {
                XCTAssertTrue(s.hasEvidence, "\(guide.id)/\(s.id): no evidence to expand")
                XCTAssertFalse(s.sourceChipText.isEmpty, "\(guide.id)/\(s.id): empty source chip")
            }
        }
    }

    func testSourceChipReflectsStoredSummary() {
        XCTAssertEqual(step("wudu", "wudu-intention")?.sourceChipText, "Quran 5:6")
    }

    // MARK: - Madhhab note expansion

    func testMadhhabSensitiveStepsExposeANoteToExpand() {
        var sensitiveCount = 0
        for guide in Learn.guides {
            for s in guide.steps where s.isMadhhabSensitive {
                sensitiveCount += 1
                XCTAssertTrue(s.hasMadhhabNote, "\(guide.id)/\(s.id): sensitive step has no madhhabNote")
            }
        }
        XCTAssertGreaterThan(sensitiveCount, 0)
    }

    func testNonSensitiveStepShowsNoMadhhabChip() {
        XCTAssertFalse(step("wudu", "wudu-hands")?.isMadhhabSensitive == true)
    }

    // MARK: - Robustness

    func testOptionalFieldsDoNotBreakHelpers() {
        // A step with no scholarNotes / no subtitle / no madhhabNote still computes.
        let plain = step("ghusl", "ghusl-hands")
        XCTAssertNotNil(plain)
        XCTAssertFalse(plain?.isMadhhabSensitive == true)
        XCTAssertNil(plain?.scholarNotes)
        XCTAssertFalse(plain?.sourceChipText.isEmpty ?? true)
    }
}
