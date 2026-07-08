import XCTest
@testable import Duhaa

/// Decoding + integrity checks for the bundled Islamic Essentials question bank.
final class EssentialsModelTests: XCTestCase {

    func testBankDecodesWithExpectedSets() {
        let sets = Essentials.sets
        XCTAssertEqual(sets.count, 6)
        XCTAssertEqual(Set(sets.map(\.id)).count, 6, "Set ids must be unique")
        XCTAssertEqual(Set(sets.map(\.category)).count, 6, "One set per category")

        let counts = Dictionary(uniqueKeysWithValues: sets.map { ($0.id, $0.cards.count) })
        XCTAssertEqual(counts["prophets"], 5)
        XCTAssertEqual(counts["seerah"], 4)
        XCTAssertEqual(counts["quran-basics"], 5)
        XCTAssertEqual(counts["tawheed"], 4)
        XCTAssertEqual(counts["prayer-basics"], 5)
        XCTAssertEqual(counts["names"], 8) // 5 name pairs + 3 reflections

        let allIDs = sets.flatMap(\.cards).map(\.id)
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "Card ids must be globally unique")
    }

    func testCardsLinkBackToTheirSet() {
        for set in Essentials.sets {
            for card in set.cards {
                XCTAssertEqual(card.setID, set.id, "\(card.id) has a mismatched setID")
                XCTAssertEqual(card.category, set.category, "\(card.id) has a mismatched category")
            }
        }
    }

    func testQuizCardsAreWellFormed() throws {
        for set in Essentials.sets {
            for card in set.cards where card.type == .multipleChoice {
                let choices = try XCTUnwrap(card.choices, "\(card.id) has no choices")
                XCTAssertEqual(choices.count, 4, "\(card.id) should have 4 choices")
                let correct = try XCTUnwrap(card.correctIndex, "\(card.id) has no correctIndex")
                XCTAssertTrue(choices.indices.contains(correct), "\(card.id) correctIndex out of range")
                XCTAssertEqual(choices[correct], card.answer,
                               "\(card.id): answer text must equal the correct choice")
            }
        }
    }

    func testAnswerChecking() {
        for set in Essentials.sets {
            for card in set.cards {
                if card.isMultipleChoice, let correct = card.correctIndex {
                    XCTAssertTrue(card.isCorrectChoice(correct))
                    for wrong in 0..<4 where wrong != correct {
                        XCTAssertFalse(card.isCorrectChoice(wrong), "\(card.id) accepted a wrong choice")
                    }
                } else {
                    XCTAssertFalse(card.isCorrectChoice(0),
                                   "\(card.id) is not multiple choice and should never check correct")
                }
            }
        }
    }

    func testLearningModeConsistency() {
        for set in Essentials.sets {
            for card in set.cards {
                if card.supports(.learn) || card.supports(.test) {
                    XCTAssertTrue(card.isMultipleChoice,
                                  "\(card.id) claims learn/test but isn't a well-formed MCQ")
                }
                if card.type == .namePair {
                    XCTAssertTrue(card.supports(.match), "\(card.id) is a name pair but not matchable")
                }
            }
        }
        // Every set that routes to the detail screen must have Learn content.
        for set in Essentials.sets where set.category != .allahNames {
            XCTAssertFalse(set.cards(for: .learn).isEmpty, "\(set.title) has no Learn-mode cards")
        }
    }

    func testMatchPairsAreOneToOne() throws {
        let names = try XCTUnwrap(Essentials.allahNames)
        let pairs = names.namePairs
        XCTAssertGreaterThanOrEqual(pairs.count, 4, "Match mode needs at least 4 pairs")
        XCTAssertEqual(Set(pairs.map(\.id)).count, pairs.count)
        XCTAssertEqual(Set(pairs.map(\.name)).count, pairs.count)
        XCTAssertEqual(Set(pairs.map(\.meaning)).count, pairs.count)
    }

    func testMeaningFirstReversal() throws {
        let names = try XCTUnwrap(Essentials.allahNames)
        let originals = names.cards.filter { $0.type == .namePair }
        let reversed = Essentials.meaningFirst(originals)
        XCTAssertEqual(reversed.count, originals.count)
        for (original, flipped) in zip(originals, reversed) {
            XCTAssertEqual(flipped.prompt, original.answer)
            XCTAssertEqual(flipped.answer, original.prompt)
            XCTAssertNotEqual(flipped.id, original.id, "Reversed cards need their own ids")
        }
    }

    func testNothingClaimsVerifiedOrReviewed() {
        // House rule: no content is "Verified"/"Reviewed" until a scholar reviews it.
        for set in Essentials.sets {
            for card in set.cards {
                XCTAssertNotEqual(card.reviewStatus, .reviewed,
                                  "\(card.id) claims reviewed before scholar review")
                let texts = [card.prompt, card.answer, card.explanation ?? "",
                             card.sourceSummary ?? "", card.sourceReference?.text ?? "",
                             card.sourceReference?.note ?? ""]
                for text in texts {
                    XCTAssertFalse(text.localizedCaseInsensitiveContains("verified"),
                                   "Content must never claim 'Verified': \(text)")
                }
            }
        }
    }

    func testTawheedIsMarkedNeedsReview() {
        // Simplified aqeedah wording stays "Needs review" until checked.
        let tawheed = Essentials.sets.first { $0.category == .tawheed }
        XCTAssertNotNil(tawheed)
        for card in tawheed?.cards ?? [] {
            XCTAssertEqual(card.reviewStatus, .needsReview, "\(card.id) must stay needs_review")
        }
    }
}
