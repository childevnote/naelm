//
//  GrammarQuizExplanationSheet.swift
//  Naelm
//

import SwiftUI

struct GrammarQuizExplanationSheet: View {
    let question: QuizQuestion
    let isCorrect: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.grammar.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(question.grammar.explanation)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Divider()

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
                        onClose()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
