//
//  RankingView.swift
//  Toeigo
//
//  순위 시스템 — 친구/전체 순위, 매월 초기화
//  ──────────────────────────────────────────────
//  점수 계산: attempts × 0.3 + correctAnswers × 0.7
//  매월 1일 자동 리셋 (month 필드 기준)
//  ──────────────────────────────────────────────

import SwiftUI
import SwiftData

// MARK: - Ranking Score Calculator

struct RankingService {

    /// 순위 점수 계산: 시도 수 × 0.3 + 정답 수 × 0.7
    static func calculateScore(attempts: Int, correct: Int) -> Double {
        return Double(attempts) * 0.3 + Double(correct) * 0.7
    }

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

    /// 이번 달 점수 업데이트
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

        let totalAttempts = activities.reduce(0) { $0 + $1.quizTotal }
        let totalCorrect = activities.reduce(0) { $0 + $1.quizCorrect }
        let score = Int(calculateScore(attempts: totalAttempts, correct: totalCorrect))

        let monthlyScore = fetchOrCreateMonthlyScore(userID: userID, context: context)
        monthlyScore.score = score
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
            VStack(spacing: 0) {
                // 탭 선택
                Picker("", selection: $selectedTab) {
                    ForEach(RankingTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // 내 순위 카드
                myRankCard
                    .padding(16)

                // 순위 리스트
                ScrollView {
                    LazyVStack(spacing: 8) {
                        let ranking = selectedTab == .global ? globalRanking : friendRanking
                        ForEach(Array(ranking.enumerated()), id: \.element.userID) { index, score in
                            rankRow(rank: index + 1, score: score)
                        }

                        if (selectedTab == .global ? globalRanking : friendRanking).isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text(selectedTab == .friends ? "아직 친구가 없어요" : "이번 달 데이터가 없어요")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("순위")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Text(RankingService.currentMonth)
                        .font(.caption).foregroundStyle(.secondary)
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
                    .fill(BrandTheme.accent)
                    .frame(width: 56, height: 56)
                Text("#\(myRank)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("내 순위")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(myScore?.score ?? 0)점")
                    .font(.title2).fontWeight(.bold)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("이번 달")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(RankingService.currentMonth)
                    .font(.caption).fontWeight(.medium)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(BrandTheme.accent.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BrandTheme.accent.opacity(0.2), lineWidth: 1))
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
                        .foregroundStyle(rank == 1 ? .yellow : rank == 2 ? .gray : .brown)
                        .font(.title3)
                }
                Text("\(rank)")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(rank <= 3 ? .clear : .secondary)
            }
            .frame(width: 32)

            // 유저 아이콘
            Circle()
                .fill(isMe ? BrandTheme.accent : .gray.opacity(0.3))
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

            Text("\(score.score)점")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(isMe ? BrandTheme.accent : .primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMe ? BrandTheme.accent.opacity(0.06) : Color(.secondarySystemBackground))
        )
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
