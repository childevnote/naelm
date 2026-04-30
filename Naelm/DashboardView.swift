//
//  DashboardView.swift
//  Naelm
//
//  학습 대시보드 (Tab 1)
//

import SwiftUI
import SwiftData

struct DashboardView: View {

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var streak: Int = 0
    @State private var dueVocabCount: Int = 0
    @State private var dueGrammarCount: Int = 0
    @State private var weeklyHistory: [DailySummary] = []
    @State private var todayWordsStudied: Int = 0
    @State private var todayGrammarStudied: Int = 0
    @State private var dailyVocabGoal: Int = 20
    @State private var dailyGrammarGoal: Int = 10
    @State private var targetScore: Int = 700
    @State private var totalWordsStudied: Int = 0
    @State private var totalDaysStudied: Int = 0
    @State private var monthlyActivity: [Date: Int] = [:]

    @State private var showReviewSession = false
    @State private var showVocabSession = false
    @State private var showGrammarSession = false
    @State private var showVocabConfirm = false
    @State private var showGrammarConfirm = false
    @State private var selectedWeekDay: DailySummary? = nil
    @State private var showVocabCompleteAlert = false
    @State private var showGrammarCompleteAlert = false
    @State private var showNoReviewAlert = false
    @State private var showHelp = false
    @State private var showSettings = false

    private let dailyGoal = LearningSessionManager.defaultDailyGoalXP

    // 문법 퀴즈 완주 날짜 (AppStorage — userID별로 저장)
    @AppStorage("lastGrammarQuizCompletedDate") private var lastGrammarQuizCompletedDateRaw: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ── 그리팅 배너 ──
                    DashboardGreetingBannerView(
                        totalDaysStudied: totalDaysStudied,
                        totalWordsStudied: totalWordsStudied
                    )

