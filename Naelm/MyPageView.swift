//
//  MyPageView.swift
//  Naelm
//
//  마이페이지 — 수준, 목표점수, 연속학습일, 문제유형 그래프
//

import SwiftUI
import SwiftData

struct MyPageView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var profile: UserProfile?
    @State private var streak: Int = 0
    @State private var totalXP: Int = 0
    @State private var totalWordsStudied: Int = 0
    @State private var totalGrammarStudied: Int = 0
    @State private var showResetAlert = false
    // 문제유형별 통계
    @State private var categoryCorrect: [String: Int] = [:]
    @State private var categoryIncorrect: [String: Int] = [:]
    // 다크모드 설정
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0  // 0=시스템, 1=라이트, 2=다크
    // 타이머 설정
    @State private var timerEnabled: Bool = true
    @State private var vocabTimerSeconds: Int = 15
    @State private var grammarTimerSeconds: Int = 15
    // 개선사항 피드백
    @State private var showFeedback: Bool = false
    // 계정 삭제
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showDeleteAccountConfirmation: Bool = false

    // 프로필 카드 애니메이션
    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var iconFloat: CGFloat = 0

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
    @State private var marqueeOffset: CGFloat = 400
    @State private var marqueeTextWidth: CGFloat = 300

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    encouragementBanner
                    goalSection
                    quizCategoryChart
                    timerSettings
                    learningSettings
                }
                .padding(16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadData() }
            .alert("전체 초기화", isPresented: $showResetAlert) {
                Button("초기화", role: .destructive) { resetOnboarding() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 학습 데이터가 삭제되고 처음 상태로 돌아갑니다.")
            }
            .alert("계정 삭제", isPresented: $showDeleteAccountAlert) {
                Button("삭제하기", role: .destructive) { showDeleteAccountConfirmation = true }
                Button("취소", role: .cancel) {}
            } message: {
                Text("계정을 삭제하면 모든 학습 데이터, 구독 정보, 저장된 단어가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("정말 삭제하시겠습니까?", isPresented: $showDeleteAccountConfirmation) {
                Button("영구 삭제", role: .destructive) { deleteAccount() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("마지막 확인입니다. 계정 삭제 후에는 데이터를 복구할 수 없습니다.")
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
        }
    }

    // MARK: - Encouragement Banner (전광판 마키 애니메이션)

    private var encouragementBanner: some View {
        let message = "✦  " + Self.encouragements[dailyEncouragementIndex] + "     "
        return GeometryReader { geo in
            let containerWidth = geo.size.width
            ZStack(alignment: .leading) {
                // 두 개의 텍스트로 끊김 없는 루프 효과
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
                // 텍스트 폭을 대략 계산해서 연속 이동
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
            // 아바타 + 잔잔한 글로우
            ZStack {
                // 부드럽게 숨쉬는 글로우
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppPalette.leaf.opacity(glowOpacity), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 54
                        )
                    )
                    .frame(width: 108, height: 108)
                    .scaleEffect(glowScale)
                    .blur(radius: 8)

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
                    .offset(y: iconFloat)
            }

            if let p = profile {
                let level = TOEICScoreRange(rawValue: p.estimatedLevel) ?? .range600

                // 수준 뱃지
                VStack(spacing: 6) {
                    Text("현재 수준")
                        .font(.pretendardMedium(12))
                        .foregroundStyle(.secondary)

                    Text(level.label)
                        .font(.pretendardBold(26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppPalette.forest, AppPalette.leaf],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                // 스탯 카드들
                HStack(spacing: 12) {
                    statCard(icon: "target", label: "목표", value: "\(p.targetScore)점", color: AppPalette.forest)
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

                // 은은한 그라데이션 오버레이
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
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowScale = 1.18
                glowOpacity = 0.25
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                iconFloat = -4
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
            Text("일일 목표").font(.pretendardSemiBold(16))
            if let p = profile {
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Category Korean Names

    private static let categoryKoreanNames: [String: String] = [
        "Agreement": "일치",
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

                // 범례
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Timer Settings
    // ⚠️ 시간 제한 UI 비활성화됨 - 코드는 유지하되 UI는 숨김
    // 기본값: timerEnabled = true, 15초 고정
    // 활성화하려면 timerSettings를 body VStack에 다시 추가하세요

    private var timerSettings: some View {
        // UI 숨김 처리 - EmptyView 반환
        EmptyView()
        /* --- 비활성화된 UI (코드 보존) ---
        VStack(alignment: .leading, spacing: 14) {
            Text("시간 제한 설정").font(.headline)

            HStack {
                Label("시간 제한 기능", systemImage: "timer")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $timerEnabled)
                    .onChange(of: timerEnabled) { _, _ in saveTimerSettings() }
            }

            if timerEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("단어 학습 시간", systemImage: "character.book.closed")
                            .font(.subheadline)
                        Spacer()
                        Text("\(vocabTimerSeconds)초")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppPalette.forest)
                            .frame(width: 44)
                    }
                    Slider(value: Binding(
                        get: { Double(vocabTimerSeconds) },
                        set: { vocabTimerSeconds = Int($0); saveTimerSettings() }
                    ), in: 5...25, step: 1)
                    .tint(AppPalette.forest)
                    HStack {
                        Text("5초").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("25초").font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("문법 학습 시간", systemImage: "text.book.closed")
                            .font(.subheadline)
                        Spacer()
                        Text("\(grammarTimerSeconds)초")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppPalette.forest)
                            .frame(width: 44)
                    }
                    Slider(value: Binding(
                        get: { Double(grammarTimerSeconds) },
                        set: { grammarTimerSeconds = Int($0); saveTimerSettings() }
                    ), in: 5...25, step: 1)
                    .tint(AppPalette.forest)
                    HStack {
                        Text("5초").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("25초").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        --- */
    }

    // MARK: - Settings

    private var learningSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("설정").font(.headline)

            // 화면 모드
            HStack {
                Label("화면 모드", systemImage: "circle.lefthalf.filled")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $appearanceMode) {
                    Text("시스템").tag(0)
                    Text("라이트").tag(1)
                    Text("다크").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            Button { showFeedback = true } label: {
                HStack {
                    Label("개선사항 보내기", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }.font(.subheadline)
            }.buttonStyle(.plain)

            Divider()

            Button { showResetAlert = true } label: {
                HStack {
                    Label("전체 초기화", systemImage: "arrow.counterclockwise")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }.font(.subheadline)
            }.buttonStyle(.plain)

            Divider()

            Button { showDeleteAccountAlert = true } label: {
                HStack {
                    Label("계정 삭제", systemImage: "person.crop.circle.badge.minus")
                        .foregroundStyle(.red)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }.font(.subheadline)
            }.buttonStyle(.plain)

            Divider()

            Button("로그아웃", role: .destructive) { authManager.signOut() }.font(.subheadline)

            if let uid = authManager.userID {
                Text("User ID: \(uid)").font(.caption2).foregroundStyle(.tertiary)
            }

            Divider()

            // 개인정보 처리방침 및 이용약관 (통합)
            if let policyURL = URL(string: "https://lively-mayonnaise-192.notion.site/naelm") {
                Link(destination: policyURL) {
                    HStack {
                        Label("개인정보 처리방침 및 이용약관", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundStyle(.tertiary)
                    }.font(.subheadline)
                }.buttonStyle(.plain)
            }

            Text("버전 1.0.0").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Data

    private func loadData() {
        guard let userID = authManager.userID else { return }

        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        profile = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first

        // 타이머 설정 로드 (현재 UI 비활성화 - 기본값 15초 고정)
        if let p = profile {
            timerEnabled = true  // 항상 활성화
            vocabTimerSeconds = 15  // 기본 15초 고정
            grammarTimerSeconds = 15  // 기본 15초 고정
            // 저장된 값 업데이트
            p.timerEnabled = true
            p.vocabTimerSeconds = 15
            p.grammarTimerSeconds = 15
        }

        streak = GamificationService.currentStreak(userID: userID, context: modelContext)
        totalXP = GamificationService.totalXP(userID: userID, context: modelContext)

        // 문제유형별 통계
        let grammarPred = #Predicate<LearningProgress> {
            $0.userID == userID && $0.itemType == "grammar"
        }
        let progresses = (try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: grammarPred))) ?? []
        var correctMap: [String: Int] = [:]
        var incorrectMap: [String: Int] = [:]
        for p in progresses {
            let cat = p.grammar?.category ?? "Other"
            correctMap[cat, default: 0] += p.correctCount
            incorrectMap[cat, default: 0] += p.incorrectCount
        }
        categoryCorrect = correctMap
        categoryIncorrect = incorrectMap
    }

    private func saveTimerSettings() {
        guard let p = profile else { return }
        p.timerEnabled = timerEnabled
        p.vocabTimerSeconds = vocabTimerSeconds
        p.grammarTimerSeconds = grammarTimerSeconds
        try? modelContext.save()
    }

    private func resetOnboarding() {
        guard let userID = authManager.userID else { return }

        let profilePred = #Predicate<UserProfile> { $0.userID == userID }
        if let profiles = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: profilePred)) {
            for p in profiles { modelContext.delete(p) }
        }
        let progressPred = #Predicate<LearningProgress> { $0.userID == userID }
        if let progresses = try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: progressPred)) {
            for p in progresses { modelContext.delete(p) }
        }
        let activityPred = #Predicate<UserActivity> { $0.userID == userID }
        if let activities = try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: activityPred)) {
            for a in activities { modelContext.delete(a) }
        }
        let scorePred = #Predicate<MonthlyScore> { $0.userID == userID }
        if let scores = try? modelContext.fetch(FetchDescriptor<MonthlyScore>(predicate: scorePred)) {
            for s in scores { modelContext.delete(s) }
        }
        let bookmarkPred = #Predicate<BookmarkedWord> { $0.userID == userID }
        if let bookmarks = try? modelContext.fetch(FetchDescriptor<BookmarkedWord>(predicate: bookmarkPred)) {
            for b in bookmarks { modelContext.delete(b) }
        }
        try? modelContext.save()
        authManager.needsOnboarding = true
    }

    // MARK: - Delete Account

    /// App Store Review Guideline 5.1.1 — 계정 삭제 기능
    /// 사용자의 모든 데이터를 영구 삭제하고 로그아웃합니다.
    private func deleteAccount() {
        guard let userID = authManager.userID else { return }

        // 1. UserProfile 삭제
        let profilePred = #Predicate<UserProfile> { $0.userID == userID }
        if let profiles = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: profilePred)) {
            for p in profiles { modelContext.delete(p) }
        }

        // 2. LearningProgress 삭제
        let progressPred = #Predicate<LearningProgress> { $0.userID == userID }
        if let progresses = try? modelContext.fetch(FetchDescriptor<LearningProgress>(predicate: progressPred)) {
            for p in progresses { modelContext.delete(p) }
        }

        // 3. UserActivity 삭제
        let activityPred = #Predicate<UserActivity> { $0.userID == userID }
        if let activities = try? modelContext.fetch(FetchDescriptor<UserActivity>(predicate: activityPred)) {
            for a in activities { modelContext.delete(a) }
        }

        // 4. MonthlyScore 삭제
        let scorePred = #Predicate<MonthlyScore> { $0.userID == userID }
        if let scores = try? modelContext.fetch(FetchDescriptor<MonthlyScore>(predicate: scorePred)) {
            for s in scores { modelContext.delete(s) }
        }

        // 5. BookmarkedWord 삭제
        let bookmarkPred = #Predicate<BookmarkedWord> { $0.userID == userID }
        if let bookmarks = try? modelContext.fetch(FetchDescriptor<BookmarkedWord>(predicate: bookmarkPred)) {
            for b in bookmarks { modelContext.delete(b) }
        }

        // 6. Friendship 삭제
        let friendPred = #Predicate<Friendship> { $0.userID == userID || $0.friendID == userID }
        if let friends = try? modelContext.fetch(FetchDescriptor<Friendship>(predicate: friendPred)) {
            for f in friends { modelContext.delete(f) }
        }

        try? modelContext.save()

        // 7. Keychain 정리
        KeychainHelper.delete(key: KeychainHelper.userIDKey)

        // 8. 로그아웃
        authManager.signOut()
    }
}
