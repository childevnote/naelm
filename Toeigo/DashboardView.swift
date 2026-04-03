//
//  DashboardView.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  학습 대시보드 (Tab 1).
//  ──────────────────────────────────────────────
//  구성:
//    • 오늘의 XP 진행 링
//    • 연속 학습 스트릭 🔥
//    • 복습 대기 항목 수
//    • 7일 학습 활동 차트
//    • 숙달 통계
//  ──────────────────────────────────────────────

import SwiftUI
import SwiftData

struct DashboardView: View {

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext

    @Query private var vocabularies: [Vocabulary]
    @Query private var grammars: [Grammar]

    @State private var streak: Int = 0
    @State private var todayXP: Int = 0
    @State private var totalXP: Int = 0
    @State private var dueCount: Int = 0
    @State private var masteredWords: Int = 0
    @State private var masteredGrammar: Int = 0
    @State private var weeklyHistory: [DailySummary] = []

    private let dailyGoal = LearningSessionManager.defaultDailyGoalXP

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── 상단: XP 링 + 스트릭 ──
                    topSection

                    // ── 오늘의 할 일 카드 ──
                    todayTaskCard

                    // ── 7일 활동 차트 ──
                    weeklyChartSection

                    // ── 숙달 통계 ──
                    masterySection

                    // ── 데이터 현황 ──
                    dataStatusSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("학습 홈")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        authManager.signOut()
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .onAppear { refreshStats() }
            .refreshable { refreshStats() }
        }
    }

    // MARK: - Top Section (XP 링 + 스트릭)

    private var topSection: some View {
        HStack(spacing: 24) {
            // XP 진행 링
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 8)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: min(1.0, Double(todayXP) / Double(dailyGoal)))
                        .stroke(
                            todayXP >= dailyGoal ? .green : .blue,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.smooth, value: todayXP)

                    VStack(spacing: 0) {
                        Text("\(todayXP)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("/ \(dailyGoal) XP")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("오늘의 목표")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 스트릭 + 레벨
            VStack(spacing: 16) {
                // 스트릭
                HStack(spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streak)일")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("연속 학습")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 레벨
                let level = GamificationService.level(fromTotalXP: totalXP)
                let levelProg = GamificationService.levelProgress(fromTotalXP: totalXP)

                VStack(spacing: 4) {
                    HStack {
                        Text("Lv.\(level)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                        Spacer()
                        Text("총 \(totalXP) XP")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: levelProg)
                        .tint(.purple)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Today Task Card

    private var todayTaskCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.orange)
                Text("오늘의 학습")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 16) {
                taskChip(
                    icon: "arrow.clockwise",
                    label: "복습 대기",
                    value: "\(dueCount)개",
                    color: dueCount > 0 ? .red : .green
                )

                taskChip(
                    icon: "character.book.closed",
                    label: "전체 단어",
                    value: "\(vocabularies.count)개",
                    color: .blue
                )

                taskChip(
                    icon: "text.book.closed",
                    label: "전체 문법",
                    value: "\(grammars.count)개",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private func taskChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이번 주 활동")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyHistory) { day in
                    VStack(spacing: 4) {
                        // XP 바
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.goalMet ? Color.green : (day.xpEarned > 0 ? Color.blue : Color.gray.opacity(0.2)))
                            .frame(width: 30, height: barHeight(xp: day.xpEarned))
                            .animation(.smooth, value: day.xpEarned)

                        // 요일
                        Text(day.weekdayShort)
                            .font(.system(size: 10))
                            .foregroundStyle(
                                Calendar.current.isDateInToday(day.date) ? .primary : .secondary
                            )
                            .fontWeight(
                                Calendar.current.isDateInToday(day.date) ? .bold : .regular
                            )

                        // 목표 달성 표시
                        if day.goalMet {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                        } else {
                            Circle()
                                .fill(.clear)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private func barHeight(xp: Int) -> CGFloat {
        let maxHeight: CGFloat = 80
        let maxXP = max(weeklyHistory.map(\.xpEarned).max() ?? 1, dailyGoal)
        return max(4, CGFloat(xp) / CGFloat(maxXP) * maxHeight)
    }

    // MARK: - Mastery Section

    private var masterySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("숙달 현황")
                .font(.headline)

            HStack(spacing: 16) {
                masteryCard(
                    title: "단어",
                    mastered: masteredWords,
                    total: vocabularies.count,
                    color: .blue
                )
                masteryCard(
                    title: "문법",
                    mastered: masteredGrammar,
                    total: grammars.count,
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private func masteryCard(title: String, mastered: Int, total: Int, color: Color) -> some View {
        let progress = total > 0 ? Double(mastered) / Double(total) : 0

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(mastered)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Text("\(mastered)/\(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Data Status

    private var dataStatusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Label("단어 데이터: \(vocabularies.count)개", systemImage: "textformat.abc")
                Label("문법 데이터: \(grammars.count)개", systemImage: "text.book.closed")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("데이터 현황", systemImage: "cylinder.split.1x2")
                .font(.caption)
        }
    }

    // MARK: - Refresh

    private func refreshStats() {
        guard let userID = authManager.userID else { return }

        streak = GamificationService.currentStreak(userID: userID, context: modelContext)
        todayXP = GamificationService.todayXP(userID: userID, context: modelContext)
        totalXP = GamificationService.totalXP(userID: userID, context: modelContext)
        dueCount = GamificationService.dueItemCount(userID: userID, context: modelContext)
        masteredWords = GamificationService.masteredVocabularyCount(userID: userID, context: modelContext)
        masteredGrammar = GamificationService.masteredGrammarCount(userID: userID, context: modelContext)
        weeklyHistory = GamificationService.weeklyHistory(userID: userID, context: modelContext)
    }
}
