import XCTest
@testable import Duhaa

final class LearnDataTests: XCTestCase {

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

    func testExactlyNineRequestedGuidesLoadInOrder() {
        XCTAssertEqual(Learn.guides.map(\.id), [
            "wudu",
            "ghusl",
            "tayammum",
            "prayer-core",
            "prayer-differences",
            "dhikr-after-prayer",
            "sujud-sahw",
            "tawbah",
            "coming-back-to-prayer",
        ])
        XCTAssertEqual(Learn.guides.count, 9)
    }

    func testGuideCountsMinutesAndCategoriesMatchBundledContent() {
        for guide in Learn.guides {
            let expected = expectedShape[guide.id]
            XCTAssertNotNil(expected, "\(guide.id) was not requested for v1.1 Learn")
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

    func testDhikrGuidePointsBackToExistingDuaLibrary() {
        let afterPrayer = Duas.categories.first { $0.name == "After Prayer Adhkar" }
        XCTAssertNotNil(afterPrayer)
        XCTAssertEqual(afterPrayer?.duas.count, 8)

        let guide = Learn.guide(id: "dhikr-after-prayer")
        XCTAssertNotNil(guide)
        XCTAssertTrue(guide?.steps.contains { $0.body.contains("Du'as") } == true)
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
}
