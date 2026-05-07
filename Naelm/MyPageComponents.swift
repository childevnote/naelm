import SwiftUI

struct MyPageHeaderView: View {
    let nickname: String
    let encouragement: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let displayName = nickname.isEmpty ? "사용자" : nickname
            Text("\(displayName)님,")
                .font(.pretendardBold(24))
                .foregroundStyle(.primary)
            Text(encouragement)
                .font(.pretendardMedium(15))
                .foregroundStyle(AppPalette.forest.opacity(0.80))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

struct ProfileCardView: View {
    let profile: UserProfile?
    let streak: Int
    let totalXP: Int

    @State private var glowOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppPalette.leaf, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 54
                        )
                    )
                    .frame(width: 108, height: 108)
                    .blur(radius: 8)
                    .opacity(glowOpacity)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowOpacity)
                    .onAppear {
                        DispatchQueue.main.async {
                            glowOpacity = 0.15
                        }
                    }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest, AppPalette.leaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: AppPalette.forest.opacity(0.25), radius: 10, y: 4)

                Image(systemName: "person.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            if let p = profile {
                let level = TOEICScoreRange.fromEstimatedLevel(p.estimatedLevel)
                let targetLabel = TOEICScoreRange.rangesUpTo(target: p.targetScore).last?.plusLabel ?? "\(p.targetScore)++"

                VStack(spacing: 6) {
                    Text("현재 수준")
                        .font(.pretendardMedium(12))
                        .foregroundStyle(.secondary)

                    Text(level.plusLabel)
                        .font(.pretendardBold(26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppPalette.forest, AppPalette.leaf],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                LevelGaugeRowView(totalXP: totalXP)

                HStack(spacing: 12) {
                    statCard(icon: "target", label: "목표", value: targetLabel, color: AppPalette.forest)
                    statCard(icon: "flame.fill", label: "연속학습", value: "\(streak)일", color: .orange)
                    statCard(icon: "star.fill", label: "총 XP", value: "\(totalXP)", color: AppPalette.gold)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppPalette.forest.opacity(0.06),
                                AppPalette.leaf.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppPalette.leaf.opacity(0.4),
                                AppPalette.forest.opacity(0.15),
                                AppPalette.leaf.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.pretendardBold(17))
            Text(label)
                .font(.pretendard(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

struct LevelGaugeRowView: View {
    let totalXP: Int

    @State private var levelGaugeProgress: Double = 0.0

    var body: some View {
        let lv = GamificationService.level(fromTotalXP: totalXP)
        let progress = GamificationService.levelProgress(fromTotalXP: totalXP)
        let xpToNext = GamificationService.xpToNextLevel(fromTotalXP: totalXP)

        return HStack(spacing: 10) {
            Text("Lv.\(lv)")
                .font(.pretendardBold(14))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppPalette.forest.opacity(0.12))
                        .frame(height: 18)
                        .colorMultiply(AppPalette.forest.opacity(0.12))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.forest.opacity(0.75), AppPalette.leaf],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * levelGaugeProgress, height: 18)
                        .animation(.easeOut(duration: 1.0), value: levelGaugeProgress)

                    HStack {
                        Spacer()
                        Text("다음 레벨까지 \(xpToNext) XP")
                            .font(.pretendardMedium(10))
                            .foregroundStyle(.opacity(0.75))
                        Spacer()
                    }
                }
                .frame(height: 18)
                .clipShape(Capsule())
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 4)
        .onAppear {
            levelGaugeProgress = 0
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 1.0)) {
                    levelGaugeProgress = progress
                }
            }
        }
        .onChange(of: totalXP) { _, _ in
            let newProgress = GamificationService.levelProgress(fromTotalXP: totalXP)
            withAnimation(.easeOut(duration: 0.8)) {
                levelGaugeProgress = newProgress
            }
        }
    }
}

