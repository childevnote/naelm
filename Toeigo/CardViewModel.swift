//
//  CardViewModel.swift
//  Toeigo
//
//  단어 카드 학습 화면의 ViewModel.
//  ──────────────────────────────────────────────
//  역할:
//    1. 사용자 목표 점수에 맞는 단어로 카드 덱 구성
//    2. 스와이프 이벤트를 LearningSessionManager에 전달
//    3. 15초 타이머 관리 (시간 초과 → 자동 "학습할게요")
//    4. 오늘 학습한 단어 수 추적
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

@MainActor
@Observable
final class CardViewModel {

    // MARK: - State

    var cardDeck: [Vocabulary] = []
    var sessionStats: SessionStats { sessionManager.stats }
    var isSessionComplete: Bool = false
    var isLoading: Bool = false

    /// 오늘 학습한 단어 수 (전체 세션 합산)
    var todayWordCount: Int = 0
    /// 오늘 목표 단어 수
    var dailyGoal: Int = 20
    /// 사용자 목표 점수
    var targetScore: Int = 700

    /// 15초 카드 타이머
    var timerRemaining: Double = 15.0
    var isTimerRunning: Bool = false

    /// 목표 점수에 따른 제한 시간 (600→15, 700→12, 800→9, 900→6)
    var timerDuration: Double {
        switch targetScore {
        case ..<700: return 15.0
        case 700..<800: return 12.0
        case 800..<900: return 9.0
        default: return 6.0
        }
    }

    // MARK: - Dependencies

    private let sessionManager: LearningSessionManager
    private var timer: Timer?

    init(sessionManager: LearningSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Load Deck

    func loadDeck(userID: String, context: ModelContext) {
        isLoading = true
        isSessionComplete = false

        // 1) 사용자 프로필에서 목표 점수 & 일일 목표 로드
        loadUserProfile(userID: userID, context: context)

        // 2) 목표 점수에 맞는 frequencyLevel 범위
        let targetLevels = TOEICScoreRange.frequencyLevels(forTarget: targetScore)

        // 3) 복습 대상 단어
        let dueWords = SpacedRepetitionService.fetchDueVocabulary(
            userID: userID,
            context: context
        )

        // 4) 새 단어
        let newWordLimit = max(5, 15 - dueWords.count)
        let newWords = SpacedRepetitionService.fetchNewVocabulary(
            userID: userID,
            limit: newWordLimit,
            context: context
        )

        // 5) 합쳐서 목표 점수에 맞는 것만 필터
        var deck = (dueWords + newWords).filter { vocab in
            targetLevels.isEmpty || targetLevels.contains(vocab.frequencyLevel)
        }

        // 6) Fallback
        if deck.isEmpty {
            let allDescriptor = FetchDescriptor<Vocabulary>(
                sortBy: [SortDescriptor(\.frequencyLevel)]
            )
            if let allVocab = try? context.fetch(allDescriptor) {
                deck = allVocab.filter { targetLevels.isEmpty || targetLevels.contains($0.frequencyLevel) }
                if deck.isEmpty { deck = Array(allVocab.prefix(20)) }
                else { deck = Array(deck.prefix(20)) }
            }
        }

        // 중복 제거
        var seen = Set<String>()
        deck = deck.filter { seen.insert($0.wordID).inserted }
        deck.shuffle()
        // 세션 크기를 dailyGoal에 맞춤 (매 세션마다 일정 수 학습)
        cardDeck = Array(deck.prefix(dailyGoal))

        // 오늘 학습 카운트 로드
        loadTodayCount(userID: userID, context: context)

        sessionManager.startSession(userID: userID)
        isLoading = false
        startTimer()
    }

    // MARK: - Handle Swipe

    func handleSwipe(vocabulary: Vocabulary, direction: SwipeDirection, context: ModelContext) {
        let knewIt = direction == .left  // 왼쪽 = "알고있어요"
        sessionManager.recordVocabularySwipe(
            vocabulary: vocabulary,
            knewIt: knewIt,
            context: context
        )

        // "학습할게요" → markedForReview 설정
        if !knewIt {
            markForReview(vocabulary: vocabulary, userID: sessionManager.userID, context: context)
        }

        todayWordCount += 1
        resetTimer()
    }

    func handleAllCardsSwiped(context: ModelContext) {
        sessionManager.endSession(context: context)
        isSessionComplete = true
        stopTimer()
        HapticManager.shared.playCelebration()
    }

    // MARK: - Timer

    func startTimer() {
        timerRemaining = timerDuration
        isTimerRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isTimerRunning else { return }
                self.timerRemaining -= 0.1
                if self.timerRemaining <= 0 {
                    self.timerExpired()
                }
            }
        }
    }

    func resetTimer() {
        timerRemaining = timerDuration
    }

    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// 타이머 만료 콜백
    var onTimerExpired: (() -> Void)?

    private func timerExpired() {
        HapticManager.shared.playIncorrect()
        onTimerExpired?()
    }

    // MARK: - Private

    private func loadUserProfile(userID: String, context: ModelContext) {
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        if let profile = try? context.fetch(descriptor).first {
            targetScore = profile.targetScore
            dailyGoal = profile.dailyVocabGoal
        }
    }

    private func loadTodayCount(userID: String, context: ModelContext) {
        if let activity = GamificationService.todayActivity(userID: userID, context: context) {
            todayWordCount = activity.wordsStudied
        } else {
            todayWordCount = 0
        }
    }

    private func markForReview(vocabulary: Vocabulary, userID: String, context: ModelContext) {
        let wordID = vocabulary.wordID
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID &&
            $0.itemType == "vocabulary" &&
            $0.vocabulary?.wordID == wordID
        }
        let descriptor = FetchDescriptor<LearningProgress>(predicate: predicate)
        if let progress = try? context.fetch(descriptor).first {
            progress.markedForReview = true
        }
    }
}
