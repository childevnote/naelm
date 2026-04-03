//
//  CardViewModel.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  단어 카드 학습 화면의 ViewModel.
//  ──────────────────────────────────────────────
//  역할:
//    1. 복습 대상 단어 + 새 단어를 혼합하여 카드 덱 구성
//    2. 스와이프 이벤트를 LearningSessionManager에 전달
//    3. 세션 상태 (진행 중/완료) 관리
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

@MainActor
@Observable
final class CardViewModel {

    // MARK: - State

    /// 현재 학습할 카드 덱
    var cardDeck: [Vocabulary] = []

    /// 세션 통계
    var sessionStats: SessionStats { sessionManager.stats }

    /// 세션 완료 여부
    var isSessionComplete: Bool = false

    /// 로딩 중 여부
    var isLoading: Bool = false

    /// 현재 선택된 난이도 (1=초급, 2=중급, 3=고급, 0=전체)
    var selectedDifficulty: Int = 0

    // MARK: - Dependencies

    private let sessionManager: LearningSessionManager

    // MARK: - Init

    init(sessionManager: LearningSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Load Deck

    /// 학습 카드 덱을 구성합니다.
    /// 복습 대상 + 새 단어를 합쳐 셔플합니다.
    func loadDeck(userID: String, context: ModelContext) {
        isLoading = true
        isSessionComplete = false

        // 1) 복습 대상 단어 (nextReviewDate <= 지금)
        let dueWords = SpacedRepetitionService.fetchDueVocabulary(
            userID: userID,
            context: context
        )

        // 2) 새 단어 (아직 학습 안 한 것)
        let newWordLimit = max(5, 10 - dueWords.count)
        let newWords = SpacedRepetitionService.fetchNewVocabulary(
            userID: userID,
            limit: newWordLimit,
            context: context
        )

        // 3) 합쳐서 셔플 (복습 대상 우선 + 새 단어 추가)
        var deck = dueWords + newWords

        // 4) SRS 기록이 없는 첫 실행 시 fallback — 직접 Vocabulary에서 가져옴
        if deck.isEmpty {
            let allDescriptor = FetchDescriptor<Vocabulary>(
                sortBy: [SortDescriptor(\.frequencyLevel)]
            )
            if let allVocab = try? context.fetch(allDescriptor) {
                deck = Array(allVocab.prefix(20))
            }
        }

        // 5) 난이도 필터링
        if selectedDifficulty > 0 {
            deck = deck.filter { $0.frequencyLevel == selectedDifficulty }
        }

        // 중복 제거 (wordID 기준)
        var seen = Set<String>()
        deck = deck.filter { word in
            guard !seen.contains(word.wordID) else { return false }
            seen.insert(word.wordID)
            return true
        }

        deck.shuffle()
        cardDeck = deck

        // 세션 시작
        sessionManager.startSession(userID: userID)

        isLoading = false
        print("📦 [CardVM] Deck loaded — Difficulty: \(selectedDifficulty == 0 ? "All" : "Lv.\(selectedDifficulty)"), Total: \(cardDeck.count)")
    }

    // MARK: - Handle Swipe

    /// 카드 스와이프를 처리합니다.
    /// left = 알고있어요 (숙달), right = 학습할게요 (복습 저장)
    func handleSwipe(
        vocabulary: Vocabulary,
        direction: SwipeDirection,
        context: ModelContext
    ) {
        let knewIt = direction == .left  // 왼쪽이 "알고있어요"
        sessionManager.recordVocabularySwipe(
            vocabulary: vocabulary,
            knewIt: knewIt,
            context: context
        )
    }

    // MARK: - Session Complete

    /// 모든 카드를 소진했을 때 호출됩니다.
    func handleAllCardsSwiped(context: ModelContext) {
        sessionManager.endSession(context: context)
        isSessionComplete = true
        HapticManager.shared.playCelebration()
    }
}
