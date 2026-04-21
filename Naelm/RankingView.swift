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

        // 이번 달 활동 합산
        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= startOfMonth &&
            $0.activityDate < nextMonth
        }
        let descriptor = FetchDescriptor<UserActivity>(predicate: predicate)
        let activities = (try? context.fetch(descriptor)) ?? []

        // XP 총합을 점수로 사용
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
    @State private var globalRanking: [MonthlyScore] = []
    @State private var friendRanking: [MonthlyScore] = []
    @State private var myScore: MonthlyScore?
    @State private var myRank: Int = 0

    enum RankingTab: String, CaseIterable {
        case global = "전체"
        case friends = "친구"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.background(scheme: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    rankingToggle
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    myRankCard
                        .padding(.horizontal, 16)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let ranking = selectedTab == .global ? globalRanking : friendRanking
                            ForEach(Array(ranking.enumerated()), id: \.element.userID) { index, score in
                                rankRow(rank: index + 1, score: score)
                            }

                            if (selectedTab == .global ? globalRanking : friendRanking).isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.bar")
                                        .font(.system(size: 48))
                                        .foregroundStyle(AppPalette.leaf)
                                    Text(selectedTab == .friends ? "아직 친구가 없어요" : "이번 달 데이터가 없어요")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColor.primary)
                                }
                                .padding(.top, 60)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationTitle("순위")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Text(RankingService.currentMonth)
                        .font(.caption).foregroundStyle(AppPalette.leaf)
                }
            }
            .onAppear { refreshRanking() }
            .refreshable { refreshRanking() }
        }
    }

    private var rankingToggle: some View {
        HStack(spacing: 8) {
            ForEach(RankingTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.pretendardSemiBold(15))
                        .foregroundStyle(selectedTab == tab ? .white : AppColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    selectedTab == tab
                                    ? AppGradient.primaryButton(scheme: colorScheme)
                                    : LinearGradient(
                                        colors: [AppPalette.cream.opacity(0.92), AppPalette.mint.opacity(0.45)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? AppPalette.forest.opacity(0.24) : AppPalette.leaf.opacity(0.18))
        )
        .overlay(
            Capsule()
                .stroke(AppPalette.leaf.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: - My Rank Card

    private var myRankCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppGradient.primaryButton(scheme: colorScheme))
                    .frame(width: 56, height: 56)
                Text("#\(myRank)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("내 순위")
                    .font(.caption).foregroundStyle(AppPalette.leaf)
                Text("\(myScore?.score ?? 0) XP")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(AppColor.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("이번 달")
                    .font(.caption2).foregroundStyle(AppPalette.leaf)
                Text(RankingService.currentMonth)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(AppColor.primary)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppPalette.cream.opacity(colorScheme == .dark ? 0.08 : 0.72),
                                AppPalette.mint.opacity(0.18),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppPalette.leaf.opacity(0.28), lineWidth: 1)
            }
        )
    }

    // MARK: - Rank Row

    private func rankRow(rank: Int, score: MonthlyScore) -> some View {
        let isMe = score.userID == authManager.userID
        let accent = rankAccent(rank: rank, isMe: isMe)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 38, height: 38)

                Text(rankSymbol(rank: rank))
                    .font(rank <= 3 ? .system(size: 16, weight: .bold) : .system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
            }
            .frame(width: 38)

            Circle()
                .fill(accent.opacity(isMe ? 1 : 0.88))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(isMe ? "나" : "U")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            Text(isMe ? "나" : String(score.userID.prefix(8)))
                .font(.subheadline).fontWeight(isMe ? .bold : .regular)
                .foregroundStyle(AppColor.primary)

            Spacer()

            Text("\(score.score) XP")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(accent.opacity(isMe ? 0.16 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accent.opacity(isMe ? 0.36 : 0.18), lineWidth: 1)
        )
    }

    private func rankSymbol(rank: Int) -> String {
        switch rank {
        case 1: return "👑"
        case 2: return "2"
        case 3: return "3"
        default: return "\(rank)"
        }
    }

    private func rankAccent(rank: Int, isMe: Bool) -> Color {
        if isMe { return AppColor.primary }

        switch rank {
        case 1: return AppPalette.gold
        case 2: return AppPalette.leaf
        case 3: return AppPalette.mint
        default: return colorScheme == .dark ? AppPalette.mint : AppPalette.leaf
        }
    }

    // MARK: - Refresh

    private func refreshRanking() {
        guard let userID = authManager.userID else { return }

        // 내 점수 업데이트
        RankingService.updateMonthlyScore(userID: userID, context: modelContext)

        // 전체 순위
        globalRanking = RankingService.fetchGlobalRanking(context: modelContext)

        // 내 순위 찾기
        myScore = globalRanking.first { $0.userID == userID }
        myRank = (globalRanking.firstIndex { $0.userID == userID } ?? -1) + 1

        // 친구 순위
        let friendPredicate = #Predicate<Friendship> {
            $0.userID == userID && $0.isFriend == true
        }
        let friendDescriptor = FetchDescriptor<Friendship>(predicate: friendPredicate)
        let friendIDs = Set((try? modelContext.fetch(friendDescriptor))?.map(\.friendID) ?? [])

        friendRanking = globalRanking.filter { friendIDs.contains($0.userID) || $0.userID == userID }
    }
}
