//
//  OnboardingPlacementTestView.swift
//  Naelm
//

import SwiftUI

struct OnboardingPlacementTestView: View {
    let currentIndex: Int
    let questions: [PlacementQuestion]
    let timerRemaining: Double
    let onAnswer: (String?, PlacementQuestion) -> Void
    let onStopTimer: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(currentIndex), total: Double(questions.count))
                .tint(BrandTheme.accent)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            HStack {
                Text("\(currentIndex + 1) / \(questions.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if currentIndex < questions.count {
                    let lvl = questions[currentIndex].difficulty
                    let scoreLbl = TOEICScoreRange.from(frequencyLevel: lvl).shortLabel
                    Text("\(scoreLbl)++")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(BrandTheme.accent.opacity(0.15)))
                }
            }
            .padding(.horizontal, 24)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(timerRemaining > 5 ? BrandTheme.knewIt : timerRemaining > 3 ? .orange : .red)
                        .frame(width: geo.size.width * max(0, timerRemaining / 10.0), height: 5)
                        .animation(.linear(duration: 0.1), value: timerRemaining)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 24)

            if currentIndex < questions.count {
                let q = questions[currentIndex]

                VStack(spacing: 16) {
                    Text(q.type == .vocabulary ? "단어" : "문법")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(BrandTheme.accent)

                    Text(q.question)
                        .font(.title3).fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(q.options, id: \.self) { option in
                            Button {
                                onAnswer(option, q)
                            } label: {
                                Text(option)
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            onAnswer(nil, q)
                        } label: {
                            Text("모르겠다")
                                .font(.body).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .onDisappear { onStopTimer() }
    }
}
