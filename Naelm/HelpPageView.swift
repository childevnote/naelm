//
//  HelpPageView.swift
//  Naelm
//
//  도움말 — 앱의 전반적인 규칙과 사용방법 안내.
//

import SwiftUI

struct HelpPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // 헤더
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppPalette.forest)
                        Text("NLLM 사용 가이드")
                            .font(.pretendardBold(24))
                        Text("토익 영단어 · 문법 마스터")
                            .font(.pretendardMedium(14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    // 학습 흐름
                    helpSection(
                        icon: "arrow.triangle.turn.up.right.diamond.fill",
                        title: "학습 흐름",
                        items: [
                            "앱을 처음 실행하면 목표 점수를 선택하고 수준 파악 테스트를 진행합니다.",
                            "테스트 결과에 따라 사용자의 현재 수준이 결정되며, 매일 학습할 단어·문법 양이 자동 설정됩니다.",
                            "매일 대시보드(홈)에서 단어 학습, 문법 퀴즈, 복습을 진행할 수 있습니다.",
                        ]
                    )

                    // 단어 학습
                    helpSection(
                        icon: "character.book.closed",
                        title: "단어 학습",
                        items: [
                            "카드를 넘기며 영어 단어의 뜻을 확인합니다.",
                            "왼쪽 스와이프(알고있어요): 이미 아는 단어로 표시합니다.",
                            "오른쪽 스와이프(학습할게요): 복습 대상에 추가됩니다.",
                            "제한 시간 내에 응답하지 않으면 자동으로 학습 대상에 추가됩니다.",
                            "일일 목표 개수를 모두 학습하면 해당 일의 단어 학습이 완료됩니다.",
                        ]
                    )

                    // 문법 퀴즈
                    helpSection(
                        icon: "text.book.closed",
                        title: "문법 퀴즈",
                        items: [
                            "빈칸 채우기 형식의 4지선다 문제를 풀게 됩니다.",
                            "정답을 맞추면 XP를 획득하고, 오답 시 복습 대상에 추가됩니다.",
                            "해설 보기를 통해 문법 규칙과 팁을 확인할 수 있습니다.",
                            "'모르겠어요' 버튼을 누르거나 시간 초과 시 오답으로 처리됩니다.",
                        ]
                    )

                    // XP 시스템
                    helpSection(
                        icon: "bolt.fill",
                        title: "XP(경험치) 시스템",
                        items: [
                            "단어를 '알고있어요'로 선택하면 XP를 획득합니다.",
                            "문법 퀴즈 정답 시 XP를 획득합니다.",
                            "복습할 내용이 있을 때 단어 복습 또는 문법 복습을 완료하면 각각 50 XP 보너스를 받습니다.",
                            "일일 XP 목표(100 XP)를 달성하면 연속 학습일이 기록됩니다.",
                        ]
                    )

                    // 복습
                    helpSection(
                        icon: "arrow.clockwise",
                        title: "복습 시스템",
                        items: [
                            "모르는 단어나 틀린 문법은 자동으로 복습 대상에 추가됩니다.",
                            "단어 복습: 반복 스와이프 방식으로, '알고있어요'를 선택할 때까지 반복됩니다.",
                            "문법 복습: 틀린 문제를 다시 풀어볼 수 있으며, 2회 이상 틀린 문제에는 힌트가 제공됩니다.",
                            "복습 완료 시 보너스 XP를 획득합니다.",
                        ]
                    )

                    // 일일 목표
                    helpSection(
                        icon: "target",
                        title: "일일 목표 & 연속 학습",
                        items: [
                            "매일 설정된 단어·문법 개수를 학습하면 일일 목표가 달성됩니다.",
                            "일일 할당량을 모두 채우면 '완료!'로 표시되며, 추가 학습은 다음 날 진행됩니다.",
                            "매일 꾸준히 학습하면 연속 학습일(스트릭)이 누적됩니다.",
                        ]
                    )

                    // 마이페이지
                    helpSection(
                        icon: "person.fill",
                        title: "마이페이지",
                        items: [
                            "현재 수준, 목표 점수, 연속 학습일, 총 XP를 확인할 수 있습니다.",
                            "목표 점수를 변경하면 일일 학습량이 자동으로 조정됩니다.",
                            "문제 유형별 정답/오답 분석 그래프를 확인할 수 있습니다.",
                            "화면 모드(라이트/다크/시스템)를 변경할 수 있습니다.",
                        ]
                    )

                    // 기타
                    helpSection(
                        icon: "star.fill",
                        title: "기타 기능",
                        items: [
                            "단어 학습 중 ★ 버튼으로 단어를 저장할 수 있습니다.",
                            "저장 탭에서 저장한 단어 목록을 확인하고 관리할 수 있습니다.",
                            "순위 탭에서 다른 학습자들의 순위를 확인할 수 있습니다.",
                        ]
                    )

                    Spacer().frame(height: 20)
                }
                .padding(16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("도움말")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func helpSection(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.forest)
                Text(title)
                    .font(.pretendardBold(17))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.pretendardMedium(14))
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.pretendardMedium(14))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}

#Preview {
    HelpPageView()
}
