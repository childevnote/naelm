import SwiftUI
import SwiftData
import os
import OSLog

struct ReviewSessionView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMode: ReviewMode? = nil
    @State private var dueVocabCount: Int = 0
    @State private var dueGrammarCount: Int = 0

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
        .onAppear { loadDueCounts() }
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
                                .fill(AppPalette.forest.opacity(dueVocabCount > 0 ? 0.18 : 0.08))
                                .frame(width: 40, height: 40)
                            Image(systemName: "character.book.closed")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(dueVocabCount > 0 ? AppPalette.forest : Color.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("단어 복습")
                                .fontWeight(.semibold)
                                .foregroundStyle(dueVocabCount > 0 ? .primary : .secondary)
                            if dueVocabCount == 0 {
                                Text("복습할 단어 없음")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(dueVocabCount)개 대기 중")
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.forest)
                            }
                        }
                        Spacer()
                        if dueVocabCount > 0 {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppPalette.forest.opacity(dueVocabCount > 0 ? 0.05 : 0.02))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.forest.opacity(dueVocabCount > 0 ? 0.12 : 0.06), lineWidth: 1))
                    )
                    .opacity(dueVocabCount > 0 ? 1.0 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(dueVocabCount == 0)

                Button { selectedMode = .grammar } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppPalette.grammarBrown.opacity(dueGrammarCount > 0 ? 0.18 : 0.08))
                                .frame(width: 40, height: 40)
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(dueGrammarCount > 0 ? AppPalette.grammarBrown : Color.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("문법 오답 복습")
                                .fontWeight(.semibold)
                                .foregroundStyle(dueGrammarCount > 0 ? .primary : .secondary)
                            if dueGrammarCount == 0 {
                                Text("복습할 문법 없음")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(dueGrammarCount)개 대기 중")
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.grammarBrown)
                            }
                        }
                        Spacer()
                        if dueGrammarCount > 0 {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppPalette.grammarBrown.opacity(dueGrammarCount > 0 ? 0.05 : 0.02))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.grammarBrown.opacity(dueGrammarCount > 0 ? 0.12 : 0.06), lineWidth: 1))
                    )
                    .opacity(dueGrammarCount > 0 ? 1.0 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(dueGrammarCount == 0)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func loadDueCounts() {
        guard let userID = authManager.userID else { return }
        let vocabPred = #Predicate<LearningProgress> {
            $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "vocabulary"
        }
        dueVocabCount = (try? modelContext.fetchCount(FetchDescriptor<LearningProgress>(predicate: vocabPred))) ?? 0
        let grammarPred = #Predicate<LearningProgress> {
            $0.userID == userID && $0.markedForReview == true && $0.isMastered == false && $0.itemType == "grammar"
        }
        dueGrammarCount = (try? modelContext.fetchCount(FetchDescriptor<LearningProgress>(predicate: grammarPred))) ?? 0
    }
}

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
    @State private var knownWordIDs: Set<String> = []

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
                            if knewIt {
                                knownWordIDs.insert(vocab.wordID)
                            } else {
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
                sessionManager.endSession(context: modelContext, isVocabularyOnly: true)
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
            sessionManager.endSession(context: modelContext, isVocabularyOnly: true)
            clearReviewFlagForKnownWords()
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

    private func clearReviewFlagForKnownWords() {
        guard let userID = authManager.userID, !knownWordIDs.isEmpty else { return }
        let predicate = #Predicate<LearningProgress> {
            $0.userID == userID && $0.itemType == "vocabulary" && $0.markedForReview == true
        }
        let progresses = (try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: predicate))) ?? []
        for progress in progresses {
            if let wordID = progress.vocabulary?.wordID, knownWordIDs.contains(wordID) {
                progress.markedForReview = false
            }
        }
        try? modelContext.save()
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
