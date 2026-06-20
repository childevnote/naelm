//
//  GamificationService.swift
//  Naelm
//
//  Created by 김동진 on 4/4/26.
//
//  게이미피케이션 서비스.
//  ──────────────────────────────────────────────
//  역할:
//    1. 연속 학습 스트릭 (streak) 계산
//    2. 일일 XP 집계 및 목표 달성 판정
//    3. 7일간 학습 활동 히스토리 제공
//    4. 레벨 시스템 (XP → 레벨 변환)
//    5. 세션 결과 기반 추정 점수 변동 계산 (5점 단위)
//  ──────────────────────────────────────────────

import Foundation
import SwiftData
import os

// MARK: - Daily Summary

/// 하루의 학습 요약 데이터 (대시보드 차트용).
struct DailySummary: Identifiable {
    var id: Date { date }
    let date: Date
    let xpEarned: Int
    let wordsStudied: Int
    let grammarStudied: Int
    let goalMet: Bool
    let studyDurationSeconds: Int

    /// 요일 약자 (월, 화, 수...) — DateFormatter를 캐싱하여 성능 최적화
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f
    }()

    var weekdayShort: String {
        Self.weekdayFormatter.string(from: date)
    }
}

// MARK: - GamificationService

@MainActor
final class GamificationService {

    // MARK: - 레벨 시스템

    /// 누적 XP에서 레벨 계산 (레벨당 필요 XP가 점진적으로 증가)
    static func level(fromTotalXP xp: Int) -> Int {
        var level = 0
        var requiredXP = 0
        while requiredXP <= xp {
            level += 1
            requiredXP += level * 100
        }
        return max(1, level)
    }

    /// 현재 레벨에서 다음 레벨까지의 진행도 (0.0 ~ 1.0)
    static func levelProgress(fromTotalXP xp: Int) -> Double {
        let currentLevel = level(fromTotalXP: xp)
        var xpForCurrentLevel = 0
        for i in 1..<currentLevel {
            xpForCurrentLevel += i * 100
        }
        let xpNeeded = currentLevel * 100
        let xpInLevel = xp - xpForCurrentLevel
        return min(1.0, Double(xpInLevel) / Double(xpNeeded))
    }

    /// 다음 레벨까지 남은 XP
    static func xpToNextLevel(fromTotalXP xp: Int) -> Int {
        let currentLevel = level(fromTotalXP: xp)
        var xpForNextLevel = 0
        for i in 1...currentLevel {
            xpForNextLevel += i * 100
        }
        return max(0, xpForNextLevel - xp)
    }

    // MARK: - 스트릭 계산

