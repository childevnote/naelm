//
//  LearningSessionManager.swift
//  Naelm
//
//  Created by 김동진 on 4/4/26.
//
//  학습 세션 오케스트레이터.
//  ──────────────────────────────────────────────
//  역할:
//    1. 복습 대상 + 새 항목을 혼합하여 학습 큐 구성
//    2. 세션 내 XP / 정답률 추적
//    3. 세션 종료 시 UserActivity에 결과 기록
//  ──────────────────────────────────────────────

import Foundation
import SwiftData
import os

// MARK: - Session Statistics

/// 한 세션의 학습 통계를 담는 구조체.
struct SessionStats {
    var wordsStudied: Int = 0
    var grammarStudied: Int = 0
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var xpEarned: Int = 0
    var startTime: Date = Date()

    /// 정답률 (0.0 ~ 1.0)
    var accuracy: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }

    /// 학습 시간 (초)
    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }

    /// 총 학습 항목 수
    var totalStudied: Int {
        wordsStudied + grammarStudied
    }
}

// MARK: - LearningSessionManager

/// 학습 세션의 상태와 진행을 관리하는 @Observable 클래스.
/// 각 학습 화면(단어/문법)의 ViewModel에서 이 매니저를 통해
/// SRS 기록과 XP를 일관되게 처리합니다.
@MainActor
@Observable
final class LearningSessionManager {

    // MARK: - XP 설정값

    /// 단어 카드 1장당 기본 XP
    static let xpPerVocabulary: Int = 10

    /// 문법 퀴즈 정답 시 XP
    static let xpPerGrammarCorrect: Int = 20

    /// 복습 완료 보너스 XP (단어/문법 각각)
    static let reviewCompletionBonusXP: Int = 50

    /// 일일 기본 목표 XP
    static let defaultDailyGoalXP: Int = 100

    // MARK: - Pending Record (세션 종료 시 일괄 반영)

    /// 세션 중 기록된 단어 스와이프 결과 (DB 미반영 상태)
    struct PendingVocabRecord {
        let vocabulary: Vocabulary
        let knewIt: Bool
        /// 응답 시간 (초). nil이면 타이머 미사용.
        let responseTime: Double?
    }

    /// 세션 중 기록된 문법 퀴즈 결과 (DB 미반영 상태)
    struct PendingGrammarRecord {
        let grammar: Grammar
        let isCorrect: Bool
        /// 응답 시간 (초). nil이면 타이머 미사용.
        let responseTime: Double?
        /// 타임아웃/모르겠다 여부
        let isTimeout: Bool
    }

    // MARK: - 상태

    /// 현재 세션 통계
    var stats = SessionStats()

    /// 세션 진행 중 여부
    var isSessionActive: Bool = false

    /// 현재 사용자 ID (AuthenticationManager에서 전달)
    var userID: String = ""

    /// 세션 중 대기 중인 단어 기록
    private var pendingVocab: [PendingVocabRecord] = []

    /// 세션 중 대기 중인 문법 기록
    private var pendingGrammar: [PendingGrammarRecord] = []

    // MARK: - 세션 시작/종료

    /// 새 학습 세션을 시작합니다.
    func startSession(userID: String) {
        self.userID = userID
        self.stats = SessionStats()
        self.pendingVocab = []
        self.pendingGrammar = []
        self.isSessionActive = true
        AppLogger.session.info("Session started")
    }

    /// 세션을 종료하고 모든 학습 결과를 DB에 일괄 반영합니다.
    /// - Returns: 이번 세션으로 변동된 추정 점수 (5의 배수, 음수 가능)
    @discardableResult
    func endSession(context: ModelContext, isVocabularyOnly: Bool = false) -> Int {
        guard isSessionActive else { return 0 }
        isSessionActive = false

        // 대기 중인 단어 기록을 DB에 반영
        for record in pendingVocab {
            // 응답시간 기반 0-5 품질 점수 계산
            let quality = Self.vocabQuality(knewIt: record.knewIt, responseTime: record.responseTime)
            SpacedRepetitionService.recordVocabularyReview(
                vocabulary: record.vocabulary,
                quality: quality,
                userID: userID,
                context: context
            )
            // 모르는 단어만 복습 플래그 설정 (mastery는 applyResult의 streak 조건에 위임)
            if !record.knewIt {
                let wordID = record.vocabulary.wordID
                let predicate = #Predicate<LearningProgress> {
                    $0.userID == userID &&
                    $0.itemType == "vocabulary" &&
                    $0.vocabulary?.wordID == wordID
                }
                if let progress = try? context.fetch(FetchDescriptor<LearningProgress>(predicate: predicate)).first {
                    progress.markedForReview = true
                }
            }
        }

