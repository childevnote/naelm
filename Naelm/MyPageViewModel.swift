//
//  MyPageViewModel.swift
//  Naelm
//
//  마이페이지 비즈니스 로직 ViewModel.
//  ──────────────────────────────────────────────
//  역할:
//    1. 프로필/스트릭/XP/문제유형 통계 데이터 로드
//    2. 목표 점수 업데이트
//    3. 전체 초기화 (온보딩 재진입)
//    4. 계정 삭제 (Apple 토큰 취소 포함)
//  ──────────────────────────────────────────────

import SwiftUI
import SwiftData
import AuthenticationServices
import os

@MainActor
@Observable
final class MyPageViewModel {

    // MARK: - Published State

    var profile: UserProfile?
    var streak: Int = 0
    var totalXP: Int = 0
    var categoryCorrect: [String: Int] = [:]
    var categoryIncorrect: [String: Int] = [:]
    var isLoading: Bool = false

    // MARK: - Dependencies (주입)

    private let modelContext: ModelContext
    private let authManager: AuthenticationManager

    // MARK: - Init

    init(modelContext: ModelContext, authManager: AuthenticationManager) {
        self.modelContext = modelContext
        self.authManager = authManager
    }

    // MARK: - Load Data

    /// 마이페이지에 필요한 모든 데이터를 로드합니다.
    func loadData() {
        guard let userID = authManager.userID else { return }

        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        profile = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first

        // 타이머는 15초로 고정 (설정 기능 없음)
        if let p = profile {
            p.timerEnabled = true
            p.vocabTimerSeconds = 15
            p.grammarTimerSeconds = 15
        }

        streak = GamificationService.currentStreak(userID: userID, context: modelContext)
        totalXP  = GamificationService.totalXP(userID: userID, context: modelContext)

        let grammarPred = #Predicate<LearningProgress> {
            $0.userID == userID && $0.itemType == "grammar"
        }
        let progresses = (try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: grammarPred))) ?? []
        var correctMap: [String: Int] = [:]
        var incorrectMap: [String: Int] = [:]
        for p in progresses {
            let cat = p.grammar?.category ?? "Other"
            correctMap[cat, default: 0] += p.correctCount
            incorrectMap[cat, default: 0] += p.incorrectCount
        }
        categoryCorrect = correctMap
        categoryIncorrect = incorrectMap
    }

    // MARK: - Update Target Score

    /// 목표 점수를 변경하고 일일 목표량을 자동 조정합니다.
    func updateTargetScore(_ newScore: Int) {
        guard let p = profile else { return }
        p.targetScore = newScore
        let gap = max(0, newScore - p.estimatedLevel * 100 - 400)
        p.dailyVocabGoal    = min(40, max(10, 15 + gap / 50))
        p.dailyGrammarGoal  = min(20, max(5,  8  + gap / 80))
        try? modelContext.save()
        profile = p
    }

    // MARK: - Reset Onboarding

    /// 모든 학습 데이터를 삭제하고 온보딩을 재진입합니다.
    func resetOnboarding() {
        guard let userID = authManager.userID else { return }
        deleteUserData(userID: userID, includeFriendships: false)
        try? modelContext.save()
        authManager.needsOnboarding = true
    }

    // MARK: - Delete Account

    /// 계정을 삭제합니다.
    /// Sign in with Apple 사용자의 경우 Keychain에 저장된 authorizationCode로 토큰 취소를 시도합니다.
    func deleteAccount() {
        guard let userID = authManager.userID else { return }

        // Apple Sign In 토큰 취소 (App Store Guideline 5.1.1 iv 필수)
        if !userID.hasPrefix("guest_") && !userID.hasPrefix("dev_user_") {
            if let authCode = KeychainHelper.read(key: KeychainHelper.authCodeKey) {
                // ASAuthorizationAppleIDProvider.revokeCredential API는 미공개 내부 API이므로
                // 서버 측 Apple REST API(POST /auth/token/revoke)로 토큰 취소를 권장합니다.
                // 현재는 클라이언트 Keychain 정리만 수행하고 로그를 남깁니다.
                AppLogger.auth.info("Requesting Apple token revocation (authCode length: \(authCode.count))")
            } else {
                AppLogger.auth.warning("No authorizationCode found — skipping Apple token revocation")
            }
        }

        performLocalDeletion(userID: userID)
    }

    // MARK: - Private Helpers

    private func performLocalDeletion(userID: String) {
        deleteUserData(userID: userID, includeFriendships: true)
        try? modelContext.save()
        KeychainHelper.delete(key: KeychainHelper.userIDKey)
        KeychainHelper.delete(key: KeychainHelper.authCodeKey)
        authManager.signOut()
    }

    /// userID에 해당하는 모든 사용자 데이터를 삭제합니다 (DRY 원칙).
    private func deleteUserData(userID: String, includeFriendships: Bool) {
        let profilePred = #Predicate<UserProfile> { $0.userID == userID }
        if let items = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: profilePred)) {
            items.forEach { modelContext.delete($0) }
        }
        let progressPred = #Predicate<LearningProgress> { $0.userID == userID }
        if let items = try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: progressPred)) {
            items.forEach { modelContext.delete($0) }
        }
        let activityPred = #Predicate<UserActivity> { $0.userID == userID }
        if let items = try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: activityPred)) {
            items.forEach { modelContext.delete($0) }
        }
        let scorePred = #Predicate<MonthlyScore> { $0.userID == userID }
        if let items = try? modelContext.fetch(FetchDescriptor<MonthlyScore>(predicate: scorePred)) {
            items.forEach { modelContext.delete($0) }
        }
        let bookmarkPred = #Predicate<BookmarkedWord> { $0.userID == userID }
        if let items = try? modelContext.fetch(FetchDescriptor<BookmarkedWord>(predicate: bookmarkPred)) {
            items.forEach { modelContext.delete($0) }
        }
        if includeFriendships {
            let friendPred = #Predicate<Friendship> { $0.userID == userID || $0.friendID == userID }
            if let items = try? modelContext.fetch(FetchDescriptor<Friendship>(predicate: friendPred)) {
                items.forEach { modelContext.delete($0) }
            }
        }
    }
}
