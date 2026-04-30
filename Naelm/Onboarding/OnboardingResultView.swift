//
//  OnboardingResultView.swift
//  Naelm
//

import SwiftUI

struct OnboardingResultView: View {
    let placementAnswers: [(level: Int, correct: Bool)]
    let estimatedLevel: Int
    let selectedTarget: Int
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundStyle(BrandTheme.accent)

            Text("수준 파악 완료!")
                .font(.title).fontWeight(.bold)

            let correctCount = placementAnswers.filter(\.correct).count
            let total = placementAnswers.count

            Text("\(total)문제 중 \(correctCount)문제 정답")
                .font(.headline).foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach([1, 2, 3, 4], id: \.self) { lvl in
                    let lvlAnswers = placementAnswers.filter { $0.level == lvl }
                    let lvlCorrect = lvlAnswers.filter(\.correct).count
                    let scoreLbl = TOEICScoreRange(rawValue: lvl)?.label ?? ""
                    HStack {
                        Text(scoreLbl).font(.caption).frame(width: 60, alignment: .leading)
                        ProgressView(value: Double(lvlCorrect), total: 5.0)
                            .tint(lvlCorrect >= 3 ? BrandTheme.knewIt : .orange)
                        Text("\(lvlCorrect)/5").font(.caption).fontWeight(.bold).frame(width: 30)
                    }
                }
            }
            .padding(.horizontal, 32)

            let levelRange = TOEICScoreRange.fromEstimatedLevel(estimatedLevel)
            Text("추정 수준: \(levelRange.label)")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(BrandTheme.accent)

            Text("목표: \(selectedTarget)점")
                .font(.subheadline).foregroundStyle(.secondary)

            Spacer()

            Button {
                onConfirm()
            } label: {
                Text("학습 시작하기")
                    .font(.headline).frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandTheme.accent)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 24)
    }
}
