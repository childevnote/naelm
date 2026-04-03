//
//  SpacedRepetitionService.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  SM-2 간격 반복 알고리즘 구현.
//  ──────────────────────────────────────────────
//  SM-2 (SuperMemo 2) 알고리즘:
//    • quality 0–5 등급으로 사용자 응답 품질을 평가
//    • easeFactor (난이도 계수)를 조정하여 개인별 복습 간격 최적화
//    • quality < 3 이면 처음부터 다시 학습 (interval = 0)
//    • quality ≥ 3 이면 간격을 점진적으로 늘림
//
//  참고: https://en.wikipedia.org/wiki/SuperMemo#Description_of_SM-2_algorithm
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

// MARK: - SM-2 Algorithm Result

/// SM-2 알고리즘 계산 결과를 담는 구조체.
/// 순수 함수의 반환값으로 사용되어, 사이드이펙트 없이 테스트 가능합니다.
struct SM2Result {
    let interval: Int           // 다음 복습까지의 간격 (일)
    let repetitions: Int        // 연속 정답 반복 횟수
    let easeFactor: Double      // 난이도 계수 (최소 1.3)
    let nextReviewDate: Date    // 다음 복습 예정일
}

// MARK: - SpacedRepetitionService

/// SM-2 기반 간격 반복 학습 서비스.
/// 순수 함수 + SwiftData 연동 헬퍼로 구성됩니다.
@MainActor
final class SpacedRepetitionService {

    // MARK: - 순수 함수: SM-2 계산

    /// SM-2 알고리즘 핵심 계산 (순수 함수 — 사이드이펙트 없음).
    ///
    /// - Parameters:
    ///   - quality: 사용자 응답 품질 (0–5)
    ///     - 0: 완전 모름 (blackout)
    ///     - 1: 틀림, 보고 나서 기억남
    ///     - 2: 틀림, 쉽게 떠오름
    ///     - 3: 맞음, 상당한 노력 필요
    ///     - 4: 맞음, 약간의 망설임
    ///     - 5: 완벽히 기억
    ///   - currentInterval: 현재 복습 간격 (일)
    ///   - currentRepetitions: 현재 연속 정답 횟수
    ///   - currentEaseFactor: 현재 난이도 계수
    /// - Returns: 새로운 SM2Result
    static func calculate(
        quality: Int,
        currentInterval: Int,
        currentRepetitions: Int,
        currentEaseFactor: Double
    ) -> SM2Result {
        // quality를 0–5 범위로 클램핑
        let q = min(max(quality, 0), 5)

        var newInterval: Int
        var newRepetitions: Int
        var newEaseFactor: Double

        if q < 3 {
            // ── 실패: 처음부터 다시 ──
            // 틀리면 간격을 리셋하고 바로 다시 복습
            newInterval = 0
            newRepetitions = 0
            newEaseFactor = currentEaseFactor
        } else {
            // ── 성공: 간격 증가 ──
            newRepetitions = currentRepetitions + 1

            switch newRepetitions {
            case 1:
                // 첫 번째 정답 → 1일 후 복습
                newInterval = 1
            case 2:
                // 두 번째 정답 → 6일 후 복습
                newInterval = 6
            default:
                // 세 번째 이후 → 이전 간격 × easeFactor
                newInterval = Int(round(Double(currentInterval) * currentEaseFactor))
                // 최소 간격 보장
                newInterval = max(newInterval, 1)
            }

            // ── easeFactor 업데이트 ──
            // EF' = EF + (0.1 - (5-q) × (0.08 + (5-q) × 0.02))
            let qDouble = Double(q)
            newEaseFactor = currentEaseFactor + (0.1 - (5.0 - qDouble) * (0.08 + (5.0 - qDouble) * 0.02))

            // easeFactor 최소값: 1.3 (너무 낮으면 간격이 줄어들지 않음)
            newEaseFactor = max(newEaseFactor, 1.3)
        }

        // 다음 복습 날짜 계산
        let nextDate: Date
        if newInterval == 0 {
            // 실패한 경우: 10분 후 재복습 (같은 세션 내)
            nextDate = Date().addingTimeInterval(10 * 60)
        } else {
            nextDate = Calendar.current.date(
                byAdding: .day,
                value: newInterval,
                to: Date()
            ) ?? Date()
        }

        return SM2Result(
            interval: newInterval,
            repetitions: newRepetitions,
            easeFactor: newEaseFactor,
            nextReviewDate: nextDate
        )
    }

    // MARK: - SwiftData 연동: 복습 기록

    /// 단어 학습 결과를 기록합니다.
    /// 기존 LearningProgress가 있으면 업데이트, 없으면 새로 생성합니다.
    ///
    /// - Parameters:
    ///   - vocabulary: 학습한 단어
    ///   - quality: 응답 품질 (0–5)
    ///   - userID: 현재 사용자 ID
    ///   - context: SwiftData ModelContext
    static func recordVocabularyReview(
        vocabulary: Vocabulary,
        quality: Int,
        userID: String,
        context: ModelContext
    ) {
        // 기존 진행 기록 조회
        let wordID = vocabulary.wordID
        let progress = fetchOrCreateProgress(
            userID: userID,
            itemType: "vocabulary",
            wordID: wordID,
            vocabulary: vocabulary,
            grammar: nil,
            context: context
        )

        // SM-2 계산
        let result = calculate(
            quality: quality,
            currentInterval: progress.interval,
            currentRepetitions: progress.repetitions,
            currentEaseFactor: progress.easeFactor
        )

        // 결과 반영
        applyResult(result, to: progress, quality: quality)
    }

