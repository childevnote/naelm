//
//  CardViewModel.swift
//  Naelm
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
var sessionStats: SessionStats = SessionStats()
var isSessionComplete: Bool = false
/// 마지막 endSession 후 변동된 추정 점수 (5의 배수, View → LessonResult 전달용)
var lastScoreDelta: Int = 0
var isLoading: Bool = false

/// 오늘 학습한 단어 수 (전체 세션 합산)
var todayWordCount: Int = 0
/// 오늘 목표 단어 수
var dailyGoal: Int = 20
/// 사용자 목표 점수
var targetScore: Int = 700
/// 사용자 추정 수준 (frequencyLevel 1~5)
var estimatedLevel: Int = 2

    /// 15초 카드 타이머
    var timerRemaining: Double = 15.0
    var isTimerRunning: Bool = false

    /// 타이머 기능 활성화 여부 (프로필에서 로드)
    var timerEnabled: Bool = true
    /// 프로필에서 설정한 커스텀 타이머 시간 (초)
    var customTimerSeconds: Int = 15

    /// 제한 시간 — 프로필 커스텀 설정 우선, 없으면 목표 점수 기반
    var timerDuration: Double { Double(customTimerSeconds) }

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

    // 1) 사용자 프로필에서 목표 점수 & 일일 목표 & 수준 로드
    loadUserProfile(userID: userID, context: context)

    // 2) 이미 숙달한 단어 ID 가져오기
    let masteredPred = #Predicate<LearningProgress> {
        $0.userID == userID && $0.itemType == "vocabulary" && $0.isMastered == true
    }
    let masteredIDs = Set((try? context.fetch(FetchDescriptor<LearningProgress>(predicate: masteredPred)))?.compactMap { $0.vocabulary?.wordID } ?? [])

    // 3) 전체 비숙달 단어 가져오기
    var allDescriptor = FetchDescriptor<Vocabulary>(sortBy: [SortDescriptor(\.frequencyLevel)])
    allDescriptor.fetchLimit = dailyGoal * 10
    let allVocab = (try? context.fetch(allDescriptor))?.filter { !masteredIDs.contains($0.wordID) } ?? []

    let currentLevelFreq = max(1, estimatedLevel)
    let targetLevels = TOEICScoreRange.frequencyLevels(forTarget: targetScore)

    // ── 4) SRS 복습 대상 우선 편입 (최대 50%) ──
    let srsReview = SpacedRepetitionService.fetchDueVocabulary(userID: userID, context: context)
        .filter { !masteredIDs.contains($0.wordID) }
    let srsSlot = min(srsReview.count, dailyGoal / 2)
    let srsItems = Array(srsReview.prefix(srsSlot))
    let srsIDs = Set(srsItems.map(\.wordID))

    // ── 5) 워밍업 구간 (첫 2~3문제: 현재 수준보다 낮거나 streak≥3 항목) ──
    // streak 정보를 조회하여 쉬운 항목 선별
    let warmupLevelFreq = max(1, currentLevelFreq - 1)
    let warmupCandidates = allVocab.filter {
        !srsIDs.contains($0.wordID) && $0.frequencyLevel <= warmupLevelFreq
    }.shuffled()
    let warmupCount = min(2, warmupCandidates.count)
    let warmupItems = Array(warmupCandidates.prefix(warmupCount))
    let warmupIDs = Set(warmupItems.map(\.wordID))

    // ── 6) 메인 덱 (40%/60%) ──
    let remainSlot = dailyGoal - srsSlot - warmupCount
    let currentLevelWords = allVocab.filter {
        $0.frequencyLevel == currentLevelFreq && !srsIDs.contains($0.wordID) && !warmupIDs.contains($0.wordID)
    }.shuffled()
    let targetLevelWords = allVocab.filter {
        targetLevels.contains($0.frequencyLevel) && $0.frequencyLevel != currentLevelFreq
        && !srsIDs.contains($0.wordID) && !warmupIDs.contains($0.wordID)
    }.shuffled()

    let currentCount = max(1, Int(Double(remainSlot) * 0.4))
    let targetCount = remainSlot - currentCount

    var mainDeck: [Vocabulary] = []
    mainDeck += Array(currentLevelWords.prefix(currentCount))
    mainDeck += Array(targetLevelWords.prefix(targetCount))

    // 부족분 보충
    if mainDeck.count < remainSlot {
        let existing = Set(mainDeck.map(\.wordID)).union(srsIDs).union(warmupIDs)
        let more = allVocab.filter { !existing.contains($0.wordID) }.shuffled()
        mainDeck += Array(more.prefix(remainSlot - mainDeck.count))
    }

    // ── 최종 조립: 워밍업 → SRS 복습 → 메인 ──
    var deck: [Vocabulary] = warmupItems + srsItems + mainDeck

    // 중복 제거
    var seen = Set<String>()
    deck = deck.filter { seen.insert($0.wordID).inserted }
    cardDeck = Array(deck.prefix(dailyGoal))

    // 오늘 학습 카운트 로드
    loadTodayCount(userID: userID, context: context)

    sessionManager.startSession(userID: userID)
    sessionStats = sessionManager.stats
    isLoading = false
    startTimer()
}

