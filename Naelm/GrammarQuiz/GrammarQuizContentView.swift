//
//  GrammarQuizContentView.swift
//  Naelm
//
//  UI subviews for GrammarQuizView.
//

import SwiftUI

struct GrammarQuizContentView: View {
    let question: QuizQuestion
    let currentIndex: Int
    let totalCount: Int
    let timerEnabled: Bool
    let timerRemaining: Double
    let timerDuration: Double
    let timerColor: Color
    let isAnswerRevealed: Bool
    let selectedAnswer: String?
    let answerBounceScale: CGFloat
    let answerShakeOffset: CGFloat
    let feedbackVisible: Bool
    let onSelectAnswer: (String) -> Void
    let onSkipDontKnow: () -> Void
    let onShowExplanation: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if timerEnabled {
                timerBar
            }

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("Q\(currentIndex + 1)/\(totalCount)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(AppPalette.forest)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    sentenceView(question.sentenceWithBlank)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        ForEach(question.options, id: \.self) { option in
                            optionButton(option: option)
                        }

                        if !isAnswerRevealed {
                            Button {
                                onSkipDontKnow()
                            } label: {
                                Text("모르겠어요.")
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
                        feedbackSection
                            .scaleEffect(answerBounceScale)
                            .offset(x: answerShakeOffset)
                            .opacity(feedbackVisible ? 1 : 0)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }

    private var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)).frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(timerColor)
                    .frame(width: geo.size.width * max(0, timerRemaining / timerDuration), height: 5)
                    .animation(.linear(duration: 0.1), value: timerRemaining)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 16).padding(.top, 4)
    }

    private func sentenceView(_ sentence: String) -> some View {
        HStack(spacing: 0) {
            FlowLayout(spacing: 4) {
                ForEach(Array(sentence.split(separator: " ").enumerated()), id: \.offset) { _, word in
                    if word == "___" {
                        Text("______")
                            .font(.pretendardBold(20))
                            .foregroundStyle(.blue)
                            .underline()
                            .padding(.horizontal, 2)
                    } else {
                        Text(String(word))
                            .font(.pretendardMedium(20))
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

    private func optionButton(option: String) -> some View {
        Button {
            if !isAnswerRevealed {
                onSelectAnswer(option)
            }
        } label: {
            HStack {
                Text(option)
                    .font(.pretendardMedium(16))

                Spacer()

                if isAnswerRevealed {
                    if option == question.correctAnswer {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if option == selectedAnswer {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(optionBackground(option: option))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(optionBorder(option: option), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnswerRevealed)
    }

    private func optionBackground(option: String) -> some ShapeStyle {
        guard isAnswerRevealed else {
            return AnyShapeStyle(.background)
        }
        if option == question.correctAnswer {
            return AnyShapeStyle(.green.opacity(0.15))
        } else if option == selectedAnswer {
            return AnyShapeStyle(.red.opacity(0.15))
        }
        return AnyShapeStyle(.background)
    }

    private func optionBorder(option: String) -> Color {
        guard isAnswerRevealed else {
            return .clear
        }
        if option == question.correctAnswer {
            return .green
        } else if option == selectedAnswer {
            return .red
        }
        return .clear
    }

    private var feedbackSection: some View {
        let isCorrect = selectedAnswer == question.correctAnswer

        return VStack(spacing: 16) {
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

            HStack(spacing: 12) {
                Button {
                    onShowExplanation()
                } label: {
                    Label("해설 보기", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button {
                    onNext()
                } label: {
                    Text(currentIndex + 1 >= totalCount ? "결과 보기" : "다음 문제")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.forest)
            }
        }
        .padding(.horizontal, 24)
    }
}
