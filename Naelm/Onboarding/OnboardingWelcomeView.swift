//
//  OnboardingWelcomeView.swift
//  Naelm
//
//  온보딩 마지막 단계 — 환영 메시지 + 앱 이용 방법 안내
//

import SwiftUI

struct OnboardingWelcomeView: View {
    let nickname: String
    var onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage: Int = 0

    private let tips: [AppTip] = [
        AppTip(
            icon: "rectangle.stack.fill",
            color: .blue,
            title: "스와이프로 단어 학습",
            description: "카드를 좌우로 스와이프하거나\n버튼을 눌러 단어를 학습해요.\n맞으면 오른쪽, 모르면 왼쪽이에요!"
        ),
        AppTip(
            icon: "text.book.closed.fill",
            color: .green,
            title: "문법 퀴즈 도전",
            description: "토익 빈출 문법 문제를 풀며\n실력을 키워보세요.\n정답 해설도 꼼꼼히 확인하세요!"
        ),
        AppTip(
            icon: "flame.fill",
            color: .orange,
            title: "연속 학습으로 스트릭 쌓기",
            description: "매일 꾸준히 학습하면\n스트릭이 올라가고 XP를 획득해요.\n연속 기록을 유지해보세요!"
        ),
        AppTip(
            icon: "star.fill",
            color: .yellow,
            title: "북마크로 단어 저장",
            description: "어려운 단어는 북마크해두고\n나중에 집중적으로 복습할 수 있어요."
        ),
        AppTip(
            icon: "person.2.fill",
            color: AppPalette.forest,
            title: "친구와 함께 경쟁",
            description: "친구를 추가하고\n학습 랭킹에서 경쟁해보세요.\n함께하면 더 재미있어요!"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 환영 헤더
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppPalette.leaf.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image("AppCharacter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                }

                VStack(spacing: 6) {
                    Text("\(nickname.isEmpty ? "환영합니다" : "\(nickname)님")!")
                        .font(.pretendardBold(28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppPalette.forest, AppPalette.leaf],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text("Naelm과 함께 토익 점수를\n올려봐요 🚀")
                        .font(.pretendardMedium(16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 32)

            // 팁 카드 탭뷰
            TabView(selection: $currentPage) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    tipCard(tip)
                        .tag(index)
                        .padding(.horizontal, 32)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)

            // 페이지 인디케이터
            HStack(spacing: 6) {
                ForEach(0..<tips.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? AppPalette.forest : AppPalette.forest.opacity(0.2))
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }
            .padding(.top, 16)

            Spacer()

            // 시작 버튼
            Button {
                if currentPage < tips.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onComplete()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage == tips.count - 1 ? "시작하기" : "다음")
                        .font(.pretendardSemiBold(17))
                    Image(systemName: currentPage == tips.count - 1 ? "checkmark" : "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.forest, AppPalette.leaf],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                )
                .shadow(color: AppPalette.forest.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func tipCard(_ tip: AppTip) -> some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(tip.color.opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: tip.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(tip.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(tip.title)
                    .font(.pretendardBold(16))
                    .foregroundStyle(.primary)
                Text(tip.description)
                    .font(.pretendardMedium(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20).stroke(
                    tip.color.opacity(0.25), lineWidth: 1
                )
            }
        )
    }
}

private struct AppTip {
    let icon: String
    let color: Color
    let title: String
    let description: String
}
