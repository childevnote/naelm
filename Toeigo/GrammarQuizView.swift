//
//  GrammarQuizView.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  문법 퀴즈 화면 — Duolingo 스타일 빈칸 채우기.
//  ──────────────────────────────────────────────
//  구성:
//    • 상단 진행 바
//    • 문제 문장 (빈칸 ___ 하이라이트)
//    • 4지선다 보기 버튼
//    • 정답/오답 피드백 + 해설 Bottom Sheet
//    • 퀴즈 완료 결과 화면
//  ──────────────────────────────────────────────

import SwiftUI
import SwiftData

// MARK: - GrammarQuizView

struct GrammarQuizView: View {

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: QuizViewModel
    @State private var sessionManager: LearningSessionManager
    @State private var grammarTimerRemaining: Double = 15.0
    @State private var grammarTimerRunning: Bool = false
    @State private var grammarTimer: Timer? = nil
    @State private var targetScore: Int = 700
    @State private var showLeaveAlert = false
    @State private var speedFeedback: String? = nil

    init() {
        let sm = LearningSessionManager()
        _sessionManager = State(initialValue: sm)
        _viewModel = State(initialValue: QuizViewModel(sessionManager: sm))
    }

    private var grammarTimerDuration: Double {
        switch targetScore {
        case ..<700: return 15.0
        case 700..<800: return 12.0
        case 800..<900: return 9.0
        default: return 6.0
        }
    }

    var isGrammarSessionActive: Bool {
        !viewModel.questions.isEmpty && !viewModel.isQuizComplete && !viewModel.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("퀴즈 준비 중...")
                } else if viewModel.isQuizComplete {
                    quizCompleteView
                } else if viewModel.questions.isEmpty {
                    emptyQuizView
                } else if let question = viewModel.currentQuestion {
                    quizContentView(question: question)
                }

                // 속도 피드백 토스트
                if let feedback = speedFeedback {
                    VStack {
                        Text(feedback)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(BrandTheme.accent.opacity(0.85)))
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("문법 퀴즈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isGrammarSessionActive ? .hidden : .visible, for: .tabBar)
            .sheet(isPresented: $viewModel.showExplanation) {
                if let question = viewModel.currentQuestion {
                    explanationSheet(question: question)
                }
            }
            .onAppear {
                if viewModel.questions.isEmpty && !viewModel.isQuizComplete {
                    loadQuiz()
                }
                startGrammarTimer()
            }
            .onDisappear {
                stopGrammarTimer()
            }
            .onChange(of: viewModel.currentIndex) { _, _ in
                resetGrammarTimer()
            }
            .onChange(of: viewModel.isQuizComplete) { _, complete in
                if complete {
                    stopGrammarTimer()
                    grammarTimerRemaining = 0
                }
            }
            .onChange(of: viewModel.isAnswerRevealed) { _, revealed in
                if revealed {
                    grammarTimerRunning = false
                    // 정답 시 속도 피드백 표시
                    if let q = viewModel.currentQuestion, viewModel.selectedAnswer == q.correctAnswer {
                        showGrammarSpeedFeedback()
                    }
                }
            }
            .alert("학습 중단", isPresented: $showLeaveAlert) {
                Button("계속 학습", role: .cancel) {}
                Button("나가기", role: .destructive) { dismiss() }
            } message: {
                Text("현재 진행 중인 학습 세션이 있습니다. 나가면 진행 상황이 저장되지 않습니다.")
            }
        }
    }

    // MARK: - Quiz Content

