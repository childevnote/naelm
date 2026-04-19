//
//  DashboardView.swift
//  Naelm
//
//  학습 대시보드 (Tab 1)
//

import SwiftUI
import SwiftData
import os

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
    @State private var scrollOffset: CGFloat = 0
    @State private var cardExpanded: Bool = false

    @State private var showReviewSession = false
    @State private var showVocabSession = false
    @State private var showGrammarSession = false
    @State private var showVocabConfirm = false
    @State private var showGrammarConfirm = false
    @State private var selectedWeekDay: DailySummary? = nil
    @State private var showVocabCompleteAlert = false
    @State private var showGrammarCompleteAlert = false

    private let dailyGoal = LearningSessionManager.defaultDailyGoalXP

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. 전체 배경: 흰색 → 상단으로 갈수록 초록색 그라디언트
                LinearGradient(
                    colors: [AppPalette.forest.opacity(0.25), AppPalette.leaf.opacity(0.12), .white],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 2. 도마뱀이 튀어나올 상단 여백
                        Spacer().frame(height: 90)

                        // 3. 메인 카드 컨테이너
                        VStack(spacing: 20) {
                            greetingBanner
                            topSection
                            todayLearningSection
                            weeklyChartSection
                        }
                        .padding(cardExpanded ? 0 : 16)
                        .background(
                            RoundedRectangle(cornerRadius: cardExpanded ? 0 : 24)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(cardExpanded ? 0 : 0.06), radius: 12, x: 0, y: 4)
                        )
                        // 4. 도마뱀 캐릭터 오버레이 배치
                        .overlay(alignment: .topTrailing) {
                            Image("NaelmHome")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 180, height: 180)
                                .shadow(color: .black.opacity(0.18), radius: 10, x: 2, y: 5)
                                .offset(x: 10, y: -90)
                        }
                        .padding(.horizontal, cardExpanded ? 0 : 16)
                        .padding(.bottom, 32)
                        .animation(.easeInOut(duration: 0.3), value: cardExpanded)

                        // 스크롤 오프셋 감지용
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .named("dashScroll")).minY)
                        }
                        .frame(height: 0)
                    }
                }
                .coordinateSpace(name: "dashScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    let shouldExpand = offset < -60
                    if shouldExpand != cardExpanded {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            cardExpanded = shouldExpand
                        }
                    }
                }
            }
            .navigationTitle("학습 홈")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { refreshStats() }
            .refreshable { refreshStats() }
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
        }
    }

    // MARK: - Greeting Banner

    private var greetingBanner: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                if totalDaysStudied > 0 {
                    Text("학습 \(totalDaysStudied)일 만에 \(totalWordsStudied)개의 단어를 학습했어요!")
                        .font(.pretendardSemiBold(14))
                        .foregroundStyle(AppPalette.forest)
                } else {
                    Text("오늘부터 토익 학습을 시작해보세요!")
                        .font(.pretendardSemiBold(14))
                        .foregroundStyle(AppPalette.forest)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.08), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16).stroke(AppPalette.leaf.opacity(0.20), lineWidth: 1)
            }
        )
    }

    // MARK: - Top Section (연속학습 + 잔디밭 한 줄)

    private var topSection: some View {
        HStack(spacing: 14) {
            // 왼쪽: 연속 학습일
            VStack(spacing: 2) {
                Text("\(streak)")
                    .font(.dashboardNumber)
                    .foregroundStyle(AppPalette.forest)
                Text("연속 학습")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 72)

            // 오른쪽: 잔디밭 (28일)
            grassChart
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppGradient.cardShimmer(scheme: colorScheme))
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.70), lineWidth: 1)
            }
        )
    }

    // MARK: - Grass Chart (GitHub style, 넓게)

    private var grassChart: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (0..<28).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let maxXP = max(1, monthlyActivity.values.max() ?? 1)

        return VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if idx < days.count {
                            let day = days[idx]
                            let xp = monthlyActivity[day] ?? 0
                            let isToday = calendar.isDateInToday(day)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(grassColorProportional(xp: xp, maxXP: maxXP))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    isToday ? RoundedRectangle(cornerRadius: 3).stroke(AppPalette.forest, lineWidth: 1.5) : nil
                                )
                        }
                    }
                }
            }
        }
    }

    private func grassColorProportional(xp: Int, maxXP: Int) -> Color {
        guard xp > 0 else { return Color.gray.opacity(0.12) }
        let ratio = Double(xp) / Double(maxXP)
        let opacity = 0.20 + ratio * 0.80
        return AppPalette.leaf.opacity(opacity)
    }

    // MARK: - Today Learning Section

    private var vocabCompleted: Bool { todayWordsStudied >= dailyVocabGoal }
    private var grammarCompleted: Bool { todayGrammarStudied >= dailyGrammarGoal }

    private var todayLearningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘의 학습").font(.pretendardSemiBold(16))
                Spacer()
                if vocabCompleted && grammarCompleted {
                    Text("오늘 학습 완료! 🎉")
                        .font(.captionBold)
                        .foregroundStyle(BrandTheme.knewIt)
                }
            }

            let totalDue = dueVocabCount + dueGrammarCount
            Button {
                showReviewSession = true
                HapticManager.shared.playTap()
            } label: {
                todayTaskRow(
                    icon: "arrow.clockwise", label: "복습 대기",
                    progress: "\(totalDue)개",
                    color: .orange,
                    subtitle: "단어 \(dueVocabCount)개 / 문법 \(dueGrammarCount)개",
                    isCompleted: false
                )
            }
            .buttonStyle(.plain)

            Button {
                if vocabCompleted {
                    showVocabCompleteAlert = true
                } else {
                    showVocabConfirm = true
                    HapticManager.shared.playTap()
                }
            } label: {
                todayTaskRow(
                    icon: "character.book.closed", label: "단어",
                    progress: vocabCompleted ? "완료!" : "\(todayWordsStudied)/\(dailyVocabGoal)개",
                    color: vocabCompleted ? AppPalette.mint : AppPalette.forest,
                    subtitle: vocabCompleted ? "오늘 목표 달성! 내일 다시 만나요" : "탭하여 단어 학습 시작",
                    isCompleted: vocabCompleted
                )
            }
            .buttonStyle(.plain)

            Button {
                if grammarCompleted {
                    showGrammarCompleteAlert = true
                } else {
                    showGrammarConfirm = true
                    HapticManager.shared.playTap()
                }
            } label: {
                todayTaskRow(
                    icon: "text.book.closed", label: "문법",
                    progress: grammarCompleted ? "완료!" : "\(todayGrammarStudied)/\(dailyGrammarGoal)개",
                    color: grammarCompleted ? AppPalette.mint : AppPalette.grammarBrown,
                    subtitle: grammarCompleted ? "오늘 목표 달성! 내일 다시 만나요" : "탭하여 문법 퀴즈 시작",
                    isCompleted: grammarCompleted
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(GlassCardBackground(cornerRadius: 16, scheme: colorScheme))
    }

    private func todayTaskRow(icon: String, label: String, progress: String, color: Color, subtitle: String, isCompleted: Bool) -> some View {
        HStack(spacing: 12) {
            // 아이콘 컨테이너 — 색상이 명확하게 보이도록 채워진 원형 배경
            ZStack {
                Circle()
                    .fill(color.opacity(isCompleted ? 0.12 : 0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.pretendardSemiBold(15))
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(progress)
                .font(.pretendardBold(15))
                .foregroundStyle(color)
            if !isCompleted {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(isCompleted ? 0.03 : 0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.75 : 1.0)
        .contentShape(Rectangle())
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이번 주 활동").font(.pretendardSemiBold(16))
                Spacer()
                if let sel = selectedWeekDay {
                    Text("\(sel.weekdayShort) \(sel.xpEarned) XP")
                        .font(.pretendardBold(13))
                        .foregroundStyle(AppPalette.forest)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyHistory) { day in
                    VStack(spacing: 4) {
                        // XP 라벨 (선택된 날만 표시)
                        if selectedWeekDay?.id == day.id && day.xpEarned > 0 {
                            Text("\(day.xpEarned)")
                                .font(.pretendard(9)).fontWeight(.bold)
                                .foregroundStyle(AppPalette.forest)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Text(" ").font(.pretendard(9))
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedWeekDay?.id == day.id
                                  ? AppPalette.gold
                                  : (day.goalMet ? AppPalette.mint : (day.xpEarned > 0 ? AppPalette.leaf : Color.gray.opacity(0.2))))
                            .frame(width: 30, height: barHeight(xp: day.xpEarned))
                        Text(day.weekdayShort)
                            .font(.pretendard(10))
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? .primary : .secondary)
                            .fontWeight(Calendar.current.isDateInToday(day.date) ? .bold : .regular)
                        if day.goalMet {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10)).foregroundStyle(AppPalette.mint)
                        } else {
                            Circle().fill(.clear).frame(width: 10, height: 10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedWeekDay?.id == day.id {
                                selectedWeekDay = nil
                            } else {
                                selectedWeekDay = day
                            }
                        }
                        HapticManager.shared.playTap()
                    }
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .background(GlassCardBackground(cornerRadius: 16, scheme: colorScheme))
    }

    private func barHeight(xp: Int) -> CGFloat {
        let maxHeight: CGFloat = 80
        let maxXP = max(weeklyHistory.map(\.xpEarned).max() ?? 1, dailyGoal)
        return max(4, CGFloat(xp) / CGFloat(maxXP) * maxHeight)
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

// MARK: - Review Session View (단어/문법 선택)

struct ReviewSessionView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMode: ReviewMode? = nil

    enum ReviewMode { case vocabulary, grammar }

    var body: some View {
        Group {
            if let mode = selectedMode {
                switch mode {
                case .vocabulary:
                    VocabReviewContent()
                        .environment(authManager)
                case .grammar:
                    GrammarReviewContent()
                        .environment(authManager)
                }
            } else {
                reviewChoiceView
            }
        }
        .navigationTitle("복습")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var reviewChoiceView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("어떤 복습을 할까요?")
                .font(.title3).fontWeight(.bold)

            VStack(spacing: 12) {
                Button { selectedMode = .vocabulary } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppPalette.forest.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "character.book.closed")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppPalette.forest)
                        }
                        Text("단어 복습")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppPalette.forest.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.forest.opacity(0.12), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                Button { selectedMode = .grammar } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppPalette.grammarBrown.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppPalette.grammarBrown)
                        }
                        Text("문법 오답 복습")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppPalette.grammarBrown.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.grammarBrown.opacity(0.12), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Vocab Review (기존 스와이프 복습)

struct VocabReviewContent: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var reviewWords: [Vocabulary] = []
    @State private var sessionManager = LearningSessionManager()
    @State private var isComplete = false
    @State private var cardStackID = UUID()
    @State private var showLeaveAlert = false
    @State private var currentRoundStudyWords: [Vocabulary] = []
    @State private var remainingCount: Int = 0
    @State private var bonusXPAwarded: Bool = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? BrandTheme.backgroundGradientDark : BrandTheme.backgroundGradient)
                .ignoresSafeArea()
            if reviewWords.isEmpty && !isComplete {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(AppPalette.mint)
                    Text("복습할 단어가 없어요!").font(.title3).fontWeight(.bold)
                }
            } else if isComplete {
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill").font(.system(size: 64)).foregroundStyle(AppPalette.gold)
                    Text("복습 완료!").font(.title).fontWeight(.bold)
                    Text("모든 단어를 숙달했어요 🎉").font(.subheadline).foregroundStyle(.secondary)
                    if bonusXPAwarded {
                        Text("+\(LearningSessionManager.reviewCompletionBonusXP) XP 보너스 획득! 🎉").font(.subheadline).foregroundStyle(AppPalette.gold)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label("홈으로", systemImage: "house.fill")
                            .font(.headline)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.forest)
                }
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text("남은 단어: \(remainingCount)개")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.top, 8)

                    SwipeableCardStack(
                        items: reviewWords,
                        onSwiped: { vocab, direction in
                            let knewIt = direction == .left
                            sessionManager.recordVocabularySwipe(vocabulary: vocab, knewIt: knewIt, context: modelContext)
                            remainingCount = max(0, remainingCount - 1)
                            if !knewIt {
                                currentRoundStudyWords.append(vocab)
                            }
                        },
                        onAllSwiped: {
                            handleRoundComplete()
                        }
                    ) { vocab in VocabularyCardView(vocabulary: vocab) }
                    .id(cardStackID)
                }
            }
        }
        .navigationBarBackButtonHidden(!isComplete)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if !isComplete {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if sessionManager.stats.wordsStudied == 0 {
                            dismiss()
                        } else {
                            showLeaveAlert = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("뒤로")
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .onAppear { loadReviewWords() }
        .alert("복습을 종료할까요?", isPresented: $showLeaveAlert) {
            Button("계속 진행하기", role: .cancel) {}
            Button("종료하기", role: .destructive) {
                sessionManager.endSession(context: modelContext)
                dismiss()
            }
        } message: {
            Text("지금까지의 복습 결과가 저장됩니다.")
        }
    }

    private func loadReviewWords() {
        guard let userID = authManager.userID else { return }
        sessionManager.startSession(userID: userID)
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "vocabulary"
        }
        reviewWords = ((try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: predicate))) ?? [])
            .compactMap(\.vocabulary).shuffled()
        currentRoundStudyWords = []
        remainingCount = reviewWords.count
    }

    private func handleRoundComplete() {
        if currentRoundStudyWords.isEmpty {
            sessionManager.endSession(context: modelContext)
            awardVocabReviewBonusXP()
            isComplete = true
            HapticManager.shared.playCelebration()
        } else {
            reviewWords = currentRoundStudyWords.shuffled()
            currentRoundStudyWords = []
            remainingCount = reviewWords.count
            cardStackID = UUID()
        }
    }

    private func awardVocabReviewBonusXP() {
        guard !bonusXPAwarded, let userID = authManager.userID else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= today &&
            $0.activityDate < tomorrow
        }
        let activity: UserActivity
        if let found = try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: predicate)).first {
            activity = found
        } else {
            activity = UserActivity(userID: userID, activityDate: today)
            modelContext.insert(activity)
        }
        activity.xpEarned += LearningSessionManager.reviewCompletionBonusXP
        if activity.xpEarned >= LearningSessionManager.defaultDailyGoalXP {
            activity.dailyGoalMet = true
        }
        do {
            try modelContext.save()
            bonusXPAwarded = true
        } catch {
            activity.xpEarned -= LearningSessionManager.reviewCompletionBonusXP
            if activity.xpEarned < LearningSessionManager.defaultDailyGoalXP {
                activity.dailyGoalMet = false
            }
            AppLogger.session.error("Failed to save vocab review bonus XP: \(error)")
        }
    }
}