                    // ── 각 섹션 직접 배치 ──
                    DashboardTopSectionView(
                        streak: streak,
                        monthlyActivity: monthlyActivity
                    )
                    TodayLearningSectionView(
                        dueVocabCount: dueVocabCount,
                        dueGrammarCount: dueGrammarCount,
                        todayWordsStudied: todayWordsStudied,
                        todayGrammarStudied: todayGrammarStudied,
                        dailyVocabGoal: dailyVocabGoal,
                        dailyGrammarGoal: dailyGrammarGoal,
                        vocabCompleted: vocabCompleted,
                        grammarCompleted: grammarCompleted,
                        onReviewTap: { totalDue in
                            if totalDue == 0 {
                                showNoReviewAlert = true
                            } else {
                                showReviewSession = true
                                HapticManager.shared.playTap()
                            }
                        },
                        onVocabTap: { completed in
                            if completed {
                                showVocabCompleteAlert = true
                            } else {
                                showVocabConfirm = true
                                HapticManager.shared.playTap()
                            }
                        },
                        onGrammarTap: { completed in
                            if completed {
                                showGrammarCompleteAlert = true
                            } else {
                                showGrammarConfirm = true
                                HapticManager.shared.playTap()
                            }
                        }
                    )
                    WeeklyChartSectionView(
                        weeklyHistory: weeklyHistory,
                        dailyGoal: dailyGoal,
                        selectedWeekDay: $selectedWeekDay
                    )
                }
                .padding(16)
                .padding(.top, 70)
                .padding(.bottom, 16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("학습 홈")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpPageView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environment(authManager)
            }
            .onAppear { refreshStats() }
            .refreshable { refreshStats() }
            .onOpenURL { url in
                guard let action = DashboardLaunchAction(url: url) else { return }
                switch action {
                case .startVocabulary: showVocabSession = true
                case .startGrammar:   showGrammarSession = true
                case .startReview:    showReviewSession = true
                }
            }
            .onChange(of: showVocabSession) { _, active in
                if !active {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        refreshStats()
                    }
                }
            }
            .onChange(of: showGrammarSession) { _, active in
                if !active {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        refreshStats()
                    }
                }
            }
            .onChange(of: showReviewSession) { _, active in
                if !active {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        refreshStats()
                    }
                }
            }
            .navigationDestination(isPresented: $showVocabSession) {
                VocabularyStudyView().environment(authManager)
            }
            .navigationDestination(isPresented: $showGrammarSession) {
                GrammarQuizView().environment(authManager)
            }
            .navigationDestination(isPresented: $showReviewSession) {
                ReviewSessionView().environment(authManager)
            }
            .alert("단어 학습 시작", isPresented: $showVocabConfirm) {
                Button("나중에", role: .cancel) {}
                Button("시작!") { showVocabSession = true }
            } message: {
                Text("약 3분 정도 소요됩니다. 학습을 시작할까요?")
            }
            .alert("문법 퀴즈 시작", isPresented: $showGrammarConfirm) {
                Button("나중에", role: .cancel) {}
                Button("시작!") { showGrammarSession = true }
            } message: {
                Text("약 3분 정도 소요됩니다. 퀴즈를 시작할까요?")
            }
            .alert("학습 완료", isPresented: $showVocabCompleteAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("오늘의 학습이 완료되었습니다.")
            }
            .alert("학습 완료", isPresented: $showGrammarCompleteAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("오늘의 학습이 완료되었습니다.")
            }
            .alert("복습할 항목 없음", isPresented: $showNoReviewAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("현재 복습할 단어나 문법이 없습니다. 학습을 먼저 진행해 보세요!")
            }
        }
    }

    private var vocabCompleted: Bool { todayWordsStudied >= dailyVocabGoal }
    /// 문법 퀴즈를 오늘 완주했으면 완료
    private var grammarCompleted: Bool {
        guard lastGrammarQuizCompletedDateRaw > 0 else { return false }
        let lastDate = Date(timeIntervalSince1970: lastGrammarQuizCompletedDateRaw)
        return Calendar.current.isDateInToday(lastDate)
    }

    // MARK: - Refresh

    private func refreshStats() {
        Task { @MainActor in
            guard let userID = authManager.userID else { return }

            streak = GamificationService.currentStreak(userID: userID, context: modelContext)
            weeklyHistory = GamificationService.weeklyHistory(userID: userID, context: modelContext)

            if let activity = GamificationService.todayActivity(userID: userID, context: modelContext) {
                todayWordsStudied = activity.wordsStudied
                todayGrammarStudied = activity.grammarStudied
            } else {
                todayWordsStudied = 0
                todayGrammarStudied = 0
            }

            let predicate = #Predicate<UserProfile> { $0.userID == userID }
            let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
            if let profile = try? modelContext.fetch(descriptor).first {
                targetScore = profile.targetScore
                dailyVocabGoal = profile.dailyVocabGoal
                dailyGrammarGoal = profile.dailyGrammarGoal
            }

            // 복습 대기: 단어(markedForReview) + 문법(틀린 문제)
            let vocabReviewPred = #Predicate<LearningProgress> {
                $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "vocabulary"
            }
            dueVocabCount = (try? modelContext.fetchCount(FetchDescriptor<LearningProgress>(predicate: vocabReviewPred))) ?? 0

            let grammarReviewPred = #Predicate<LearningProgress> {
                $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "grammar"
            }
            dueGrammarCount = (try? modelContext.fetchCount(FetchDescriptor<LearningProgress>(predicate: grammarReviewPred))) ?? 0

            // 총 학습일수 & 총 단어 수 (correctCount = 알고있어요만 카운트)
            let allActivityPred = #Predicate<UserActivity> { $0.userID == userID }
            let allActivities = (try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: allActivityPred))) ?? []
            totalDaysStudied = allActivities.filter { $0.wordsStudied > 0 || $0.grammarStudied > 0 }.count
            totalWordsStudied = allActivities.reduce(0) { $0 + $1.quizCorrect }

            // 잔디밭용 최근 28일 데이터
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -27, to: today) ?? today
            var actMap: [Date: Int] = [:]
            for a in allActivities {
                let day = calendar.startOfDay(for: a.activityDate)
                if day >= start { actMap[day, default: 0] += a.xpEarned }
            }
            monthlyActivity = actMap

            // 위젯 데이터 업데이트
            let vCompleted = todayWordsStudied >= dailyVocabGoal
            let gCompleted = todayGrammarStudied >= dailyGrammarGoal
            WidgetDataProvider.shared.update(
                streak: streak,
                vocabCompleted: vCompleted,
                grammarCompleted: gCompleted
            )

            // 일일 알림 예약/취소
            await NotificationService.shared.scheduleDailyReminderIfNeeded(
                vocabCompleted: vCompleted,
                grammarCompleted: gCompleted
            )
        }
    }
}

// MARK: - ScrollOffset PreferenceKey

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
