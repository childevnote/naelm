//
//  OnboardingPlacementIntroView.swift
//  Naelm
//

import SwiftUI

struct OnboardingPlacementIntroView: View {
    let onStartTest: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 64))
                .foregroundStyle(BrandTheme.accent)

            Text("간단한 수준 파악 테스트")
                .font(.pretendardBold(22))

            Text("20문제로 현재 실력을 진단합니다.\n문제당 10초 제한이 있습니다.\n약 3분 소요됩니다.")
                .font(.pretendardMedium(15)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onStartTest()
                } label: {
                    Text("테스트 시작")
                        .font(.headline).frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent)

                Button {
                    onSkip()
                } label: {
                    Text("건너뛰기")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 24)
    }
}