    @ViewBuilder
    private func quizContentView(question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            progressBar

            // 타이머 바 (숫자 없이 바만)
            grammarTimerBar

            ScrollView {
                VStack(spacing: 24) {
                    // 문제 번호만
                    HStack {
                        Text("Q\(viewModel.currentIndex + 1)/\(viewModel.questions.count)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(BrandTheme.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // 문제 문장
                    sentenceView(question.sentenceWithBlank)
                        .padding(.horizontal, 24)

                    // 보기 버튼들
                    VStack(spacing: 12) {
                        ForEach(question.options, id: \.self) { option in
                            optionButton(option: option, question: question)
                        }

                        // 모르겠다 버튼
                        if !viewModel.isAnswerRevealed {
                            Button {
                                viewModel.skipAsDontKnow(context: modelContext)
                            } label: {
                                Text("모르겠어요.")
                                    .font(.body).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)

                    // 정답 공개 후: 다음/해설 버튼
                    if viewModel.isAnswerRevealed {
                        feedbackSection(question: question)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary).frame(height: 6)
                Rectangle().fill(BrandTheme.accent)
                    .frame(width: geo.size.width * viewModel.progress, height: 6)
                    .animation(.smooth, value: viewModel.progress)
            }
        }
        .frame(height: 6)
    }

    // Grammar timer bar (bar only, no text)
    private var grammarTimerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)).frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(grammarTimerColor)
                    .frame(width: geo.size.width * max(0, grammarTimerRemaining / grammarTimerDuration), height: 5)
                    .animation(.linear(duration: 0.1), value: grammarTimerRemaining)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 16).padding(.top, 4)
    }

    private var grammarTimerColor: Color {
        let ratio = grammarTimerRemaining / grammarTimerDuration
        if ratio > 0.66 { return BrandTheme.knewIt }
        if ratio > 0.33 { return .orange }
        return .red
    }

