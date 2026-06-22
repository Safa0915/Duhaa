import XCTest
@testable import Duhaa

final class LearnDataTests: XCTestCase {

    // (steps, minutes, category) — unchanged content shape, used to prove the
    // reorganization didn't drop or mutate any guide.
    private let expectedShape: [String: (steps: Int, minutes: Int, category: GuideCategory)] = [
        "wudu": (8, 5, .purification),
        "ghusl": (7, 6, .purification),
        "tayammum": (5, 3, .purification),
        "prayer-core": (10, 10, .prayer),
        "prayer-differences": (5, 5, .prayer),
        "dhikr-after-prayer": (7, 8, .prayer),
        "sujud-sahw": (7, 8, .prayer),
        "tawbah": (6, 6, .foundations),
        "coming-back-to-prayer": (7, 7, .foundations),
    ]

    // MARK: - Load + ordering

    func testJSONDecodesAndAllNineGuidesLoad() {
        XCTAssertEqual(Learn.guides.count, 9, "learn_guides.json did not decode all 9 guides")
    }

    func testGuidesLoadInNewDisplayOrder() {
        XCTAssertEqual(Learn.guides.map(\.id), [
            "coming-back-to-prayer",
            "wudu",
            "prayer-core",
            "dhikr-after-prayer",
            "tawbah",
            "ghusl",
            "tayammum",
            "sujud-sahw",
            "prayer-differences",
        ])
    }

    func testGuideIDsAreUnique() {
        let ids = Learn.guides.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate guide id")
    }

    func testStepIDsAreUniqueWithinEachGuide() {
        for guide in Learn.guides {
            let ids = guide.steps.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(guide.id): duplicate step id")
        }
    }

    func testGuideCountsMinutesAndCategoriesMatchBundledContent() {
        for guide in Learn.guides {
            let expected = expectedShape[guide.id]
            XCTAssertNotNil(expected, "\(guide.id) was not requested for Learn")
            XCTAssertEqual(guide.steps.count, expected?.steps, "\(guide.id): step count changed")
            XCTAssertEqual(guide.estimatedMinutes, expected?.minutes, "\(guide.id): minute estimate changed")
            XCTAssertEqual(guide.category, expected?.category, "\(guide.id): category changed")
        }
    }

    func testStepOrdersAreContiguous() {
        for guide in Learn.guides {
            XCTAssertEqual(guide.sortedSteps.map(\.order), Array(1...guide.steps.count), "\(guide.id): step order is not contiguous")
        }
    }

    // MARK: - New framework metadata

    func testEveryGuideHasDisplayOrderReviewStatusAndSensitivity() {
        let orders = Learn.guides.map(\.displayOrder)
        XCTAssertEqual(Set(orders).count, orders.count, "displayOrder values must be unique")
        XCTAssertEqual(orders.sorted(), Array(1...9), "displayOrder should be 1...9")
        for guide in Learn.guides {
            // reviewStatus / madhhabSensitivity are non-optional, so presence is
            // structural; assert the product guardrail instead.
            XCTAssertNotEqual(guide.scholarReviewStatus, .reviewed,
                              "\(guide.id): nothing should claim scholar-reviewed before sign-off")
        }
    }

    func testGuidesAreGroupedWithoutDuplicateCards() {
        let grouped = Learn.guidesByGroup
        XCTAssertFalse(grouped.isEmpty)
        // Group sections must appear in the fixed display order.
        XCTAssertEqual(grouped.map(\.group.displayIndex), grouped.map(\.group.displayIndex).sorted())
        // Every guide appears exactly once across all groups.
        let groupedIDs = grouped.flatMap { $0.guides.map(\.id) }
        XCTAssertEqual(Set(groupedIDs).count, groupedIDs.count, "a guide appears in more than one group")
        XCTAssertEqual(Set(groupedIDs), Set(Learn.guides.map(\.id)), "grouping dropped a guide")
    }

    func testStartHereLeadsWithTheBeginnerEssentials() {
        let startHere = Learn.guidesByGroup.first { $0.group == .startHere }
        XCTAssertEqual(startHere?.guides.map(\.id), ["coming-back-to-prayer", "wudu", "prayer-core"])
    }

    func testMadhhabSensitiveStepsCarryAGentleNote() {
        var flagged = 0
        for guide in Learn.guides {
            for step in guide.steps where step.madhhabSensitivity.warrantsNote {
                flagged += 1
                XCTAssertNotNil(step.madhhabNote, "\(guide.id)/\(step.id): sensitive step is missing a madhhabNote")
                XCTAssertFalse(step.madhhabNote?.isEmpty ?? true)
            }
        }
        XCTAssertGreaterThan(flagged, 0, "expected at least one madhhab-sensitive step to be flagged")
    }