    static func currentStreak(
        userID: String,
        context: ModelContext
    ) -> Int {
        var descriptor = FetchDescriptor<UserActivity>(
            predicate: #Predicate<UserActivity> { $0.userID == userID },
            sortBy: [SortDescriptor(\.activityDate, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\UserActivity.activityDate, \UserActivity.dailyGoalMet]

        do {
            let activities = try context.fetch(descriptor)
            guard !activities.isEmpty else { return 0 }

            var streak = 0
            let calendar = Calendar.current
            var expectedDate = calendar.startOfDay(for: Date())

            for activity in activities {
                let activityDay = calendar.startOfDay(for: activity.activityDate)

                if activityDay == expectedDate {
                    if activity.dailyGoalMet {
                        streak += 1
                        guard let prev = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { break }
                        expectedDate = prev
                    } else {
                        if activityDay == calendar.startOfDay(for: Date()) {
                            guard let prev = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { break }
                            expectedDate = prev
                            continue
                        }
                        break
                    }
                } else if activityDay < expectedDate {
                    break
                }
            }

            return streak
        } catch {
            AppLogger.session.error("Failed to calculate streak: \(error)")
            return 0
        }
    }

    // MARK: - 누적 XP

    static func totalXP(
        userID: String,
        context: ModelContext
    ) -> Int {
        var descriptor = FetchDescriptor<UserActivity>(
            predicate: #Predicate<UserActivity> { $0.userID == userID }
        )
        descriptor.propertiesToFetch = [\UserActivity.xpEarned]

        do {
            let activities = try context.fetch(descriptor)
            return activities.reduce(0) { $0 + $1.xpEarned }
        } catch {
            AppLogger.session.error("Failed to calculate total XP: \(error)")
            return 0
        }
    }

    // MARK: - 오늘 XP

    static func todayXP(
        userID: String,
        context: ModelContext
    ) -> Int {
        guard let activity = todayActivity(userID: userID, context: context) else { return 0 }
        return activity.xpEarned
    }

    // MARK: - 오늘 활동

    static func todayActivity(
        userID: String,
        context: ModelContext
    ) -> UserActivity? {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= today &&
            $0.activityDate < tomorrow
        }
        let descriptor = FetchDescriptor<UserActivity>(predicate: predicate)

        do {
            return try context.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    // MARK: - 7일 히스토리

    static func weeklyHistory(
        userID: String,
        context: ModelContext
    ) -> [DailySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let dates: [Date] = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }

        guard let sevenDaysAgo = dates.first,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= sevenDaysAgo &&
            $0.activityDate < tomorrow
        }
        let descriptor = FetchDescriptor<UserActivity>(predicate: predicate)

        let activities: [UserActivity]
        do {
            activities = try context.fetch(descriptor)
        } catch {
            activities = []
        }

        let activityByDate = Dictionary(
            grouping: activities,
            by: { calendar.startOfDay(for: $0.activityDate) }
        )

        return dates.map { date in
            if let activity = activityByDate[date]?.first {
                return DailySummary(
                    date: date,
                    xpEarned: activity.xpEarned,
                    wordsStudied: activity.wordsStudied,
                    grammarStudied: activity.grammarStudied,
                    goalMet: activity.dailyGoalMet,
                    studyDurationSeconds: activity.studyDurationSeconds
                )
            } else {
                return DailySummary(
                    date: date,
                    xpEarned: 0,
                    wordsStudied: 0,
                    grammarStudied: 0,
                    goalMet: false,
                    studyDurationSeconds: 0
                )
            }
        }
    }

    // MARK: - 복습 대상 수

    static func dueItemCount(
        userID: String,
        context: ModelContext
    ) -> Int {
        let now = Date()
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID &&
            $0.nextReviewDate <= now &&
            $0.isMastered == false
        }
        let descriptor = FetchDescriptor<LearningProgress>(predicate: predicate)

        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    // MARK: - 숙달 통계

    static func masteredVocabularyCount(
        userID: String,
        context: ModelContext
    ) -> Int {
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID &&
            $0.itemType == "vocabulary" &&
            $0.isMastered == true
        }
        let descriptor = FetchDescriptor<LearningProgress>(predicate: predicate)

        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    static func masteredGrammarCount(
        userID: String,
        context: ModelContext
    ) -> Int {
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID &&
            $0.itemType == "grammar" &&
            $0.isMastered == true
        }
        let descriptor = FetchDescriptor<LearningProgress>(predicate: predicate)

        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    // MARK: - 추정 점수 증감 계산 (5점 단위)

    /// 세션 결과를 바탕으로 TOEIC 추정 점수 변동값을 계산합니다. (Pure Function)
    ///
    /// goalRatio는 세션 유형별 독립 계산 후 평균:
    ///   - 문법만 완료 → grammarGoal 기준 (10/10 = 100%)
    ///   - 단어만 완료 → vocabGoal 기준 (20/20 = 100%)
    ///
    /// - Parameters:
    ///   - accuracy: 세션 정답률 (0.0 ~ 1.0)
    ///   - wordsStudied: 이번 세션 단어 학습 수
    ///   - grammarStudied: 이번 세션 문법 학습 수
    ///   - dailyVocabGoal: 단어 일일 목표
    ///   - dailyGrammarGoal: 문법 일일 목표
    ///   - streakDays: 현재 연속 학습 일수
    /// - Returns: 점수 변동값 (음수 가능, 항상 5의 배수)
    static func calculateScoreDelta(
        accuracy: Double,
        wordsStudied: Int,
        grammarStudied: Int,
        dailyVocabGoal: Int,
        dailyGrammarGoal: Int,
        streakDays: Int
    ) -> Int {
        var ratioSum = 0.0
        var ratioCount = 0

        if wordsStudied > 0 && dailyVocabGoal > 0 {
            ratioSum += Double(wordsStudied) / Double(dailyVocabGoal)
            ratioCount += 1
        }
        if grammarStudied > 0 && dailyGrammarGoal > 0 {
            ratioSum += Double(grammarStudied) / Double(dailyGrammarGoal)
            ratioCount += 1
        }
        guard ratioCount > 0 else { return 0 }

        let goalRatio = ratioSum / Double(ratioCount)

        // if-else 방식 (Swift 튜플 switch Double 범위 매칭 불안정 방지)
        if accuracy >= 0.8 && goalRatio >= 1.0 {
            return streakDays >= 7 ? 15 : 10
        } else if accuracy >= 0.8 && goalRatio >= 0.5 {
            return 5
        } else if accuracy >= 0.6 && goalRatio >= 0.5 {
            return 5
        } else if accuracy < 0.4 {
            return -10
        } else if accuracy < 0.6 && goalRatio >= 1.0 {
            return -5
        } else {
            return 0
        }
    }

    /// `calculateScoreDelta`의 결과를 현재 estimatedScore에 반영합니다.
    static func applyScoreDelta(
        currentScore: Int,
        delta: Int,
        targetScore: Int
    ) -> Int {
        let raw = currentScore + delta
        let aligned = (raw / 5) * 5
        return max(0, min(aligned, targetScore))
    }

    /// 누적 추정 점수 → estimatedLevel (0~5) 변환
    static func estimatedLevel(fromScore score: Int) -> Int {
        if score <= 0   { return 0 }
        if score < 600  { return 1 }
        if score < 700  { return 2 }
        if score < 800  { return 3 }
        if score < 900  { return 4 }
        return 5
    }

    /// 레벨에 따른 기본 추정 점수 반환
    static func defaultScore(forLevel level: Int) -> Int {
        switch level {
        case 1: return 550
        case 2: return 600
        case 3: return 700
        case 4: return 800
        case 5: return 900
        default: return 500
        }
    }
}
