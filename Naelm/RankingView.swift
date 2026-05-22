//
//  RankingView.swift
//  Naelm
//
//  순위 시스템 — 친구/전체 순위, 매월 초기화
//  ──────────────────────────────────────────────
//  점수 계산: 이번 달 XP 총합
//  매월 1일 자동 리셋 (month 필드 기준)
//  ──────────────────────────────────────────────

import SwiftUI
import SwiftData
import os

// MARK: - Ranking Score Calculator

struct RankingService {

    /// 현재 월 문자열 (예: "2026-04")
    static var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    /// 사용자의 이번 달 점수 조회/생성
    @MainActor
    static func fetchOrCreateMonthlyScore(
        userID: String,
        context: ModelContext
    ) -> MonthlyScore {
        let month = currentMonth
        let predicate = #Predicate<MonthlyScore> {
            $0.userID == userID && $0.month == month
        }
        let descriptor = FetchDescriptor<MonthlyScore>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let newScore = MonthlyScore(userID: userID, month: month, score: 0)
        context.insert(newScore)
        return newScore
    }

    /// 이번 달 점수 업데이트 — XP 총합 기반
    @MainActor
    static func updateMonthlyScore(
        userID: String,
        context: ModelContext
    ) {
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)!

        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= startOfMonth &&
            $0.activityDate < nextMonth
        }
        let descriptor = FetchDescriptor<UserActivity>(predicate: predicate)
        let activities = (try? context.fetch(descriptor)) ?? []

        let totalXP = activities.reduce(0) { $0 + $1.xpEarned }

        let monthlyScore = fetchOrCreateMonthlyScore(userID: userID, context: context)
        monthlyScore.score = totalXP
    }

    /// 전체 유저 순위 (이번 달, CloudKit 동기화된 데이터)
    @MainActor
    static func fetchGlobalRanking(context: ModelContext) -> [MonthlyScore] {
        let month = currentMonth
        let predicate = #Predicate<MonthlyScore> { $0.month == month }
        var descriptor = FetchDescriptor<MonthlyScore>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.score, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Ranking View

struct RankingView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: RankingTab = .global
    @State private var globalRanking: [PublicUserInfo] = []
    @State private var friendRanking: [PublicUserInfo] = []
    @State private var myScore: Int = 0
    @State private var myRank: Int = 0

    /// 친구 탭 행 렌더링 시 O(1) 조회를 위한 캐시 (friendUserID → Friendship)
    @State private var friendshipCache: [String: Friendship] = [:]

    /// 진행 중인 순위 로딩 Task (재진입 시 취소 후 재시작)
    @State private var rankingTask: Task<Void, Never>? = nil

    enum RankingTab: String, CaseIterable {
        case global = "전체"
        case friends = "친구"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 내 순위 카드
                    myRankCard

                    // 탭 선택
                    Picker("", selection: $selectedTab) {
                        ForEach(RankingTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    // 순위 리스트
                    let ranking = selectedTab == .global ? globalRanking : friendRanking
                    if ranking.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: selectedTab == .friends ? "person.2.slash" : "chart.bar")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text(selectedTab == .friends ? "아직 친구가 없어요" : "이번 달 데이터가 없어요")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            if selectedTab == .friends {
                                Text("마이페이지 → 친구 탭에서 친구를 추가해보세요")
                                    .font(.caption).foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(ranking.enumerated()), id: \.element.publicID) { index, info in
                                if selectedTab == .friends, let friendship = friendshipCache[info.publicID] {
                                    NavigationLink(destination: FriendDetailView(friendship: friendship)) {
                                        rankRow(rank: index + 1, info: info)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    rankRow(rank: index + 1, info: info)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("순위")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Text(RankingService.currentMonth)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { refreshRanking() }
            .refreshable { refreshRanking() }
        }
    }

    // MARK: - My Rank Card

    private var myRankCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest, AppPalette.leaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: AppPalette.forest.opacity(0.30), radius: 8, y: 3)
                Text("#\(myRank)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("내 순위")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(myScore) XP")
                    .font(.title2).fontWeight(.bold)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("이번 달")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(RankingService.currentMonth)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(AppPalette.forest)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.06), AppPalette.leaf.opacity(0.03), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [AppPalette.leaf.opacity(0.4), AppPalette.forest.opacity(0.15), AppPalette.leaf.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    // MARK: - Rank Row

    private func rankRow(rank: Int, info: PublicUserInfo) -> some View {
        let myPublicID = authManager.userID.map { FriendService.publicID(from: $0) }
        let isMe = info.publicID == myPublicID
        return HStack(spacing: 12) {
            // 순위
            ZStack {
                if rank <= 3 {
                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                        .foregroundStyle(rank == 1 ? AppPalette.gold : rank == 2 ? .gray : Color(hex: "#A0522D"))
                        .font(.title3)
                }
                Text("\(rank)")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(rank <= 3 ? .clear : .secondary)
            }
            .frame(width: 32)

            // 유저 아이콘
            Circle()
                .fill(
                    isMe
                    ? LinearGradient(colors: [AppPalette.forest, AppPalette.leaf], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(.tertiarySystemFill), Color(.tertiarySystemFill)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Text(isMe ? "나" : String(info.nickname.prefix(1)))
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(isMe ? .white : .secondary)
                )

            Text(isMe ? "나" : info.nickname)
                .font(.subheadline).fontWeight(isMe ? .bold : .regular)

            Spacer()

            Text("\(info.monthlyXP) XP")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(isMe ? AppPalette.forest : .primary)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.06), AppPalette.leaf.opacity(0.03), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [AppPalette.leaf.opacity(0.4), AppPalette.forest.opacity(0.15), AppPalette.leaf.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    // MARK: - Refresh

    private func refreshRanking() {
        guard let userID = authManager.userID else { return }

        RankingService.updateMonthlyScore(userID: userID, context: modelContext)
        FriendSyncService.shared.syncPublicProfileIfNeeded(userID: userID, context: modelContext)
        let localMyScore = RankingService.fetchOrCreateMonthlyScore(userID: userID, context: modelContext).score
        let myPublicID = FriendService.publicID(from: userID)
        myScore = localMyScore

        let friendPredicate = #Predicate<Friendship> {
            $0.userID == userID && $0.isFriend == true
        }
        let friendDescriptor = FetchDescriptor<Friendship>(predicate: friendPredicate)
        let friendships = (try? modelContext.fetch(friendDescriptor)) ?? []
        let friendIDs = Set(friendships.map { FriendService.publicID(from: $0.friendID) })

        // 친구 캐시 구축 (O(1) 조회를 위해 친구 탭 렌더링 시 사용)
        friendshipCache = Dictionary(
            uniqueKeysWithValues: friendships.map { (FriendService.publicID(from: $0.friendID), $0) }
        )

        rankingTask?.cancel()
        rankingTask = Task {
            do {
                var fetchedGlobal = try await FriendService.shared.fetchGlobalRankingProfiles(limit: 100)
                guard !Task.isCancelled else { return }

                if !fetchedGlobal.contains(where: { $0.publicID == myPublicID }) {
                    let nickname = fetchMyNickname(userID: userID)
                    fetchedGlobal.append(
                        PublicUserInfo(
                            publicID: myPublicID,
                            nickname: nickname.isEmpty ? "나" : nickname,
                            friendCode: FriendService.friendCode(from: myPublicID),
                            estimatedLevel: 0,
                            targetScore: 700,
                            monthlyXP: localMyScore,
                            totalXP: 0,
                            streak: 0,
                            weeklyXP: 0,
                            recordName: "local_\(myPublicID)"
                        )
                    )
                }

                fetchedGlobal.sort {
                    if $0.monthlyXP != $1.monthlyXP { return $0.monthlyXP > $1.monthlyXP }
                    return $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
                }

                await MainActor.run {
                    globalRanking = fetchedGlobal
                    myRank = (fetchedGlobal.firstIndex { $0.publicID == myPublicID } ?? -1) + 1
                    friendRanking = fetchedGlobal.filter { friendIDs.contains($0.publicID) || $0.publicID == myPublicID }
                }

                let loadedFriendIDs = Set(friendRanking.map(\.publicID))
                let missingFriendIDs = friendIDs.subtracting(loadedFriendIDs)
                guard !missingFriendIDs.isEmpty else { return }

                let extraInfos = try await FriendService.shared.fetchPublicProfiles(userIDs: Array(missingFriendIDs))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    friendRanking += extraInfos
                    friendRanking.sort {
                        if $0.monthlyXP != $1.monthlyXP { return $0.monthlyXP > $1.monthlyXP }
                        return $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
                    }
                }
            } catch {
                AppLogger.friend.warning("Failed to load ranking from CloudKit: \(error.localizedDescription)")
                let fallbackMe = PublicUserInfo(
                    publicID: myPublicID,
                    nickname: fetchMyNickname(userID: userID).isEmpty ? "나" : fetchMyNickname(userID: userID),
                    friendCode: FriendService.friendCode(from: myPublicID),
                    estimatedLevel: 0,
                    targetScore: 700,
                    monthlyXP: localMyScore,
                    totalXP: 0,
                    streak: 0,
                    weeklyXP: 0,
                    recordName: "local_\(myPublicID)"
                )
                let fallbackFriends = (try? await FriendService.shared.fetchPublicProfiles(userIDs: Array(friendIDs))) ?? []
                let merged = ([fallbackMe] + fallbackFriends)
                let unique = Dictionary(grouping: merged, by: { $0.publicID }).compactMap { $0.value.first }
                await MainActor.run {
                    globalRanking = unique.sorted {
                        if $0.monthlyXP != $1.monthlyXP { return $0.monthlyXP > $1.monthlyXP }
                        return $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
                    }
                    myRank = (globalRanking.firstIndex { $0.publicID == myPublicID } ?? -1) + 1
                    friendRanking = globalRanking.filter { friendIDs.contains($0.publicID) || $0.publicID == myPublicID }
                }
            }
        }
    }

    // MARK: - Friendship 캐시 조회 헬퍼 (refreshRanking에서 미리 로드한 캐시 사용)

    private func fetchFriendship(for friendUserID: String) -> Friendship? {
        friendshipCache[friendUserID]
    }

    private func fetchMyNickname(userID: String) -> String {
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first?.nickname) ?? ""
    }
}
