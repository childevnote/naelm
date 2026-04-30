//
//  OnboardingTargetScoreView.swift
//  Naelm
//

import SwiftUI

struct OnboardingTargetScoreView: View {
    @Binding var selectedTarget: Int
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(BrandTheme.accent)

            Text("목표 TOEIC 점수를 선택해주세요")
                .font(.pretendardBold(22))
                .multilineTextAlignment(.center)

            Text("선택한 점수에 맞는 단어와 문법을 추천해 드립니다")
                .font(.pretendardMedium(15)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                ForEach([600, 700, 800, 900], id: \.self) { score in
                    Button {
                        selectedTarget = score
                        HapticManager.shared.playTap()
                    } label: {
                        HStack {
                            Text("\(score)점 이상")
                                .font(.headline)
                            Spacer()
                            if selectedTarget == score {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BrandTheme.accent)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTarget == score ? BrandTheme.accent.opacity(0.12) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTarget == score ? BrandTheme.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                onNext()
            } label: {
                Text("다음")
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