struct GoalSectionView: View {
    let profile: UserProfile?
    let onEditTargetScore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일일 목표").font(.pretendardSemiBold(16))
                Spacer()
                Button {
                    onEditTargetScore()
                } label: {
                    HStack(spacing: 4) {
                        Text("목표 점수 변경")
                            .font(.pretendardMedium(13))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppPalette.forest)
                }
            }
            if let p = profile {
                HStack {
                    Label("목표 점수", systemImage: "target"); Spacer()
                    Text("\(p.targetScore)++").font(.pretendardSemiBold(15))
                }.font(.pretendardMedium(15))
                HStack {
                    Label("단어", systemImage: "character.book.closed"); Spacer()
                    Text("\(p.dailyVocabGoal)개/일").font(.pretendardSemiBold(15))
                }.font(.pretendardMedium(15))
                HStack {
                    Label("문법", systemImage: "text.book.closed"); Spacer()
                    Text("\(p.dailyGrammarGoal)개/일").font(.pretendardSemiBold(15))
                }.font(.pretendardMedium(15))
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.06), AppPalette.leaf.opacity(0.03), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [AppPalette.leaf.opacity(0.4), AppPalette.forest.opacity(0.15), AppPalette.leaf.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

struct TargetScorePickerSheetView: View {
    @Binding var selectedTargetScore: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemFill))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            HStack {
                Button("취소") { onCancel() }
                    .font(.pretendardMedium(16))
                    .foregroundStyle(AppPalette.forest)
                Spacer()
                Text("목표 점수 변경")
                    .font(.pretendardSemiBold(17))
                Spacer()
                Button("변경하기") { onConfirm() }
                    .font(.pretendardSemiBold(16))
                    .foregroundStyle(AppPalette.forest)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    Text("목표 TOEIC 점수를 변경해주세요")
                        .font(.pretendardBold(18))
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)

                    Text("선택한 점수에 맞는 단어와 문법이 추천됩니다")
                        .font(.pretendardMedium(14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        ForEach([600, 700, 800, 900], id: \.self) { score in
                            Button {
                                selectedTargetScore = score
                                HapticManager.shared.playTap()
                            } label: {
                                HStack {
                                    Text("\(score)점 이상")
                                        .font(.pretendardSemiBold(16))
                                    Spacer()
                                    if selectedTargetScore == score {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppPalette.forest)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedTargetScore == score ? AppPalette.forest.opacity(0.12) : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTargetScore == score ? AppPalette.forest : .clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

struct QuizCategoryChartView: View {
    let categoryCorrect: [String: Int]
    let categoryIncorrect: [String: Int]

    private static let categoryKoreanNames: [String: String] = [
        "Agreement": "일치",
        "Subject-Verb Agreement": "주어-동사 일치",
        "Collocation": "연어",
        "Conjunction": "접속사",
        "Gerund/Infinitive": "동명사/부정사",
        "Preposition": "전치사",
        "Pronoun": "대명사",
        "Relative Clause": "관계절",
        "Subjunctive": "가정법",
        "Tense": "시제",
        "Vocabulary": "어휘",
        "Voice": "태",
        "Word Form": "어형"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("문제 유형별 분석").font(.pretendardSemiBold(16))

            let allCategories = Set(Array(categoryCorrect.keys) + Array(categoryIncorrect.keys)).sorted()

            if allCategories.isEmpty {
                Text("아직 풀어본 문제가 없어요.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(allCategories, id: \.self) { cat in
                        let correct = categoryCorrect[cat] ?? 0
                        let incorrect = categoryIncorrect[cat] ?? 0
                        let total = correct + incorrect
                        let maxTotal = allCategories.map { (categoryCorrect[$0] ?? 0) + (categoryIncorrect[$0] ?? 0) }.max() ?? 1

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(koreanCategoryName(cat))
                                    .font(.caption).fontWeight(.medium)
                                Spacer()
                                Text("\(correct)")
                                    .font(.caption).fontWeight(.bold).foregroundStyle(AppPalette.mint)
                                Text("/")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("\(incorrect)")
                                    .font(.caption).fontWeight(.bold).foregroundStyle(.red)
                            }
                            GeometryReader { geo in
                                let barWidth = geo.size.width * (Double(total) / Double(max(1, maxTotal)))
                                let correctWidth = total > 0 ? barWidth * (Double(correct) / Double(total)) : 0

                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 10)

                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppPalette.mint)
                                            .frame(width: max(0, correctWidth), height: 10)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.red.opacity(0.6))
                                            .frame(width: max(0, barWidth - correctWidth), height: 10)
                                    }
                                }
                            }
                            .frame(height: 10)
                        }
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(AppPalette.mint).frame(width: 8, height: 8)
                        Text("정답").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.red.opacity(0.6)).frame(width: 8, height: 8)
                        Text("오답").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.06), AppPalette.leaf.opacity(0.03), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [AppPalette.leaf.opacity(0.4), AppPalette.forest.opacity(0.15), AppPalette.leaf.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    private func koreanCategoryName(_ category: String) -> String {
        Self.categoryKoreanNames[category] ?? category
    }
}