    /// 문법 학습 결과를 기록합니다.
    static func recordGrammarReview(
        grammar: Grammar,
        quality: Int,
        userID: String,
        context: ModelContext
    ) {
        let grammarID = grammar.grammarID
        let progress = fetchOrCreateProgress(
            userID: userID,
            itemType: "grammar",
            wordID: nil,
            vocabulary: nil,
            grammar: grammar,
            grammarID: grammarID,
            context: context
        )

        let result = calculate(
            quality: quality,
            currentInterval: progress.interval,
            currentRepetitions: progress.repetitions,
            currentEaseFactor: progress.easeFactor
        )

        applyResult(result, to: progress, quality: quality)
    }

    // MARK: - 복습 대상 조회

    /// 오늘 복습해야 할 단어 목록을 반환합니다.
    static func fetchDueVocabulary(
        userID: String,
        context: ModelContext
    ) -> [Vocabulary] {
        let now = Date()
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID &&
            $0.itemType == "vocabulary" &&
            $0.nextReviewDate <= now &&
            $0.isMastered == false
        }
        let descriptor = FetchDescriptor<LearningProgress>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )

        do {
            let progresses = try context.fetch(descriptor)
            return progresses.compactMap(\.vocabulary)
        } catch {
            print("❌ [SRS] Failed to fetch due vocabulary: \(error)")
            return []
        }
    }

    /// 오늘 복습해야 할 문법 목록을 반환합니다.
    static func fetchDueGrammar(
        userID: String,
        context: ModelContext
    ) -> [Grammar] {
        let now = Date()
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID &&
            $0.itemType == "grammar" &&
            $0.nextReviewDate <= now &&
            $0.isMastered == false
        }
        let descriptor = FetchDescriptor<LearningProgress>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )

        do {
            let progresses = try context.fetch(descriptor)
            return progresses.compactMap(\.grammar)
        } catch {
            print("❌ [SRS] Failed to fetch due grammar: \(error)")
            return []
        }
    }

    /// 아직 한 번도 학습하지 않은 새 단어 목록을 반환합니다.
    static func fetchNewVocabulary(
        userID: String,
        limit: Int = 10,
        context: ModelContext
    ) -> [Vocabulary] {
        // 이미 학습 기록이 있는 단어 ID 수집
        let existingPredicate = #Predicate<LearningProgress> {
            $0.userID == userID && $0.itemType == "vocabulary"
        }
        let existingDescriptor = FetchDescriptor<LearningProgress>(predicate: existingPredicate)

        do {
            let existingProgresses = try context.fetch(existingDescriptor)
            let studiedWordIDs = Set(existingProgresses.compactMap { $0.vocabulary?.wordID })

            // 전체 단어에서 학습하지 않은 것만 필터링
            var allDescriptor = FetchDescriptor<Vocabulary>(
                sortBy: [SortDescriptor(\.frequencyLevel)]
            )
            allDescriptor.fetchLimit = limit + studiedWordIDs.count

            let allVocab = try context.fetch(allDescriptor)
            let newVocab = allVocab.filter { !studiedWordIDs.contains($0.wordID) }
            return Array(newVocab.prefix(limit))
        } catch {
            print("❌ [SRS] Failed to fetch new vocabulary: \(error)")
            return []
        }
    }

    // MARK: - Private Helpers

    /// 기존 LearningProgress를 조회하거나, 없으면 새로 생성합니다.
    private static func fetchOrCreateProgress(
        userID: String,
        itemType: String,
        wordID: String? = nil,
        vocabulary: Vocabulary? = nil,
        grammar: Grammar? = nil,
        grammarID: String? = nil,
        context: ModelContext
    ) -> LearningProgress {
        // 기존 기록 검색
        let predicate: Predicate<LearningProgress>

        if itemType == "vocabulary", let wid = wordID {
            predicate = #Predicate<LearningProgress> {
                $0.userID == userID &&
                $0.itemType == "vocabulary" &&
                $0.vocabulary?.wordID == wid
            }
        } else if itemType == "grammar", let gid = grammarID {
            predicate = #Predicate<LearningProgress> {
                $0.userID == userID &&
                $0.itemType == "grammar" &&
                $0.grammar?.grammarID == gid
            }
        } else {
            // Fallback: 새로 생성
            let newProgress = LearningProgress(
                userID: userID,
                itemType: itemType,
                vocabulary: vocabulary,
                grammar: grammar
            )
            context.insert(newProgress)
            return newProgress
        }

        let descriptor = FetchDescriptor<LearningProgress>(predicate: predicate)

        do {
            let results = try context.fetch(descriptor)
            if let existing = results.first {
                return existing
            }
        } catch {
            print("⚠️ [SRS] Fetch error: \(error)")
        }

        // 기존 기록 없음 → 새로 생성
        let newProgress = LearningProgress(
            userID: userID,
            itemType: itemType,
            vocabulary: vocabulary,
            grammar: grammar
        )
        context.insert(newProgress)
        return newProgress
    }

    /// SM2Result를 LearningProgress에 적용합니다.
    private static func applyResult(
        _ result: SM2Result,
        to progress: LearningProgress,
        quality: Int
    ) {
        progress.interval = result.interval
        progress.repetitions = result.repetitions
        progress.easeFactor = result.easeFactor
        progress.nextReviewDate = result.nextReviewDate
        progress.lastReviewedAt = Date()

        // 통계 업데이트
        if quality >= 3 {
            progress.correctCount += 1
            progress.streak += 1
        } else {
            progress.incorrectCount += 1
            progress.streak = 0
        }

        // 숙달 판정: 연속 5회 이상 정답 + easeFactor 2.5 이상
        if progress.streak >= 5 && progress.easeFactor >= 2.5 {
            progress.isMastered = true
        }
    }
}
