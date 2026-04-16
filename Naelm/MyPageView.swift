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
    @State private var glowPhase: CGFloat = 0
    @State private var iconBounce: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    goalSection
                    quizCategoryChart
                    timerSettings
                    learningSettings
                }
                .padding(16)
            }
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

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 20) {
            // 아바타 + 글로우
            ZStack {
                // 글로우 링
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [AppPalette.forest, AppPalette.leaf, AppPalette.mint, AppPalette.forest],
                            center: .center,
                            startAngle: .degrees(glowPhase),
                            endAngle: .degrees(glowPhase + 360)
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 96, height: 96)
                    .blur(radius: 4)
                    .opacity(0.7)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest, AppPalette.leaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: AppPalette.forest.opacity(0.3), radius: 12, y: 4)

                Image(systemName: "person.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .offset(y: iconBounce ? -2 : 2)
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
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                glowPhase = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                iconBounce.toggle()
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

    private var timerSettings: some View {
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

            // 이용약관 / 개인정보 처리방침
            if let termsURL = URL(string: "https://toeigo.notion.site/terms") {
                Link(destination: termsURL) {
                    HStack {
                        Label("이용약관", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundStyle(.tertiary)
                    }.font(.subheadline)
                }.buttonStyle(.plain)
            }

            Divider()

            if let privacyURL = URL(string: "https://toeigo.notion.site/privacy") {
                Link(destination: privacyURL) {
                    HStack {
                        Label("개인정보 처리방침", systemImage: "hand.raised")
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

        // 타이머 설정 로드
        if let p = profile {
            timerEnabled = p.timerEnabled
            vocabTimerSeconds = p.vocabTimerSeconds
            grammarTimerSeconds = p.grammarTimerSeconds
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