// MARK: - Grammar Review (오답 재풀기, 시도 횟수 표시)

struct GrammarReviewContent: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var wrongGrammars: [(grammar: Grammar, attempts: Int)] = []
    @State private var currentIndex: Int = 0
    @State private var selectedAnswer: String? = nil
    @State private var isAnswerRevealed: Bool = false
    @State private var isComplete: Bool = false
    @State private var currentQuestion: QuizQuestion? = nil
    @State private var currentRoundWrong: [(grammar: Grammar, attempts: Int)] = []
    @State private var showUnsolvedAlert: Bool = false
    @State private var bonusXPAwarded: Bool = false

    var body: some View {
        VStack {
            if wrongGrammars.isEmpty && !isComplete {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(AppPalette.mint)
                    Text("복습할 문법이 없어요!").font(.title3).fontWeight(.bold)
                }
            } else if isComplete {
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill").font(.system(size: 64)).foregroundStyle(AppPalette.gold)
                    Text("오답 복습 완료!").font(.title).fontWeight(.bold)
                    if bonusXPAwarded {
                        Text("+\(LearningSessionManager.reviewCompletionBonusXP) XP 보너스 획득! 🎉").font(.subheadline).foregroundStyle(AppPalette.gold)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label("홈으로", systemImage: "house.fill")
                            .font(.headline)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.forest)
                }
            } else if let q = currentQuestion {
                reviewQuizView(question: q)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear { loadWrongGrammars(); loadCurrentQuestion() }
        .alert("풀지 못한 문제가 있습니다", isPresented: $showUnsolvedAlert) {
            Button("홈으로") {
                dismiss()
            }
            Button("다시 풀기") {
                wrongGrammars = currentRoundWrong
                currentRoundWrong = []
                currentIndex = 0
                selectedAnswer = nil
                isAnswerRevealed = false
                loadCurrentQuestion()
            }
        } message: {
            Text("남은 문제를 다시 풀어볼까요?")
        }
    }

    private func reviewQuizView(question: QuizQuestion) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ProgressView(value: Double(currentIndex), total: Double(wrongGrammars.count))
                    .tint(AppPalette.forest)
                    .padding(.horizontal, 24)

                    HStack {
                        Text("Q\(currentIndex + 1)/\(wrongGrammars.count)")
                            .font(.caption).fontWeight(.bold).foregroundStyle(AppPalette.forest)
                        Spacer()
                        if currentIndex < wrongGrammars.count {
                            let attempts = wrongGrammars[currentIndex].attempts
                            Text("시도 \(attempts)회")
                                .font(.caption2).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(.orange.opacity(0.15)))
                        }
                    }
                .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Text(question.sentenceWithBlank)
                        .font(.title3).padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                    if currentIndex < wrongGrammars.count && wrongGrammars[currentIndex].attempts >= 2 {
                        let explanation = question.grammar.explanation
                        Text(explanation)
                            .font(.caption).foregroundStyle(.secondary).italic()
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    ForEach(question.options, id: \.self) { option in
                        Button {
                            guard !isAnswerRevealed else { return }
                            selectedAnswer = option
                            isAnswerRevealed = true
                            let isCorrect = option == question.correctAnswer
                            if isCorrect {
                                HapticManager.shared.playCorrect()
                                markGrammarReviewCorrect(grammar: question.grammar)
                            } else {
                                HapticManager.shared.playIncorrect()
                                incrementAttempt(grammar: question.grammar)
                                if currentIndex < wrongGrammars.count {
                                    currentRoundWrong.append(wrongGrammars[currentIndex])
                                }
                            }
                        } label: {
                            HStack {
                                Text(option).font(.body).fontWeight(.medium)
                                Spacer()
                                if isAnswerRevealed {
                                    if option == question.correctAnswer {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if option == selectedAnswer {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(16)
                            .background(optionBg(option: option, correct: question.correctAnswer))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(isAnswerRevealed)
                    }

                    if !isAnswerRevealed {
                        Button {
                            isAnswerRevealed = true
                            HapticManager.shared.playIncorrect()
                            incrementAttempt(grammar: question.grammar)
                            if currentIndex < wrongGrammars.count {
                                currentRoundWrong.append(wrongGrammars[currentIndex])
                            }
                        } label: {
                            Text("모르겠다")
                                .font(.body).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                if isAnswerRevealed {
                    Button {
                        moveToNext()
                    } label: {
                        Text(currentIndex + 1 >= wrongGrammars.count ? "완료" : "다음 문제")
                            .fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent).tint(AppPalette.forest)
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func optionBg(option: String, correct: String) -> some ShapeStyle {
        guard isAnswerRevealed else { return AnyShapeStyle(Color(.secondarySystemBackground)) }
        if option == correct { return AnyShapeStyle(Color.green.opacity(0.15)) }
        if option == selectedAnswer { return AnyShapeStyle(Color.red.opacity(0.15)) }
        return AnyShapeStyle(Color(.secondarySystemBackground))
    }

    private func moveToNext() {
        selectedAnswer = nil
        isAnswerRevealed = false
        if currentIndex + 1 >= wrongGrammars.count {
            if currentRoundWrong.isEmpty {
                awardReviewBonusXP()
                isComplete = true
            } else {
                showUnsolvedAlert = true
            }
        } else {
            currentIndex += 1
            loadCurrentQuestion()
        }
    }

    private func awardReviewBonusXP() {
        guard !bonusXPAwarded, let userID = authManager.userID else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<UserActivity> {
            $0.userID == userID &&
            $0.activityDate >= today &&
            $0.activityDate < tomorrow
        }
        let activity: UserActivity
        if let found = try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: predicate)).first {
            activity = found
        } else {
            activity = UserActivity(userID: userID, activityDate: today)
            modelContext.insert(activity)
        }
        activity.xpEarned += LearningSessionManager.reviewCompletionBonusXP
        if activity.xpEarned >= LearningSessionManager.defaultDailyGoalXP {
            activity.dailyGoalMet = true
        }
        do {
            try modelContext.save()
            bonusXPAwarded = true
        } catch {
            activity.xpEarned -= LearningSessionManager.reviewCompletionBonusXP
            if activity.xpEarned < LearningSessionManager.defaultDailyGoalXP {
                activity.dailyGoalMet = false
            }
            AppLogger.session.error("Failed to save grammar review bonus XP: \(error)")
        }
    }

    private func loadWrongGrammars() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "grammar"
        }
        let progresses = (try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: predicate))) ?? []
        wrongGrammars = progresses.compactMap { p in
            guard let g = p.grammar else { return nil as (Grammar, Int)? }
            return (g, p.incorrectCount)
        }.shuffled()
    }

    private func loadCurrentQuestion() {
        guard currentIndex < wrongGrammars.count else { return }
        let grammar = wrongGrammars[currentIndex].grammar
        let sentence = grammar.correctExample
        guard !sentence.isEmpty else { currentQuestion = nil; return }

        var sentenceWithBlank = sentence
        var correctAnswer = grammar.blankTarget
        if !correctAnswer.isEmpty {
            sentenceWithBlank = sentence.replacingOccurrences(of: correctAnswer, with: "___")
        } else {
            let words = sentence.split(separator: " ").map(String.init)
            let skip = Set(["the","a","an","is","are","was","were","in","on","at","to","of","for","and","or","but","by","it","be"])
            let candidates = words.enumerated().filter { $0.element.lowercased().trimmingCharacters(in: .punctuationCharacters).count >= 3 && !skip.contains($0.element.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
            if let target = candidates.randomElement() {
                var blanked = words; blanked[target.offset] = "___"
                sentenceWithBlank = blanked.joined(separator: " ")
                correctAnswer = target.element.trimmingCharacters(in: .punctuationCharacters)
            }
        }

        var distractors = grammar.distractors.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != correctAnswer }
        while distractors.count < 3 {
            distractors.append(["however","therefore","although","moreover"].randomElement() ?? "however")
        }
        var options = [correctAnswer] + Array(distractors.prefix(3))
        options.shuffle()

        currentQuestion = QuizQuestion(
            grammar: grammar,
            sentenceWithBlank: sentenceWithBlank,
            correctAnswer: correctAnswer,
            options: options,
            incorrectExample: grammar.incorrectExample,
            tip: grammar.tip
        )
    }

    private func markGrammarReviewCorrect(grammar: Grammar) {
        guard let userID = authManager.userID else { return }
        let grammarID = grammar.grammarID
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID && $0.grammar?.grammarID == grammarID
        }
        if let progress = try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: predicate)).first {
            progress.markedForReview = false
            progress.correctCount += 1
        }
    }

    private func incrementAttempt(grammar: Grammar) {
        guard let userID = authManager.userID else { return }
        let grammarID = grammar.grammarID
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID && $0.grammar?.grammarID == grammarID
        }
        if let progress = try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: predicate)).first {
            progress.incorrectCount += 1
            if currentIndex < wrongGrammars.count {
                wrongGrammars[currentIndex].attempts = progress.incorrectCount
            }
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