    func testEveryStepHasASourceSummaryChip() {
        for guide in Learn.guides {
            for step in guide.steps {
                let chip = step.sourceSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(chip?.isEmpty ?? true, "\(guide.id)/\(step.id): missing sourceSummary")
            }
        }
    }

    func testNothingIsFalselyMarkedReviewed() {
        for guide in Learn.guides {
            XCTAssertNotEqual(guide.reviewStatus, .reviewed, "\(guide.id): content marked reviewed pre-sign-off")
            for step in guide.steps {
                XCTAssertNotEqual(step.reviewStatus, .reviewed, "\(guide.id)/\(step.id): step marked reviewed pre-sign-off")
            }
        }
    }

    func testOptionalScholarNotesDoNotBreakDecoding() {
        // Most steps have no scholarNotes/subtitle/scholarSources; a successful load
        // with those absent proves IfPresent decoding works.
        XCTAssertTrue(Learn.guides.contains { $0.steps.contains { $0.scholarNotes == nil } })
        XCTAssertTrue(Learn.guides.contains { $0.subtitle == nil })
    }

    // MARK: - Evidence integrity (preserved through the reorg)

    func testEveryStepHasEvidenceWithSourceGradeAndAttribution() {
        for guide in Learn.guides {
            for step in guide.steps {
                XCTAssertFalse(step.dalilReferences.isEmpty, "\(guide.id)/\(step.id): missing evidence")
                for reference in step.dalilReferences {
                    XCTAssertFalse(reference.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(guide.id)/\(step.id): empty source")
                    XCTAssertFalse(reference.graderAttribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(guide.id)/\(step.id): missing grader")
                }
            }
        }
    }

    func testNoWeakOrFabricatedNarrationsShipInLearn() {
        let blocked: Set<EvidenceGrade> = [.daif, .mawdu]
        for guide in Learn.guides {
            for step in guide.steps {
                for reference in step.dalilReferences {
                    XCTAssertFalse(blocked.contains(reference.grade), "\(guide.id)/\(step.id): weak or fabricated evidence should be omitted")
                }
            }
        }
    }

    func testLearnEvidenceDisplayOmitsAlbaniByline() {
        for guide in Learn.guides {
            for step in guide.steps {
                for reference in step.dalilReferences {
                    XCTAssertFalse(reference.displayGradingText.localizedCaseInsensitiveContains("al-Albani"), "\(guide.id)/\(step.id): remove al-Albani from visible grading text")
                }
            }
        }
    }

    func testArabicAndTranslationSurvivedTheReorg() {
        // The Bismillah step keeps its Arabic + translation.
        let wudu = Learn.guide(id: "wudu")
        let step = wudu?.steps.first { $0.id == "wudu-intention" }
        XCTAssertEqual(step?.arabicText, "بِسْمِ اللَّهِ")
        XCTAssertNotNil(step?.translation)
    }

    func testDhikrGuidePointsBackToExistingDuaLibrary() {
        let afterPrayer = Duas.categories.first { $0.name == "After Prayer Adhkar" }
        XCTAssertNotNil(afterPrayer)
        XCTAssertEqual(afterPrayer?.duas.count, 8)

        let guide = Learn.guide(id: "dhikr-after-prayer")
        XCTAssertNotNil(guide)
        XCTAssertTrue(guide?.steps.contains { $0.body.contains("Du'as") } == true)
    }

    func testExistingDuasJSONStillDecodes() {
        XCTAssertFalse(Duas.categories.isEmpty, "Duas JSON failed to decode")
    }

    func testContentHasNoReviewTodos() {
        for guide in Learn.guides {
            XCTAssertFalse(guide.title.localizedCaseInsensitiveContains("TODO"))
            XCTAssertFalse(guide.summary.localizedCaseInsensitiveContains("TODO"))
            for step in guide.steps {
                XCTAssertFalse(step.title.localizedCaseInsensitiveContains("TODO"), "\(guide.id)/\(step.id)")
                XCTAssertFalse(step.body.localizedCaseInsensitiveContains("TODO"), "\(guide.id)/\(step.id)")
            }
        }
    }

    // NOTE: The user-facing madhhab-preference picker (MadhhabPreference /
    // MadhhabSettings, and MadhhabGuidance.shouldShowNote) was removed in commit
    // b614ca2 "Publish Duhaa updates" — the app now keeps only neutral guidance
    // text on MadhhabGuidance and never asks the user to declare a school. The
    // five tests that exercised that removed API were left behind by that commit
    // and broke the test target's compile; they're removed here. Neutral
    // MadhhabSensitivity chip wording is still covered in LearnUITests.
}