    private func startGrammarTimer() {
        grammarTimerRemaining = grammarTimerDuration
        grammarTimerRunning = true
        grammarTimer?.invalidate()
        grammarTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard grammarTimerRunning else { return }
                grammarTimerRemaining -= 0.1
                if grammarTimerRemaining <= 0 {
                    grammarTimerRunning = false
                    // 시간 초과 → 오답 선택하지 않고 복습 추가 후 다음 문제로 넘어감
                    if !viewModel.isAnswerRevealed {
                        viewModel.skipAsTimeout(context: modelContext)
                    }
                }
            }
        }
    }

    private func resetGrammarTimer() {
        grammarTimerRemaining = grammarTimerDuration
        grammarTimerRunning = true
        // 타이머가 invalidate된 경우를 대비해 재시작
        if grammarTimer == nil || !grammarTimer!.isValid {
            startGrammarTimer()
        }
    }

    private func stopGrammarTimer() {
        grammarTimerRunning = false
        grammarTimer?.invalidate()
        grammarTimer = nil
    }

    // MARK: - Sentence View

    private func sentenceView(_ sentence: String) -> some View {
        return HStack(spacing: 0) {
            FlowLayout(spacing: 4) {
                ForEach(Array(sentence.split(separator: " ").enumerated()), id: \.offset) { _, word in
                    if word == "___" {
                        Text("______")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .underline()
                            .padding(.horizontal, 2)
                    } else {
                        Text(String(word))
                            .font(.title3)
                            .padding(.horizontal, 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    // MARK: - Option Button

    private func optionButton(option: String, question: QuizQuestion) -> some View {
        Button {
            if !viewModel.isAnswerRevealed {
                viewModel.selectAnswer(option, context: modelContext)
            }
        } label: {
            HStack {
                Text(option)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                if viewModel.isAnswerRevealed {
                    if option == question.correctAnswer {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if option == viewModel.selectedAnswer {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(optionBackground(option: option, question: question))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(optionBorder(option: option, question: question), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isAnswerRevealed)
    }

    private func optionBackground(option: String, question: QuizQuestion) -> some ShapeStyle {
        guard viewModel.isAnswerRevealed else {
            return AnyShapeStyle(.background)
        }
        if option == question.correctAnswer {
            return AnyShapeStyle(.green.opacity(0.15))
        } else if option == viewModel.selectedAnswer {
            return AnyShapeStyle(.red.opacity(0.15))
        }
        return AnyShapeStyle(.background)
    }

    private func optionBorder(option: String, question: QuizQuestion) -> Color {
        guard viewModel.isAnswerRevealed else {
            return .clear
        }
        if option == question.correctAnswer {
            return .green
        } else if option == viewModel.selectedAnswer {
            return .red
        }
        return .clear
    }

    // MARK: - Feedback Section

    private func feedbackSection(question: QuizQuestion) -> some View {
        let isCorrect = viewModel.selectedAnswer == question.correctAnswer

        return VStack(spacing: 16) {
            // 정답/오답 배너
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                Text(isCorrect ? "정답입니다!" : "틀렸어요")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(isCorrect ? .green : .red)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCorrect ? .green.opacity(0.1) : .red.opacity(0.1))
            )

            // 버튼
            HStack(spacing: 12) {
                Button {
                    viewModel.showExplanation = true
                } label: {
                    Label("해설 보기", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.moveToNext(context: modelContext)
                } label: {
                    Text(viewModel.currentIndex + 1 >= viewModel.questions.count ? "결과 보기" : "다음 문제")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Explanation Sheet

    private func explanationSheet(question: QuizQuestion) -> some View {
        let isCorrect = viewModel.selectedAnswer == question.correctAnswer

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 문법 규칙
                    Text(question.grammar.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    // 설명
                    Text(question.grammar.explanation)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Divider()

                    // 틀렸을 때만 올바른 예문 표시
                    if !isCorrect {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("올바른 예문", systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                            Text(question.grammar.correctExample)
                                .font(.body)
                                .italic()
                        }
                    }

                    // 팁
                    if !question.tip.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("학습 팁", systemImage: "lightbulb.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                            Text(question.tip)
                                .font(.body)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.orange.opacity(0.08))
                        )
                    }
                }
                .padding(24)
            }
            .navigationTitle("해설")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        viewModel.showExplanation = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Quiz Complete

    private var quizCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 스코어 링
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: viewModel.accuracy)
                    .stroke(
                        viewModel.accuracy >= 0.7 ? .green : .orange,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(viewModel.accuracy * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("정답률")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(quizResultMessage)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // 통계
            VStack(spacing: 12) {
                statRow(icon: "text.book.closed", label: "풀이한 문제", value: "\(viewModel.questions.count)개")
                statRow(icon: "checkmark.circle", label: "정답", value: "\(viewModel.correctCount)개")
                statRow(icon: "xmark.circle", label: "오답", value: "\(viewModel.incorrectCount)개")
                statRow(icon: "star.fill", label: "획득 XP", value: "+\(sessionManager.stats.xpEarned)")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 32)

            Spacer()

            // 오답 노트
            if viewModel.incorrectCount > 0 {
                Button {
                    retryWrongAnswers()
                } label: {
                    Label("오답 복습하기", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            Button {
                dismiss()
            } label: {
                Label("홈으로", systemImage: "house.fill")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(BrandTheme.accent)

            Spacer()
                .frame(height: 40)
        }
    }

    private var quizResultMessage: String {
        switch viewModel.accuracy {
        case 0.9...1.0: return "완벽해요!"
        case 0.7..<0.9: return "잘했어요!"
        case 0.5..<0.7: return "조금만 더!"
        default: return "다시 도전해봐요!"
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Empty Quiz

    private var emptyQuizView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("풀 수 있는 문제가 없어요")
                .font(.title3)
                .fontWeight(.semibold)

            Text("문법 데이터를 로드 중이거나\n모든 문법을 숙달했습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("새로고침") {
                loadQuiz()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func loadQuiz() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        let ts = (try? modelContext.fetch(descriptor).first?.targetScore) ?? 700
        targetScore = ts
        viewModel.loadQuiz(userID: userID, context: modelContext, targetScore: ts)
        startGrammarTimer()
    }

    private func retryWrongAnswers() {
        let wrongQuestions = viewModel.answers.filter { !$0.isCorrect }.map(\.question)
        guard !wrongQuestions.isEmpty else { return }
        viewModel.questions = wrongQuestions.shuffled()
        viewModel.currentIndex = 0
        viewModel.answers = []
        viewModel.selectedAnswer = nil
        viewModel.isAnswerRevealed = false
        viewModel.isQuizComplete = false
        viewModel.showExplanation = false
        startGrammarTimer()
    }

    private func showGrammarSpeedFeedback() {
        let elapsed = grammarTimerDuration - grammarTimerRemaining
        let ratio = elapsed / grammarTimerDuration
        let msg: String
        if ratio <= 0.4 { msg = "빠르네요!" }
        else if ratio <= 0.7 { msg = "적절해요." }
        else { msg = "느리네요." }

        withAnimation(.easeInOut(duration: 0.25)) { speedFeedback = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { speedFeedback = nil }
        }
    }
}

// MARK: - FlowLayout (간단한 워드 랩 레이아웃)

/// 단어들이 줄바꿈되는 간단한 FlowLayout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + lineHeight))
    }
}
