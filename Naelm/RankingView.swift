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
                            Image(systemName: "chart.bar")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text(selectedTab == .friends ? "아직 친구가 없어요" : "이번 달 데이터가 없어요")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(ranking.enumerated()), id: \.element.userID) { index, score in
                                rankRow(rank: index + 1, score: score)
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
                Text("\(myScore?.score ?? 0) XP")
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

    private func rankRow(rank: Int, score: MonthlyScore) -> some View {
        let isMe = score.userID == authManager.userID
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
                    Text(isMe ? "나" : "U")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(isMe ? .white : .secondary)
                )

            // 유저 ID (축약)
            Text(isMe ? "나" : String(score.userID.prefix(8)))
                .font(.subheadline).fontWeight(isMe ? .bold : .regular)

            Spacer()

            Text("\(score.score) XP")
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
        globalRanking = RankingService.fetchGlobalRanking(context: modelContext)

        myScore = globalRanking.first { $0.userID == userID }
        myRank = (globalRanking.firstIndex { $0.userID == userID } ?? -1) + 1

        let friendPredicate = #Predicate<Friendship> {
            $0.userID == userID && $0.isFriend == true
        }
        let friendDescriptor = FetchDescriptor<Friendship>(predicate: friendPredicate)
        let friendIDs = Set((try? modelContext.fetch(friendDescriptor))?.map(\.friendID) ?? [])

        friendRanking = globalRanking.filter { friendIDs.contains($0.userID) || $0.userID == userID }
    }
}
