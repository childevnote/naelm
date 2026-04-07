//
//  GamificationService.swift
//  Toeigo
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

    /// 요일 약자 (월, 화, 수...)
    var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// MARK: - GamificationService

@MainActor
final class GamificationService {

    // MARK: - 레벨 시스템

    /// 누적 XP에서 레벨 계산 (레벨당 필요 XP가 점진적으로 증가)
    static func level(fromTotalXP xp: Int) -> Int {
        // 레벨 n → n × 100 XP 필요
        // 누적: 100, 300, 600, 1000, ...
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
        // 현재 레벨 시작에 필요한 누적 XP
        var xpForCurrentLevel = 0
        for i in 1..<currentLevel {
            xpForCurrentLevel += i * 100
        }
        // 다음 레벨에 필요한 XP
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

    /// 현재 연속 학습 일수 (스트릭) 계산.
    /// 오늘부터 거꾸로 연속으로 dailyGoalMet == true인 날을 카운트합니다.
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
                        expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
                    } else {
                        // 오늘이면 아직 진행 중이므로 건너뜀
                        if activityDay == calendar.startOfDay(for: Date()) {
                            expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
                            continue
                        }
                        break
                    }
                } else if activityDay < expectedDate {
                    // 날짜 갭 → 스트릭 종료
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

    /// 사용자의 전체 누적 XP를 계산합니다.
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

    /// 오늘 획득한 XP.
    static func todayXP(
        userID: String,
        context: ModelContext
    ) -> Int {
        guard let activity = todayActivity(userID: userID, context: context) else {
            return 0
        }
        return activity.xpEarned
    }

    // MARK: - 오늘 활동

    /// 오늘의 UserActivity를 가져옵니다.
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

    /// 최근 7일간의 학습 활동 요약.
    /// 활동이 없는 날은 빈 DailySummary로 채워 항상 7개를 반환합니다.
    static func weeklyHistory(
        userID: String,
        context: ModelContext
    ) -> [DailySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 7일 전부터 오늘까지의 날짜 목록
        var dates: [Date] = []
        for i in (0..<7).reversed() {
            dates.append(calendar.date(byAdding: .day, value: -i, to: today)!)
        }

        // 7일간의 활동 조회
        let sevenDaysAgo = dates.first!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

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

        // 날짜별 매핑
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

    /// 오늘 복습해야 할 항목 수.
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

    /// 숙달한 단어 수.
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

    /// 숙달한 문법 수.
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
}
