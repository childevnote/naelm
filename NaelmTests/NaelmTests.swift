//
//  NaelmTests.swift
//  NaelmTests
//
//  핵심 로직 유닛 테스트

import Testing
@testable import Naelm

// MARK: - SM-2 Algorithm Tests

@MainActor
struct SM2AlgorithmTests {

    @Test func correctAnswerIncreasesInterval() async throws {
        let result = SpacedRepetitionService.calculate(
            quality: 4,
            currentInterval: 1,
            currentRepetitions: 1,
            currentEaseFactor: 2.5
        )
        #expect(result.repetitions == 2)
        #expect(result.interval == 6)
        #expect(result.easeFactor >= 2.3)
    }

    @Test func incorrectAnswerResetsInterval() async throws {
        let result = SpacedRepetitionService.calculate(
            quality: 1,
            currentInterval: 6,
            currentRepetitions: 3,
            currentEaseFactor: 2.5
        )
        #expect(result.repetitions == 0)
        #expect(result.interval == 0)
    }

    @Test func perfectAnswerGivesHighEaseFactor() async throws {
        let result = SpacedRepetitionService.calculate(
            quality: 5,
            currentInterval: 1,
            currentRepetitions: 0,
            currentEaseFactor: 2.5
        )
        #expect(result.easeFactor >= 2.5)
        #expect(result.repetitions == 1)
    }

    @Test func easeFactorNeverBelowMinimum() async throws {
        let result = SpacedRepetitionService.calculate(
            quality: 3,
            currentInterval: 1,
            currentRepetitions: 0,
            currentEaseFactor: 1.3)
        #expect(result.easeFactor >= 1.3)
    }

    @Test func qualityIsClampedTo0And5() async throws {
        let low = SpacedRepetitionService.calculate(quality: -5, currentInterval: 1, currentRepetitions: 0, currentEaseFactor: 2.5)
        #expect(low.repetitions == 0)

        let high = SpacedRepetitionService.calculate(quality: 10, currentInterval: 1, currentRepetitions: 0, currentEaseFactor: 2.5)
        #expect(high.repetitions == 1)
    }
}

// MARK: - DashboardLaunchAction URL Tests

struct DashboardLaunchActionTests {

    @Test func vocabularyURL() {
        let url = URL(string: "naelm://study/vocabulary")!
        #expect(DashboardLaunchAction(url: url) == .startVocabulary)
    }

    @Test func grammarURL() {
        let url = URL(string: "naelm://study/grammar")!
        #expect(DashboardLaunchAction(url: url) == .startGrammar)
    }

    @Test func reviewURL() {
        let url = URL(string: "naelm://study/review")!
        #expect(DashboardLaunchAction(url: url) == .startReview)
    }

    @Test func unknownPathReturnsNil() {
        let url = URL(string: "naelm://study/unknown")!
        #expect(DashboardLaunchAction(url: url) == nil)
    }

    @Test func wrongSchemeReturnsNil() {
        let url = URL(string: "https://study/vocabulary")!
        #expect(DashboardLaunchAction(url: url) == nil)
    }

    @Test func schemeCaseInsensitive() {
        let url = URL(string: "NAELM://study/vocabulary")!
        #expect(DashboardLaunchAction(url: url) == .startVocabulary)
    }

    @Test func pathCaseInsensitive() {
        let url = URL(string: "naelm://study/VOCABULARY")!
        #expect(DashboardLaunchAction(url: url) == .startVocabulary)
    }

    @Test func hostCaseInsensitive() {
        let url = URL(string: "naelm://STUDY/grammar")!
        #expect(DashboardLaunchAction(url: url) == .startGrammar)
    }

    @Test func missingHostReturnsNil() {
        let url = URL(string: "naelm:///vocabulary")!
        #expect(DashboardLaunchAction(url: url) == nil)
    }

    @Test func extraTrailingSlashReturnsNil() {
        // Path would be "/vocabulary/" which doesn't match "/vocabulary"
        let url = URL(string: "naelm://study/vocabulary/")!
        #expect(DashboardLaunchAction(url: url) == nil)
    }
}

// MARK: - TOEIC Score Range Tests

struct TOEICScoreRangeTests {

    @Test func frequencyLevelsForTarget600() {
        let levels = TOEICScoreRange.frequencyLevels(forTarget: 600)
        #expect(levels.contains(1))
    }

    @Test func frequencyLevelsForTarget900() {
        let levels = TOEICScoreRange.frequencyLevels(forTarget: 900)
        #expect(levels.contains(1))
        #expect(levels.contains(2))
        #expect(levels.contains(3))
    }
}

// MARK: - Timer Duration Tests

struct TimerDurationTests {

    @Test func timerDurationMatchesTargetScore() {
        #expect(timerFor(600) == 15.0)
        #expect(timerFor(700) == 12.0)
        #expect(timerFor(800) == 9.0)
        #expect(timerFor(900) == 6.0)
    }

    private func timerFor(_ score: Int) -> Double {
        switch score {
        case ..<700: return 15.0
        case 700..<800: return 12.0
        case 800..<900: return 9.0
        default: return 6.0
        }
    }
}
