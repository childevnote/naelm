import SwiftUI

struct DashboardGreetingBannerView: View {
    let totalDaysStudied: Int
    let totalWordsStudied: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.forest.opacity(0.08), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppPalette.leaf.opacity(0.20), lineWidth: 1)
                )

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if totalDaysStudied > 0 {
                        Text("학습 \(totalDaysStudied)일 만에 \(totalWordsStudied)개의 단어를 학습했어요!")
                            .font(.pretendardSemiBold(14))
                            .foregroundStyle(AppPalette.forest)
                    } else {
                        Text("오늘부터 토익 학습을 시작해보세요!")
                            .font(.pretendardSemiBold(14))
                            .foregroundStyle(AppPalette.forest)
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                Spacer()
                Color.clear.frame(width: 90)
            }
        }
        .frame(height: 40)
        .overlay(alignment: .topTrailing) {
            Image("NaelmHome")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 2, y: 5)
                .offset(x: 10, y: -65)
        }
    }
}

struct DashboardTopSectionView: View {
    let streak: Int
    let monthlyActivity: [Date: Int]

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("\(streak)")
                    .font(.dashboardNumber)
                    .foregroundStyle(AppPalette.forest)
                Text("연속 학습")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 72)

            GrassChartView(monthlyActivity: monthlyActivity)
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

struct GrassChartView: View {
    let monthlyActivity: [Date: Int]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (0..<28).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let maxXP = max(1, monthlyActivity.values.max() ?? 1)

        return VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if idx < days.count {
                            let day = days[idx]
                            let xp = monthlyActivity[day] ?? 0
                            let isToday = calendar.isDateInToday(day)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(grassColorProportional(xp: xp, maxXP: maxXP))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    isToday ? RoundedRectangle(cornerRadius: 3).stroke(AppPalette.forest, lineWidth: 1.5) : nil
                                )
                        }
                    }
                }
            }
        }
    }

    private func grassColorProportional(xp: Int, maxXP: Int) -> Color {
        guard xp > 0 else { return Color.gray.opacity(0.12) }
        let ratio = Double(xp) / Double(maxXP)
        let opacity = 0.20 + ratio * 0.80
        return AppPalette.leaf.opacity(opacity)
    }
}

struct TodayLearningSectionView: View {
    let dueVocabCount: Int
    let dueGrammarCount: Int
    let todayWordsStudied: Int
    let todayGrammarStudied: Int
    let dailyVocabGoal: Int
    let dailyGrammarGoal: Int
    let vocabCompleted: Bool
    let grammarCompleted: Bool
    let onReviewTap: (Int) -> Void
    let onVocabTap: (Bool) -> Void
    let onGrammarTap: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘의 학습").font(.pretendardSemiBold(16))
                Spacer()
                if vocabCompleted && grammarCompleted {
                    Text("오늘 학습 완료! 🎉")
                        .font(.captionBold)
                        .foregroundStyle(BrandTheme.knewIt)
                }
            }

            let totalDue = dueVocabCount + dueGrammarCount
            Button {
                onReviewTap(totalDue)
            } label: {
                TodayTaskRowView(
                    icon: "arrow.clockwise", label: "복습 대기",
                    progress: "\(totalDue)개",
                    color: .orange,
                    subtitle: "단어 \(dueVocabCount)개 / 문법 \(dueGrammarCount)개",
                    isCompleted: false
                )
            }
            .buttonStyle(.plain)

            Button {
                onVocabTap(vocabCompleted)
            } label: {
                TodayTaskRowView(
                    icon: "character.book.closed", label: "단어",
                    progress: vocabCompleted ? "완료!" : "\(todayWordsStudied)/\(dailyVocabGoal)개",
                    color: vocabCompleted ? AppPalette.mint : AppPalette.forest,
                    subtitle: vocabCompleted ? "오늘 목표 달성! 내일 다시 만나요" : "탭하여 단어 학습 시작",
                    isCompleted: vocabCompleted
                )
            }
            .buttonStyle(.plain)

            Button {
                onGrammarTap(grammarCompleted)
            } label: {
                TodayTaskRowView(
                    icon: "text.book.closed", label: "문법",
                    progress: grammarCompleted ? "완료!" : "\(todayGrammarStudied)/\(dailyGrammarGoal)개",
                    color: grammarCompleted ? AppPalette.mint : AppPalette.grammarBrown,
                    subtitle: grammarCompleted ? "오늘 목표 달성! 내일 다시 만나요" : "탭하여 문법 퀴즈 시작",
                    isCompleted: grammarCompleted
                )
            }
            .buttonStyle(.plain)
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

struct TodayTaskRowView: View {
    let icon: String
    let label: String
    let progress: String
    let color: Color
    let subtitle: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(isCompleted ? 0.12 : 0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.pretendardSemiBold(15))
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(progress)
                .font(.pretendardBold(15))
                .foregroundStyle(color)
            if !isCompleted {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(isCompleted ? 0.03 : 0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.75 : 1.0)
        .contentShape(Rectangle())
    }
}

struct WeeklyChartSectionView: View {
    let weeklyHistory: [DailySummary]
    let dailyGoal: Int
    @Binding var selectedWeekDay: DailySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이번 주 활동").font(.pretendardSemiBold(16))
                Spacer()
                if let sel = selectedWeekDay {
                    Text("\(sel.weekdayShort) \(sel.xpEarned) XP")
                        .font(.pretendardBold(13))
                        .foregroundStyle(AppPalette.forest)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyHistory) { day in
                    VStack(spacing: 4) {
                        if selectedWeekDay?.id == day.id && day.xpEarned > 0 {
                            Text("\(day.xpEarned)")
                                .font(.pretendard(9)).fontWeight(.bold)
                                .foregroundStyle(AppPalette.forest)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Text(" ").font(.pretendard(9))
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedWeekDay?.id == day.id
                                  ? AppPalette.gold
                                  : (day.goalMet ? AppPalette.mint : (day.xpEarned > 0 ? AppPalette.leaf : Color.gray.opacity(0.2))))
                            .frame(width: 30, height: barHeight(xp: day.xpEarned))
                        Text(day.weekdayShort)
                            .font(.pretendard(10))
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? .primary : .secondary)
                            .fontWeight(Calendar.current.isDateInToday(day.date) ? .bold : .regular)
                        if day.goalMet {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10)).foregroundStyle(AppPalette.mint)
                        } else {
                            Circle().fill(.clear).frame(width: 10, height: 10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedWeekDay?.id == day.id {
                                selectedWeekDay = nil
                            } else {
                                selectedWeekDay = day
                            }
                        }
                        HapticManager.shared.playTap()
                    }
                }
            }
            .frame(height: 130)
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

    private func barHeight(xp: Int) -> CGFloat {
        let maxHeight: CGFloat = 80
        let maxXP = max(weeklyHistory.map(\.xpEarned).max() ?? 1, dailyGoal)
        return max(4, CGFloat(xp) / CGFloat(maxXP) * maxHeight)
    }
}
