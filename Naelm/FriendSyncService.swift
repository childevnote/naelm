//
//  FriendSyncService.swift
//  Naelm
//
//  앱 실행 시 CloudKit Public DB에 최신 통계를 자동 동기화하는 서비스.
//  ──────────────────────────────────────────────
//  역할:
//    1. 인증된 유저의 XP/스트릭/주간XP를 계산
//    2. isPublicProfileRegistered == true이면 upsertPublicProfile 호출
//  ──────────────────────────────────────────────

import Foundation
import SwiftData
import os

// MARK: - FriendSyncService

@MainActor
final class FriendSyncService {

    static let shared = FriendSyncService()

    private init() {}

    /// 앱 실행 시 공개 프로필을 최신 통계로 업데이트합니다.
    /// 에러는 무시하며 백그라운드에서 조용히 처리됩니다.
    func syncPublicProfileIfNeeded(
        userID: String,
        context: ModelContext
    ) {
        // 게스트 유저는 친구 기능 비활성화
        guard !userID.hasPrefix("guest_") else { return }

        Task {
            do {
                // UserProfile 조회
                let predicate = #Predicate<UserProfile> { $0.userID == userID }
                let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
                guard let profile = try? context.fetch(descriptor).first else { return }

                // isPublicProfileRegistered 확인
                guard profile.isPublicProfileRegistered else { return }

                // GamificationService로 통계 계산
                let totalXP = GamificationService.totalXP(userID: userID, context: context)
                let streak = GamificationService.currentStreak(userID: userID, context: context)

                // 이번 달 XP 계산 (RankingService 활용)
                RankingService.updateMonthlyScore(userID: userID, context: context)
                let monthlyXP = RankingService.fetchOrCreateMonthlyScore(userID: userID, context: context).score

                // 이번 주 XP 계산 (최근 7일 UserActivity.xpEarned 합산)
                let weeklyXP = calculateWeeklyXP(userID: userID, context: context)

                // Public Profile 업데이트
                try await FriendService.shared.upsertPublicProfile(
                    userID: userID,
                    nickname: profile.nickname,
                    monthlyXP: monthlyXP,
                    totalXP: totalXP,
                    streak: streak,
                    weeklyXP: weeklyXP,
                    estimatedLevel: profile.estimatedLevel,
                    targetScore: profile.targetScore
                )
                AppLogger.friend.info("Public profile synced")
            } catch {
                AppLogger.friend.warning("Failed to sync public profile: \(error.localizedDescription)")
            }
        }

        // 내가 보낸 친구 요청 중 수락된 것이 있으면 로컬 Friendship 업데이트
        syncAcceptedOutgoingRequests(userID: userID, context: context)
    }

    /// 내가 보낸 요청(requestedByMe=true, isPending=true)을 CloudKit에서 확인하여
    /// 상대방이 수락한 경우 로컬 Friendship을 isFriend=true로 업데이트합니다.
    func syncAcceptedOutgoingRequests(userID: String, context: ModelContext) {
        guard !userID.hasPrefix("guest_") else { return }

        Task {
            let predicate = #Predicate<Friendship> {
                $0.userID == userID &&
                $0.requestedByMe == true &&
                $0.isPending == true &&
                $0.cloudRequestRecordID != ""
            }
            let descriptor = FetchDescriptor<Friendship>(predicate: predicate)
            let pendingFriendships = (try? context.fetch(descriptor)) ?? []
            guard !pendingFriendships.isEmpty else { return }

            for friendship in pendingFriendships {
                guard let info = try? await FriendService.shared.fetchSentRequest(
                    recordName: friendship.cloudRequestRecordID
                ) else { continue }

                if info.status == "accepted" {
                    friendship.isFriend = true
                    friendship.isPending = false
                    AppLogger.friend.info("Outgoing friend request accepted, updated local Friendship")
                } else if info.status == "declined" || info.status == "removed" {
                    friendship.isPending = false
                    AppLogger.friend.info("Outgoing friend request declined/removed")
                }
            }
            try? context.save()
        }
    }

    /// 최근 7일 XP 합산
    private func calculateWeeklyXP(userID: String, context: ModelContext) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return 0 }

        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= sevenDaysAgo &&
            $0.activityDate < tomorrow
        }
        var descriptor = FetchDescriptor<UserActivity>(predicate: predicate)
        descriptor.propertiesToFetch = [\UserActivity.xpEarned]

        let activities = (try? context.fetch(descriptor)) ?? []
        return activities.reduce(0) { $0 + $1.xpEarned }
    }
}
