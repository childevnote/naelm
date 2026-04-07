//
//  LearningSessionManager.swift
//  Toeigo
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

    /// 문법 퀴즈 오답 시 XP (참여 보상)
    static let xpPerGrammarIncorrect: Int = 5

    /// 일일 기본 목표 XP
    static let defaultDailyGoalXP: Int = 100

    // MARK: - Pending Record (세션 종료 시 일괄 반영)

    /// 세션 중 기록된 단어 스와이프 결과 (DB 미반영 상태)
    struct PendingVocabRecord {
        let vocabulary: Vocabulary
        let knewIt: Bool
    }

    /// 세션 중 기록된 문법 퀴즈 결과 (DB 미반영 상태)
    struct PendingGrammarRecord {
        let grammar: Grammar
        let isCorrect: Bool
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
    func endSession(context: ModelContext) {
        guard isSessionActive else { return }
        isSessionActive = false

        // 대기 중인 단어 기록을 DB에 반영
        for record in pendingVocab {
            let quality = record.knewIt ? 4 : 1
            SpacedRepetitionService.recordVocabularyReview(
                vocabulary: record.vocabulary,
                quality: quality,
                userID: userID,
                context: context
            )
            if record.knewIt {
                let wordID = record.vocabulary.wordID
                let predicate = #Predicate<LearningProgress> {
                    $0.userID == userID &&
                    $0.itemType == "vocabulary" &&
                    $0.vocabulary?.wordID == wordID
                }
                if let progress = try? context.fetch(FetchDescriptor<LearningProgress>(predicate: predicate)).first {
                    progress.isMastered = true
                    progress.markedForReview = false
                }
            } else {
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
            let quality = record.isCorrect ? 4 : 1
            SpacedRepetitionService.recordGrammarReview(
                grammar: record.grammar,
                quality: quality,
                userID: userID,
                context: context
            )
            let grammarID = record.grammar.grammarID
            let predicate = #Predicate<LearningProgress> {
                $0.userID == userID &&
                $0.itemType == "grammar" &&
                $0.grammar?.grammarID == grammarID
            }
            if let progress = try? context.fetch(FetchDescriptor<LearningProgress>(predicate: predicate)).first {
                if record.isCorrect {
                    progress.isMastered = true
                    progress.markedForReview = false
                } else {
                    progress.markedForReview = true
                }
            }
        }

        // UserActivity에 오늘 학습 기록 저장
        saveUserActivity(context: context)

        // 대기 목록 초기화
        pendingVocab = []
        pendingGrammar = []

        AppLogger.session.info("Session ended — Words: \(self.stats.wordsStudied), Grammar: \(self.stats.grammarStudied), XP: \(self.stats.xpEarned)")
    }

    // MARK: - 단어 학습 기록 (메모리에만 저장)

    /// 단어 스와이프 결과를 기록합니다 (DB 반영은 endSession에서).
    func recordVocabularySwipe(
        vocabulary: Vocabulary,
        knewIt: Bool,
        context: ModelContext
    ) {
        // 대기 목록에 추가 (DB 미반영)
        pendingVocab.append(PendingVocabRecord(vocabulary: vocabulary, knewIt: knewIt))

        // 통계 업데이트
        stats.wordsStudied += 1
        if knewIt {
            stats.correctCount += 1
            stats.xpEarned += Self.xpPerVocabulary
        } else {
            stats.incorrectCount += 1
            // 모르는 단어도 참여 XP 부여 (절반)
            stats.xpEarned += Self.xpPerVocabulary / 2
        }

        // 햅틱 피드백
        HapticManager.shared.playSwipeComplete()
    }

    // MARK: - 문법 퀴즈 기록 (메모리에만 저장)

    /// 문법 퀴즈 결과를 기록합니다 (DB 반영은 endSession에서).
    func recordGrammarQuiz(
        grammar: Grammar,
        isCorrect: Bool,
        context: ModelContext
    ) {
        // 대기 목록에 추가 (DB 미반영)
        pendingGrammar.append(PendingGrammarRecord(grammar: grammar, isCorrect: isCorrect))

        // 통계 업데이트
        stats.grammarStudied += 1
        if isCorrect {
            stats.correctCount += 1
            stats.xpEarned += Self.xpPerGrammarCorrect
        } else {
            stats.incorrectCount += 1
            stats.xpEarned += Self.xpPerGrammarIncorrect
        }
    }

    // MARK: - Private Helpers

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
}
