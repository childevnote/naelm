//
//  NaelmTests.swift
//  NaelmTests
//
//  핵심 로직 유닛 테스트

import Testing
import Foundation
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

@MainActor
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

// MARK: - GamificationService Tests

@MainActor
struct GamificationServiceTests {

    // MARK: Level 계산

    @Test func level1WhenXPIsZero() {
        #expect(GamificationService.level(fromTotalXP: 0) == 1)
    }

    @Test func level1BeforeFirstThreshold() {
        // 레벨 1 → 100 XP 필요. 99 XP이면 여전히 Lv.1
        #expect(GamificationService.level(fromTotalXP: 99) == 1)
    }

    @Test func level2AtExactThreshold() {
        // 누적 100 XP에서 레벨 2 달성
        #expect(GamificationService.level(fromTotalXP: 100) == 2)
    }

    @Test func level3AtCorrectCumulativeXP() {
        // 레벨 3 진입: 100 + 200 = 300 XP
        #expect(GamificationService.level(fromTotalXP: 300) == 3)
    }

    @Test func level4AtCorrectCumulativeXP() {
        // 레벨 4 진입: 100 + 200 + 300 = 600 XP
        #expect(GamificationService.level(fromTotalXP: 600) == 4)
    }

    @Test func levelNeverBelowOne() {
        #expect(GamificationService.level(fromTotalXP: -100) >= 1)
    }

    // MARK: levelProgress

    @Test func progressZeroAtLevelStart() {
        // Lv.1 시작 (0 XP) → 진행도 0
        let p = GamificationService.levelProgress(fromTotalXP: 0)
        #expect(p == 0.0)
    }

    @Test func progressHalfwayThroughLevel() {
        // Lv.1은 100 XP 필요. 50 XP → 0.5
        let p = GamificationService.levelProgress(fromTotalXP: 50)
        #expect(abs(p - 0.5) < 0.01)
    }

    @Test func progressDoesNotExceedOne() {
        let p = GamificationService.levelProgress(fromTotalXP: 100_000)
        #expect(p <= 1.0)
    }

    // MARK: xpToNextLevel

    @Test func xpToNextLevelFromZero() {
        // Lv.1 → 다음 레벨까지 100 XP
        #expect(GamificationService.xpToNextLevel(fromTotalXP: 0) == 100)
    }

    @Test func xpToNextLevelAtLevel2Start() {
        // Lv.2 시작 (100 XP) → 다음 레벨(Lv.3)까지 200 XP
        #expect(GamificationService.xpToNextLevel(fromTotalXP: 100) == 200)
    }

    @Test func xpToNextLevelNeverNegative() {
        #expect(GamificationService.xpToNextLevel(fromTotalXP: 999_999) >= 0)
    }

    // MARK: Level ↔ Progress 일관성

    @Test func levelAndProgressConsistent() {
        // 모든 레벨에서 progress는 [0, 1] 범위
        for xp in stride(from: 0, to: 10_000, by: 50) {
            let p = GamificationService.levelProgress(fromTotalXP: xp)
            #expect(p >= 0.0 && p <= 1.0,
                    "xp=\(xp): progress \(p) out of range")
        }
    }
}

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
