//
//  MyPageView.swift
//  Naelm
//
//  마이페이지 — 수준, 목표점수, 연속학습일, 문제유형 그래프
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct MyPageView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // ViewModel — 데이터/로직 전담
    @State private var viewModel: MyPageViewModel?

    // UI 전용 상태
    @State private var showTargetScorePicker: Bool = false
    @State private var selectedTargetScore: Int = 700
    @State private var glowOpacity: Double = 1.0
    @State private var levelGaugeProgress: Double = 0.0
    @State private var marqueeOffset: CGFloat = 400
    @State private var marqueeTextWidth: CGFloat = 300

    // ViewModel에서 읽는 편의 프로퍼티
    private var profile: UserProfile? { viewModel?.profile }
    private var streak: Int { viewModel?.streak ?? 0 }
    private var totalXP: Int { viewModel?.totalXP ?? 0 }
    private var categoryCorrect: [String: Int] { viewModel?.categoryCorrect ?? [:] }
    private var categoryIncorrect: [String: Int] { viewModel?.categoryIncorrect ?? [:] }

    // 응원 배너 (30개 - 매일 하나씩)
    private static let encouragements: [String] = [
        "오늘도 좋은 하루 되세요! ☀️",
        "꾸준한 학습이 실력을 만들어요 💪",
        "한 걸음씩, 목표에 가까워지고 있어요 🎯",
        "오늘의 노력이 내일의 점수가 돼요 📈",
        "당신의 도전을 응원합니다! 🌟",
        "작은 습관이 큰 변화를 만들어요 🌱",
        "포기하지 않는 당신이 최고예요 🏆",
        "매일 조금씩, 반드시 성장해요 🚀",
        "오늘의 학습이 내일의 자신감이 돼요 ✨",
        "토익 목표 달성, 충분히 가능해요! 💡",
        "지금 이 순간도 성장 중이에요 🌿",
        "단어 하나하나가 점수로 쌓여요 📚",
        "어제보다 오늘 더 나은 당신 👍",
        "꾸준함이 재능을 이겨요! 🔥",
        "오늘도 멋진 하루 만들어봐요 🌈",
        "실수해도 괜찮아요, 그게 학습이에요 😊",
        "당신의 노력은 반드시 결실을 맺어요 🌸",
        "영어 실력, 매일 조금씩 올라가고 있어요 📊",
        "목표를 향해 꾸준히! 응원해요 🎉",
        "오늘도 한 걸음 더 나아가는 당신! 👣",
        "스스로를 믿으세요, 할 수 있어요 💎",
        "새벽을 달리는 당신의 열정이 빛나요 🌙",
        "지금 당장 결과가 안 보여도, 쌓이고 있어요 ⏳",
        "학습의 즐거움을 느끼는 하루 되세요 🎵",
        "최고의 투자는 자기 자신에게! 💰",
        "원하는 점수, 반드시 나올 거예요 🎊",
        "매일 학습하는 당신은 이미 승리자예요 🏅",
        "오늘의 복습이 장기 기억의 열쇠예요 🔑",
        "끝까지 해내는 당신을 믿어요! 💫",
        "작은 도전들이 모여 큰 성취를 만들어요 🌊",
    ]
    private var dailyEncouragementIndex: Int {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return (dayOfYear - 1) % Self.encouragements.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── 최상단 인사 헤더 ──────────────────────────────
                    userGreetingHeader
                    profileCard
                    goalSection
                    quizCategoryChart
                    timerSettings
                }
                .padding(16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 첫 렌더링 완료 후 무거운 데이터 로드 → 진입 딜레이 제거
                DispatchQueue.main.async { loadData() }
            }
            .sheet(isPresented: $showTargetScorePicker) {
                targetScorePickerSheet
            }
        }
    }

    // MARK: - User Greeting Header (최상단)

    /// 프로필 카드 바로 위에 표시되는 인사 헤더
    /// "@@@님, {격려멘트}" 형태로 좌측 정렬 굵은 타이틀
    private var userGreetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let uid = authManager.userID {
                // 유저 ID를 간결하게 표시 (앞 8자 이하)
                let shortID = uid.count > 8 ? String(uid.prefix(8)) : uid
                Text("\(shortID)님,")
                    .font(.pretendardBold(24))
                    .foregroundStyle(.primary)
            }
            Text(Self.encouragements[dailyEncouragementIndex])
                .font(.pretendardMedium(15))
                .foregroundStyle(AppPalette.forest.opacity(0.80))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Encouragement Banner (전광판 마키 애니메이션)

    private var encouragementBanner: some View {
        let message = "✦  " + Self.encouragements[dailyEncouragementIndex] + "     "
        return GeometryReader { geo in
            let containerWidth = geo.size.width
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text(message)
                        .font(.pretendardMedium(13))
                        .foregroundStyle(AppPalette.forest)
                        .fixedSize()
                    Text(message)
                        .font(.pretendardMedium(13))
                        .foregroundStyle(AppPalette.forest)
                        .fixedSize()
                }
                .offset(x: marqueeOffset)
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .onAppear {
                marqueeOffset = containerWidth
                let approxWidth = CGFloat(message.count) * 8.5
                marqueeTextWidth = approxWidth
                withAnimation(.linear(duration: Double(approxWidth) / 45).repeatForever(autoreverses: false)) {
                    marqueeOffset = -approxWidth
                }
            }
        }
        .frame(height: 20)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppPalette.forest.opacity(0.06))
        )
        .overlay(
            HStack {
                LinearGradient(colors: [Color(.systemBackground).opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 20)
                Spacer()
                LinearGradient(colors: [.clear, Color(.systemBackground).opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 20)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 20) {
            // 아바타
            ZStack {
                // 부드럽게 숨쉬는 글로우 - 크기 변동 착시를 막기 위해 도형 전체에 opacity 적용
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppPalette.leaf, .clear], // 그라데이션 자체의 색상은 고정
                            center: .center,
                            startRadius: 0,
                            endRadius: 54
                        )
                    )
                    .frame(width: 108, height: 108)
                    .blur(radius: 8)
                    .opacity(glowOpacity) // 여기서 도형 전체의 밝기를 조절
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowOpacity)
                    .onAppear {
                        // 글로우 애니메이션도 첫 렌더 후 시작하여 진입 시 버벅임 방지
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
                let level = TOEICScoreRange(rawValue: p.estimatedLevel) ?? .range600
                let targetLabel = TOEICScoreRange.rangesUpTo(target: p.targetScore).last?.plusLabel ?? "\(p.targetScore)++"

                    // 수준 뱃지
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

                    // ── 레벨 & 경험치 게이지 ──────────────────────────
                    levelGaugeRow

                // 스탯 카드들
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

    // MARK: - Level Gauge Row

    private var levelGaugeRow: some View {
        let lv = GamificationService.level(fromTotalXP: totalXP)
        let progress = GamificationService.levelProgress(fromTotalXP: totalXP)
        let xpToNext = GamificationService.xpToNextLevel(fromTotalXP: totalXP)

        return HStack(spacing: 10) {
            // 레벨 뱃지
            Text("Lv.\(lv)")
                .font(.pretendardBold(14))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)


            // 게이지 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 배경
                    Capsule()
                        .fill(AppPalette.forest.opacity(0.12))
                        .frame(height: 18)
                        .colorMultiply(AppPalette.forest.opacity(0.12))

                    // 채워진 바
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

                    // 총 XP 텍스트 (반투명 오버레이)
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
            // 게이지 애니메이션: 첫 렌더 후 차오르는 효과
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

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.pretendardBold(16))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일일 목표").font(.pretendardSemiBold(16))
                Spacer()
                Button {
                    if let p = profile {
                        selectedTargetScore = p.targetScore
                    }
                    showTargetScorePicker = true
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

    // MARK: - Target Score Picker Sheet

    private var targetScorePickerSheet: some View {
        VStack(spacing: 0) {
            // 핸들 바
            Capsule()
                .fill(Color(.systemFill))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // 헤더
            HStack {
                Button("취소") { showTargetScorePicker = false }
                    .font(.pretendardMedium(16))
                    .foregroundStyle(AppPalette.forest)
                Spacer()
                Text("목표 점수 변경")
                    .font(.pretendardSemiBold(17))
                Spacer()
                Button("변경하기") {
                    updateTargetScore(selectedTargetScore)
                    showTargetScorePicker = false
                }
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

    // MARK: - Category Korean Names

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
        "Word Form": "어형",
    ]

    private func koreanCategoryName(_ category: String) -> String {
        Self.categoryKoreanNames[category] ?? category
    }

    // MARK: - Quiz Category Chart (수평 바 차트)

    private var quizCategoryChart: some View {
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

    // MARK: - Timer Settings
    private var timerSettings: some View {
        EmptyView()
    }

    // MARK: - Data

    private func loadData() {
        // ViewModel이 없으면 생성 (onAppear 최초 1회)
        if viewModel == nil {
            viewModel = MyPageViewModel(modelContext: modelContext, authManager: authManager)
        }
        viewModel?.loadData()
    }

    private func updateTargetScore(_ newScore: Int) {
        viewModel?.updateTargetScore(newScore)
    }
}
