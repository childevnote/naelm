//
//  MyPageView.swift
//  Toeigo
//
//  마이페이지 — 수준, 목표점수, 연속학습일, 문제유형 그래프
//

import SwiftUI
import SwiftData

struct MyPageView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext

    @State private var profile: UserProfile?
    @State private var streak: Int = 0
    @State private var totalXP: Int = 0
    @State private var totalWordsStudied: Int = 0
    @State private var totalGrammarStudied: Int = 0
    @State private var showResetAlert = false
    // 문제유형별 통계
    @State private var categoryCorrect: [String: Int] = [:]
    @State private var categoryIncorrect: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    goalSection
                    quizCategoryChart
                    learningSettings
                    accountSection
                }
                .padding(16)
            }
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadData() }
            .alert("전체 초기화", isPresented: $showResetAlert) {
                Button("초기화", role: .destructive) { resetOnboarding() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 학습 데이터가 삭제되고 처음 상태로 돌아갑니다.")
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(BrandTheme.accent).frame(width: 80, height: 80)
                Image(systemName: "person.fill").font(.system(size: 36)).foregroundStyle(.white)
            }

            if let p = profile {
                let level = TOEICScoreRange(rawValue: p.estimatedLevel) ?? .range600
                VStack(spacing: 4) {
                    Text("현재 수준").font(.caption).foregroundStyle(.secondary)
                    Text(level.label).font(.title2).fontWeight(.bold).foregroundStyle(BrandTheme.accent)
                }

                HStack(spacing: 24) {
                    statPill(icon: "target", label: "목표", value: "\(p.targetScore)점")
                    Divider().frame(height: 30)
                    statPill(icon: "flame", label: "연속학습", value: "\(streak)일")
                    Divider().frame(height: 30)
                    statPill(icon: "star", label: "총 XP", value: "\(totalXP)")
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(BrandTheme.accent.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(BrandTheme.accent.opacity(0.15), lineWidth: 1))
        )
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline).fontWeight(.bold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일일 목표").font(.headline)
            if let p = profile {
                HStack {
                    Label("단어", systemImage: "character.book.closed"); Spacer()
                    Text("\(p.dailyVocabGoal)개/일").fontWeight(.semibold)
                }.font(.subheadline)
                HStack {
                    Label("문법", systemImage: "text.book.closed"); Spacer()
                    Text("\(p.dailyGrammarGoal)개/일").fontWeight(.semibold)
                }.font(.subheadline)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Quiz Category Chart (도넛 그래프)

    private var quizCategoryChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("문제 유형별 분석").font(.headline)

            let allCategories = Set(Array(categoryCorrect.keys) + Array(categoryIncorrect.keys)).sorted()

            if allCategories.isEmpty {
                Text("아직 풀어본 문제가 없어요.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // 맞힌 문제 도넛
                    VStack(spacing: 8) {
                        Text("맞힌 문제").font(.caption).fontWeight(.semibold).foregroundStyle(BrandTheme.knewIt)
                        donutChart(data: categoryCorrect, colors: correctPalette)
                    }
                    .frame(maxWidth: .infinity)

                    // 틀린 문제 도넛
                    VStack(spacing: 8) {
                        Text("틀린 문제").font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                        let hasIncorrect = categoryIncorrect.values.reduce(0, +) > 0
                        if hasIncorrect {
                            donutChart(data: categoryIncorrect, colors: incorrectPalette)
                        } else {
                            ZStack {
                                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 14)
                                    .frame(width: 100, height: 100)
                                Text("없음").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // 범례
                let total = categoryCorrect.merging(categoryIncorrect) { $0 + $1 }
                let sorted = total.sorted { $0.value > $1.value }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(sorted.prefix(6)), id: \.key) { cat, count in
                        let idx = allCategories.firstIndex(of: cat) ?? 0
                        HStack(spacing: 6) {
                            Circle().fill(chartColor(index: idx)).frame(width: 8, height: 8)
                            Text(cat).font(.caption2)
                            Spacer()
                            Text("\(categoryCorrect[cat] ?? 0)")
                                .font(.caption2).fontWeight(.bold).foregroundStyle(BrandTheme.knewIt)
                            Text("/")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("\(categoryIncorrect[cat] ?? 0)")
                                .font(.caption2).fontWeight(.bold).foregroundStyle(.red)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    private func donutChart(data: [String: Int], colors: [Color]) -> some View {
        let sorted = data.sorted { $0.value > $1.value }
        let total = max(1, sorted.reduce(0) { $0 + $1.value })
        let allCats = Set(Array(categoryCorrect.keys) + Array(categoryIncorrect.keys)).sorted()

        return ZStack {
            ForEach(Array(sorted.enumerated()), id: \.element.key) { i, entry in
                let idx = allCats.firstIndex(of: entry.key) ?? i
                let startAngle = angleFor(data: sorted, upTo: i, total: total)
                let endAngle = angleFor(data: sorted, upTo: i + 1, total: total)
                DonutSlice(startAngle: startAngle, endAngle: endAngle)
                    .fill(chartColor(index: idx))
            }
            Circle().fill(Color(.systemBackground)).frame(width: 60, height: 60)
            Text("\(total)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 100)
    }

    private func angleFor(data: [(key: String, value: Int)], upTo index: Int, total: Int) -> Angle {
        let sum = data.prefix(index).reduce(0) { $0 + $1.value }
        return .degrees(Double(sum) / Double(total) * 360 - 90)
    }

    private func chartColor(index: Int) -> Color {
        let palette: [Color] = [
            BrandTheme.accent, .blue, .purple, .orange, .pink, .cyan, .indigo, .brown, .mint, .teal
        ]
        return palette[index % palette.count]
    }

    private var correctPalette: [Color] {
        [BrandTheme.knewIt, .green.opacity(0.7), .green.opacity(0.5), .green.opacity(0.3)]
    }
    private var incorrectPalette: [Color] {
        [.red, .red.opacity(0.7), .red.opacity(0.5), .red.opacity(0.3)]
    }

    // MARK: - Settings

    private var learningSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("설정").font(.headline)
            Button { showResetAlert = true } label: {
                HStack {
                    Label("전체 초기화", systemImage: "arrow.counterclockwise")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }.font(.subheadline)
            }.buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(spacing: 12) {
            if let uid = authManager.userID {
                Text("User ID: \(uid)").font(.caption2).foregroundStyle(.tertiary)
            }
            Button("로그아웃", role: .destructive) { authManager.signOut() }.font(.subheadline)
            Text("버전 1.0.0").font(.caption2).foregroundStyle(.tertiary)
        }.padding(16)
    }

    // MARK: - Data

    private func loadData() {
        guard let userID = authManager.userID else { return }

        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        profile = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first

        streak = GamificationService.currentStreak(userID: userID, context: modelContext)
        totalXP = GamificationService.totalXP(userID: userID, context: modelContext)

        // 문제유형별 통계
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

    private func resetOnboarding() {
        guard let userID = authManager.userID else { return }

        let profilePred = #Predicate<UserProfile> { $0.userID == userID }
        if let profiles = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: profilePred)) {
            for p in profiles { modelContext.delete(p) }
        }
        let progressPred = #Predicate<LearningProgress> { $0.userID == userID }
        if let progresses = try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: progressPred)) {
            for p in progresses { modelContext.delete(p) }
        }
        let activityPred = #Predicate<UserActivity> { $0.userID == userID }
        if let activities = try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: activityPred)) {
            for a in activities { modelContext.delete(a) }
        }
        let scorePred = #Predicate<MonthlyScore> { $0.userID == userID }
        if let scores = try? modelContext.fetch(FetchDescriptor<MonthlyScore>(predicate: scorePred)) {
            for s in scores { modelContext.delete(s) }
        }
        try? modelContext.save()
        authManager.needsOnboarding = true
    }
}

// MARK: - Donut Slice Shape

struct DonutSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.6
        var path = Path()
        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