// MARK: - Handle Swipe

func handleSwipe(vocabulary: Vocabulary, direction: SwipeDirection, context: ModelContext) {
    let knewIt = direction == .left  // 왼쪽 = "알고있어요"
    // 타이머에서 경과 시간 계산 (응답시간 = 전체 타이머 - 남은 시간)
    let elapsed = timerEnabled ? (timerDuration - max(0, timerRemaining)) : nil
    sessionManager.recordVocabularySwipe(
        vocabulary: vocabulary,
        knewIt: knewIt,
        responseTime: elapsed,
        context: context
    )

    todayWordCount += 1

    // sessionManager 통계를 동기화
    sessionStats = sessionManager.stats

    // 마지막 카드가 아닐 때: 타이머를 새로 시작 (pauseTimer 상태에서 스와이프한 경우도 포함)
    let swipedCount = sessionStats.wordsStudied
    if swipedCount < cardDeck.count {
        startTimer()
    }
}

func handleAllCardsSwiped(context: ModelContext) {
    lastScoreDelta = sessionManager.endSession(context: context, isVocabularyOnly: true)
    sessionStats = sessionManager.stats
    isSessionComplete = true
    stopTimer()
    timerRemaining = 0
    HapticManager.shared.playCelebration()
}

/// 복습 대기 단어가 있는지 체크
func hasReviewWords(context: ModelContext) -> Bool {
    let userID = sessionManager.userID
    let predicate = #Predicate<LearningProgress> {
        $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "vocabulary"
    }
    return ((try? context.fetchCount(FetchDescriptor<LearningProgress>(predicate: predicate))) ?? 0) > 0
}

/// 복습 대기 단어로 덱 구성
func loadReviewDeck(context: ModelContext) {
    isSessionComplete = false
    let userID = sessionManager.userID
    let predicate = #Predicate<LearningProgress> {
        $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "vocabulary"
    }
    let progresses = (try? context.fetch(FetchDescriptor<LearningProgress>(predicate: predicate))) ?? []
    var deck = progresses.compactMap(\.vocabulary).shuffled()
    deck = Array(deck.prefix(dailyGoal))
    cardDeck = deck
    sessionManager.startSession(userID: userID)
    sessionStats = sessionManager.stats
    startTimer()
}

// MARK: - Timer
    // ARCH FIX: Timer closure now uses Task @MainActor to avoid retain cycle and thread-safety issues
    func startTimer() {
        guard timerEnabled else { return }
        timerRemaining = timerDuration
        isTimerRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isTimerRunning else { return }
                self.timerRemaining -= 0.1
                if self.timerRemaining <= 0 {
                    self.timerExpired()
                }
            }
        }
    }

    /// 타이머 일시정지 (카드 뒤집기 중)
    func pauseTimer() {
        isTimerRunning = false
    }

    /// 타이머 재개 (카드 앞면 복귀)
    func resumeTimer() {
        guard timerEnabled else { return }
        isTimerRunning = true
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
            estimatedLevel = profile.estimatedLevel
            timerEnabled = profile.timerEnabled
            customTimerSeconds = profile.vocabTimerSeconds
        }
    }

    private func loadTodayCount(userID: String, context: ModelContext) {
        if let activity = GamificationService.todayActivity(userID: userID, context: context) {
            todayWordCount = activity.wordsStudied
        } else {
            todayWordCount = 0
        }
    }
}
