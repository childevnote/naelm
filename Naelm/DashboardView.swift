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

    private let dailyGoal = LearningSessionManager.defaultDailyGoalXP

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    greetingBanner
                    topSection
                    todayLearningSection
                    weeklyChartSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("학습 홈")
            .onAppear { refreshStats() }
            .refreshable { refreshStats() }
            .onChange(of: showVocabSession) { _, active in
                if !active {
                    // SwiftData flush 대기 후 갱신
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshStats() }
                }
            }
            .onChange(of: showGrammarSession) { _, active in
                if !active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshStats() }
                }
            }
            .onChange(of: showReviewSession) { _, active in
                if !active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshStats() }
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
        .background(RoundedRectangle(cornerRadius: 14).fill(AppPalette.cream.opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.leaf.opacity(0.25), lineWidth: 1)))
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
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
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

    private var vocabCompleted: Bool { false }
    private var grammarCompleted: Bool { false }

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
                if !vocabCompleted {
                    showVocabConfirm = true
                    HapticManager.shared.playTap()
                }
            } label: {
                todayTaskRow(
                    icon: "character.book.closed", label: "단어",
                    progress: "\(todayWordsStudied)/\(dailyVocabGoal)개",
                    color: vocabCompleted ? AppPalette.forest : AppPalette.forest,
                    subtitle: vocabCompleted ? "오늘 목표 달성! 내일 다시 만나요" : "탭하여 단어 학습 시작",
                    isCompleted: vocabCompleted
                )
            }
            .buttonStyle(.plain)
            .disabled(vocabCompleted)

            Button {
                if !grammarCompleted {
                    showGrammarConfirm = true
                    HapticManager.shared.playTap()
                }
            } label: {
                todayTaskRow(
                    icon: "text.book.closed", label: "문법",
                    progress: "\(todayGrammarStudied)/\(dailyGrammarGoal)개",
                    color: grammarCompleted ? AppPalette.forest : AppPalette.leaf,
                    subtitle: grammarCompleted ? "오늘 목표 달성! 내일 다시 만나요" : "탭하여 문법 퀴즈 시작",
                    isCompleted: grammarCompleted
                )
            }
            .buttonStyle(.plain)
            .disabled(grammarCompleted)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func todayTaskRow(icon: String, label: String, progress: String, color: Color, subtitle: String, isCompleted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                .font(.title3).foregroundStyle(color).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label).font(.pretendardSemiBold(15))
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                    Spacer()
                    Text(progress).font(.pretendardBold(15)).foregroundStyle(color)
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            if !isCompleted {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(isCompleted ? 0.04 : 0.06)))
        .opacity(isCompleted ? 0.75 : 1.0)
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이번 주 활동").font(.pretendardSemiBold(16))
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyHistory) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.goalMet ? AppPalette.mint : (day.xpEarned > 0 ? AppPalette.leaf : Color.gray.opacity(0.2)))
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
                }
            }
            .frame(height: 120)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
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
    }

    private var reviewChoiceView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 56))
                .foregroundStyle(AppPalette.forest)
            Text("어떤 복습을 할까요?")
                .font(.title3).fontWeight(.bold)

            VStack(spacing: 12) {
                Button { selectedMode = .vocabulary } label: {
                    HStack {
                        Image(systemName: "character.book.closed")
                        Text("단어 복습")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppPalette.forest.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button { selectedMode = .grammar } label: {
                    HStack {
                        Image(systemName: "text.book.closed")
                        Text("문법 오답 복습")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppPalette.warning.opacity(0.08)))
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
    /// 이번 라운드에서 학습할게요(오른쪽)를 선택한 단어들
    @State private var currentRoundStudyWords: [Vocabulary] = []
    /// 현재 라운드 남은 단어 수 (스와이프마다 감소)
    @State private var remainingCount: Int = 0

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
                    // 남은 단어 수 표시
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
                            // 알고있어요든 학습할게요든 스와이프하면 남은 수 감소
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
        .toolbar {
            if !isComplete {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showLeaveAlert = true
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
            isComplete = true
            HapticManager.shared.playCelebration()
        } else {
            reviewWords = currentRoundStudyWords.shuffled()
            currentRoundStudyWords = []
            remainingCount = reviewWords.count
            cardStackID = UUID()
        }
    }
}

// MARK: - Grammar Review (오답 재풀기, 시도 횟수 표시)

struct GrammarReviewContent: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext

    @State private var wrongGrammars: [(grammar: Grammar, attempts: Int)] = []
    @State private var currentIndex: Int = 0
    @State private var selectedAnswer: String? = nil
    @State private var isAnswerRevealed: Bool = false
    @State private var isComplete: Bool = false
    @State private var currentQuestion: QuizQuestion? = nil

    var body: some View {
        VStack {
            if wrongGrammars.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(AppPalette.mint)
                    Text("복습할 문법이 없어요!").font(.title3).fontWeight(.bold)
                }
            } else if isComplete {
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill").font(.system(size: 64)).foregroundStyle(AppPalette.gold)
                    Text("오답 복습 완료!").font(.title).fontWeight(.bold)
                }
            } else if let q = currentQuestion {
                reviewQuizView(question: q)
            }
        }
        .onAppear { loadWrongGrammars(); loadCurrentQuestion() }
    }

    private func reviewQuizView(question: QuizQuestion) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 진행률
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

                // 문장
                VStack(spacing: 8) {
                    Text(question.sentenceWithBlank)
                        .font(.title3).padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                    // 2회 이상 틀린 문제: 한국어 해석 힌트 표시
                    if currentIndex < wrongGrammars.count && wrongGrammars[currentIndex].attempts >= 2 {
                        let explanation = question.grammar.explanation
                        Text(explanation)
                            .font(.caption).foregroundStyle(.secondary).italic()
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)

                // 보기
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

                    // 모르겠다 버튼
                    if !isAnswerRevealed {
                        Button {
                            isAnswerRevealed = true
                            HapticManager.shared.playIncorrect()
                            incrementAttempt(grammar: question.grammar)
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
            isComplete = true
        } else {
            currentIndex += 1
            loadCurrentQuestion()
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
        // Generate question from grammar
        let sentence = grammar.correctExample
        guard !sentence.isEmpty else { currentQuestion = nil; return }

        var sentenceWithBlank = sentence
        var correctAnswer = grammar.blankTarget
        if !correctAnswer.isEmpty {
            sentenceWithBlank = sentence.replacingOccurrences(of: correctAnswer, with: "___")
        } else {
            // fallback
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
            // Update local display
            if currentIndex < wrongGrammars.count {
                wrongGrammars[currentIndex].attempts = progress.incorrectCount
            }
        }
    }
}