        // 대기 중인 문법 기록을 DB에 반영
        for record in pendingGrammar {
            // 응답시간 + 타임아웃 기반 0-5 품질 점수 계산
            let quality = Self.grammarQuality(isCorrect: record.isCorrect, isTimeout: record.isTimeout, responseTime: record.responseTime)
            SpacedRepetitionService.recordGrammarReview(
                grammar: record.grammar,
                quality: quality,
                userID: userID,
                context: context
            )
            // 오답만 복습 플래그 설정 (mastery는 applyResult의 streak 조건에 위임)
            if !record.isCorrect {
                let grammarID = record.grammar.grammarID
                let predicate = #Predicate<LearningProgress> {
                    $0.userID == userID &&
                    $0.itemType == "grammar" &&
                    $0.grammar?.grammarID == grammarID
                }
                if let progress = try? context.fetch(FetchDescriptor<LearningProgress>(predicate: predicate)).first {
                    progress.markedForReview = true
                }
            }
        }

        // UserActivity에 오늘 학습 기록 저장
        saveUserActivity(context: context)

        // ── 추정 점수 업데이트 ───────────────────────────────
        let scoreDelta: Int
        if isVocabularyOnly {
            scoreDelta = 0
        } else {
            let streakDays = GamificationService.currentStreak(userID: userID, context: context)
            scoreDelta = updateEstimatedScore(context: context, streakDays: streakDays)
        }

        // 대기 목록 초기화
        pendingVocab = []
        pendingGrammar = []

        AppLogger.session.info("Session ended — Words: \(self.stats.wordsStudied), Grammar: \(self.stats.grammarStudied), XP: \(self.stats.xpEarned), ScoreDelta: \(scoreDelta)")

        return scoreDelta
    }

    // MARK: - 단어 학습 기록 (메모리에만 저장)

    /// 단어 스와이프 결과를 기록합니다 (DB 반영은 endSession에서).
    func recordVocabularySwipe(
        vocabulary: Vocabulary,
        knewIt: Bool,
        responseTime: Double? = nil,
        context: ModelContext
    ) {
        // 대기 목록에 추가 (DB 미반영)
        pendingVocab.append(PendingVocabRecord(vocabulary: vocabulary, knewIt: knewIt, responseTime: responseTime))

        // 통계 업데이트
        stats.wordsStudied += 1
        if knewIt {
            stats.correctCount += 1
            stats.xpEarned += Self.xpPerVocabulary
        } else {
            stats.incorrectCount += 1
            // 모르는 단어: XP 없음
        }

        // 햅틱 피드백
        HapticManager.shared.playSwipeComplete()
    }

    // MARK: - 문법 퀴즈 기록 (메모리에만 저장)

    /// 문법 퀴즈 결과를 기록합니다 (DB 반영은 endSession에서).
    func recordGrammarQuiz(
        grammar: Grammar,
        isCorrect: Bool,
        isTimeout: Bool = false,
        responseTime: Double? = nil,
        context: ModelContext
    ) {
        // 대기 목록에 추가 (DB 미반영)
        pendingGrammar.append(PendingGrammarRecord(grammar: grammar, isCorrect: isCorrect, responseTime: responseTime, isTimeout: isTimeout))

        // 통계 업데이트
        stats.grammarStudied += 1
        if isCorrect {
            stats.correctCount += 1
            stats.xpEarned += Self.xpPerGrammarCorrect
        } else {
            stats.incorrectCount += 1
            // 오답: XP 없음
        }
    }

    // MARK: - Private Helpers

    // MARK: Quality Scoring

    /// 단어 카드 응답 품질 (0–5) 계산
    /// - knewIt=true + 빠름(≤5s)  → 5 (완벽히 기억)
    /// - knewIt=true + 보통(≤10s) → 4 (약간 망설임)
    /// - knewIt=true + 느림       → 3 (상당한 노력)
    /// - knewIt=false             → 1 (틀림)
    static func vocabQuality(knewIt: Bool, responseTime: Double?) -> Int {
        guard knewIt else { return 1 }
        guard let t = responseTime else { return 4 }  // 타이머 없으면 기본 4
        if t <= 5 { return 5 }
        if t <= 10 { return 4 }
        return 3
    }

    /// 문법 퀴즈 응답 품질 (0–5) 계산
    /// - timeout/모르겠다          → 0 (완전 모름)
    /// - 오답                     → 1 (틀림)
    /// - 정답 + 느림(>타이머50%)   → 3 (상당한 노력)
    /// - 정답 + 보통               → 4 (약간 망설임)
    /// - 정답 + 빠름(≤타이머50%)   → 5 (완벽히 기억)
    static func grammarQuality(isCorrect: Bool, isTimeout: Bool, responseTime: Double?, timerDuration: Double = 15) -> Int {
        if isTimeout { return 0 }
        guard isCorrect else { return 1 }
        guard let t = responseTime else { return 4 }
        let half = timerDuration * 0.5
        if t <= half { return 5 }
        if t <= timerDuration * 0.8 { return 4 }
        return 3
    }

    /// 오늘의 UserActivity를 가져오거나 생성하여 세션 결과를 누적합니다.
    private func saveUserActivity(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // 오늘 날짜의 기존 기록 검색
        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= today &&
            $0.activityDate < tomorrow
        }
        let descriptor = FetchDescriptor<UserActivity>(predicate: predicate)

        let activity: UserActivity
        do {
            let existing = try context.fetch(descriptor)
            if let found = existing.first {
                activity = found
            } else {
                activity = UserActivity(userID: userID, activityDate: today)
                context.insert(activity)
            }
        } catch {
            AppLogger.session.error("Failed to fetch UserActivity: \(error)")
            activity = UserActivity(userID: userID, activityDate: today)
            context.insert(activity)
        }

        // 세션 결과 누적 (하루에 여러 세션 가능)
        activity.wordsStudied += stats.wordsStudied
        activity.grammarStudied += stats.grammarStudied
        activity.studyDurationSeconds += stats.durationSeconds
        activity.quizTotal += stats.correctCount + stats.incorrectCount
        activity.quizCorrect += stats.correctCount
        activity.xpEarned += stats.xpEarned

        // 정답률 재계산
        if activity.quizTotal > 0 {
            activity.quizAccuracy = Double(activity.quizCorrect) / Double(activity.quizTotal)
        }

        // 일일 목표 달성 확인
        if activity.xpEarned >= Self.defaultDailyGoalXP {
            activity.dailyGoalMet = true
        }

        try? context.save()

        AppLogger.session.info("UserActivity updated — XP today: \(activity.xpEarned)")
    }

    // MARK: - 추정 점수 업데이트

    /// 세션 통계를 기반으로 UserProfile의 estimatedScore/estimatedLevel을 갱신합니다.
    /// - Returns: 실제 적용된 점수 변동값 (5의 배수)
    @discardableResult
    private func updateEstimatedScore(context: ModelContext, streakDays: Int) -> Int {
        // UserProfile 조회
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        guard let profile = try? context.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first else {
            return 0
        }

        let delta = GamificationService.calculateScoreDelta(
            accuracy: stats.accuracy,
            wordsStudied: stats.wordsStudied,
            grammarStudied: stats.grammarStudied,
            dailyVocabGoal: profile.dailyVocabGoal,
            dailyGrammarGoal: profile.dailyGrammarGoal,
            streakDays: streakDays
        )

        guard delta != 0 else { return 0 }

        let newScore = GamificationService.applyScoreDelta(
            currentScore: profile.estimatedScore,
            delta: delta,
            targetScore: profile.targetScore
        )
        profile.estimatedScore = newScore
        profile.estimatedLevel = GamificationService.estimatedLevel(fromScore: newScore)

        try? context.save()

        AppLogger.session.info("EstimatedScore updated: \(profile.estimatedScore - delta) → \(profile.estimatedScore) (delta: \(delta))")
        return delta
    }
}
