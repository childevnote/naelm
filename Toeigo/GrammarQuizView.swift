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

    @State private var viewModel: QuizViewModel
    @State private var sessionManager: LearningSessionManager

    init() {
        let sm = LearningSessionManager()
        _sessionManager = State(initialValue: sm)
        _viewModel = State(initialValue: QuizViewModel(sessionManager: sm))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
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
            }
            .navigationTitle("문법 퀴즈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        loadQuiz()
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showExplanation) {
                if let question = viewModel.currentQuestion {
                    explanationSheet(question: question)
                }
            }
            .onAppear {
                if viewModel.questions.isEmpty && !viewModel.isQuizComplete {
                    loadQuiz()
                }
            }
        }
    }

    // MARK: - Quiz Content

    @ViewBuilder
    private func quizContentView(question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            // 진행 바
            progressBar

            ScrollView {
                VStack(spacing: 24) {
                    // 문제 번호 + 카테고리
                    HStack {
                        Text("Q\(viewModel.currentIndex + 1)/\(viewModel.questions.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)

                        Spacer()

                        Text(question.grammar.category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.15))
                            .clipShape(Capsule())

                        difficultyStars(level: question.grammar.difficultyLevel)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // 문법 규칙 제목
                    Text(question.grammar.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 문제 문장
                    sentenceView(question.sentenceWithBlank)
                        .padding(.horizontal, 24)

                    // 보기 버튼들
                    VStack(spacing: 12) {
                        ForEach(question.options, id: \.self) { option in
                            optionButton(option: option, question: question)
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
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 6)

                Rectangle()
                    .fill(.blue)
                    .frame(width: geo.size.width * viewModel.progress, height: 6)
                    .animation(.smooth, value: viewModel.progress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Sentence View

    private func sentenceView(_ sentence: String) -> some View {
        let parts = sentence.components(separatedBy: "___")

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
                Text(isCorrect ? "정답입니다! 👏" : "틀렸어요 😅")
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
        NavigationStack {
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

                    // 올바른 예문
                    VStack(alignment: .leading, spacing: 6) {
                        Label("올바른 예문", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text(question.grammar.correctExample)
                            .font(.body)
                            .italic()
                    }

                    // 틀린 예문
                    if !question.incorrectExample.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("틀린 예문", systemImage: "xmark.circle")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            Text(question.incorrectExample)
                                .font(.body)
                                .italic()
                                .strikethrough()
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
                    // TODO: 오답 노트 화면 이동
                } label: {
                    Label("오답 복습하기", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: 280)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }

            Button {
                loadQuiz()
            } label: {
                Label("한 번 더 풀기", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()
                .frame(height: 40)
        }
    }

    private var quizResultMessage: String {
        switch viewModel.accuracy {
        case 0.9...1.0: return "완벽해요! 🏆"
        case 0.7..<0.9: return "잘했어요! 👏"
        case 0.5..<0.7: return "조금만 더! 💪"
        default: return "다시 도전해봐요! 📚"
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

    // MARK: - Difficulty Stars

    private func difficultyStars(level: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < level ? "star.fill" : "star")
                    .font(.system(size: 10))
            }
        }
        .foregroundStyle(.orange)
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
        viewModel.loadQuiz(userID: userID, context: modelContext)
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
