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
    // 구독 상태
    @State private var isPro: Bool = false
    @State private var showSubscription: Bool = false
    @State private var showCancelSubscriptionAlert: Bool = false
    // 코드 입력
    @State private var showCodeInput: Bool = false
    @State private var codeInput: String = ""
    @State private var codeError: String? = nil
    @State private var codeSuccess: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    goalSection
                    quizCategoryChart
                    if !isPro { proPromoBanner }
                    if isPro { subscriptionInfoSection }
                    timerSettings
                    learningSettings
                    accountSection
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
            .alert("구독 취소", isPresented: $showCancelSubscriptionAlert) {
                Button("취소하기", role: .destructive) { cancelSubscription() }
                Button("닫기", role: .cancel) {}
            } message: {
                Text("구독을 취소하면 Pro 혜택이 즉시 종료됩니다. 정말 취소하시겠습니까?")
            }
            .sheet(isPresented: $showCodeInput, onDismiss: { codeInput = ""; codeError = nil; codeSuccess = false }) {
                codeInputSheet
            }
            .sheet(isPresented: $showSubscription, onDismiss: { loadData() }) {
                NavigationStack {
                    SubscriptionView()
                        .environment(authManager)
                }
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(AppPalette.forest).frame(width: 80, height: 80)
                Image(systemName: "person.fill").font(.system(size: 36)).foregroundStyle(.white)
            }

            if let p = profile {
                let level = TOEICScoreRange(rawValue: p.estimatedLevel) ?? .range600
                VStack(spacing: 4) {
                    Text("현재 수준")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(level.label)
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.black)
                }

                HStack(spacing: 24) {
                    statPill(icon: "target", label: "목표", value: "\(p.targetScore)점")
                    Divider().frame(height: 30)
                    statPill(icon: "flame", label: "연속학습", value: "\(streak)일")
                    Divider().frame(height: 30)
                    statPill(icon: "star", label: "총 XP", value: "\(totalXP)")
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppPalette.cream.opacity(0.40))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppPalette.leaf.opacity(0.30), lineWidth: 1))
        )
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline).fontWeight(.bold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Pro Promo Banner

    private var proPromoBanner: some View {
        Button { showSubscription = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.leaf)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Pro로 업그레이드")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.primary)
                        ProBadgeView()
                    }
                    Text("무제한 학습 · 단어저장 · 타이머 설정")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppPalette.leaf.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppPalette.leaf.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일일 목표").font(.headline)
            if let p = profile {
                HStack {
                    Label("단어", systemImage: "character.book.closed"); Spacer()
                    Text("\(p.dailyVocabGoal)개/일").fontWeight(.semibold)
                }.font(.subheadline)
                HStack {
                    Label("문법", systemImage: "text.book.closed"); Spacer()
                    Text("\(p.dailyGrammarGoal)개/일").fontWeight(.semibold)
                }.font(.subheadline)
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
            Text("문제 유형별 분석").font(.headline)

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
            HStack {
                Text("시간 제한 설정").font(.headline)
                if !isPro {
                    ProBadgeView()
                }
            }

            if !isPro {
                // 비Pro: 잠금 안내
                Button { showSubscription = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(AppPalette.leaf)
                        Text("Pro 구독 시 타이머 설정 가능")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Pro: 정상 표시
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

            Button { showCodeInput = true } label: {
                HStack {
                    Label("코드 입력", systemImage: "gift")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }.font(.subheadline)
            }.buttonStyle(.plain)

            if isPro {
                Divider()

                Button { showCancelSubscriptionAlert = true } label: {
                    HStack {
                        Label("구독 취소", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }.font(.subheadline)
                }.buttonStyle(.plain)
            }

            Divider()

            Button { showResetAlert = true } label: {
                HStack {
                    Label("전체 초기화", systemImage: "arrow.counterclockwise")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }.font(.subheadline)
            }.buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(spacing: 12) {
            if let uid = authManager.userID {
                Text("User ID: \(uid)").font(.caption2).foregroundStyle(.tertiary)
            }
            Button("로그아웃", role: .destructive) { authManager.signOut() }.font(.subheadline)
            Text("버전 1.0.0").font(.caption2).foregroundStyle(.tertiary)
        }.padding(16)
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
            isPro = p.isProActive
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

    // MARK: - Cancel Subscription

    private func cancelSubscription() {
        guard let p = profile else { return }
        p.isPro = false
        p.subscriptionPlan = ""
        p.proExpiresAt = nil
        try? modelContext.save()
        isPro = false
    }

    // MARK: - Redeem Code

    private func redeemCode() {
        let trimmed = codeInput.trimmingCharacters(in: .whitespaces)
        guard let p = profile else { codeError = "프로필 정보를 불러올 수 없습니다."; return }

        switch trimmed {
        case "kdjnaelm":
            // 영구 구독 코드
            p.isPro = true
            p.subscriptionPlan = "lifetime"
            p.proExpiresAt = nil   // nil = 영구
            if p.subscribedAt == nil { p.subscribedAt = Date() }
            try? modelContext.save()
            isPro = true
            codeSuccess = true
            codeError = nil
        default:
            codeError = "유효하지 않은 코드입니다."
            codeSuccess = false
        }
    }

    // MARK: - Subscription Info Section

    private var subscriptionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("구독 정보").font(.headline)

            if let p = profile {
                let plan = p.subscriptionPlan
                let planLabel: String = {
                    switch plan {
                    case "monthly":  return "월간 구독"
                    case "annual":   return "연간 구독"
                    case "lifetime": return "영구 구독 👑"
                    default:         return "구독 중"
                    }
                }()

                HStack {
                    Label("플랜", systemImage: "crown.fill")
                        .font(.subheadline).foregroundStyle(AppPalette.forest)
                    Spacer()
                    Text(planLabel)
                        .font(.subheadline).fontWeight(.semibold)
                }

                if let startDate = p.subscribedAt {
                    Divider()
                    HStack {
                        Label("구독 시작", systemImage: "calendar")
                            .font(.subheadline)
                        Spacer()
                        Text(startDate, style: .date)
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }

                if let expiresAt = p.proExpiresAt {
                    Divider()
                    HStack {
                        Label("만료일", systemImage: "calendar.badge.clock")
                            .font(.subheadline)
                        Spacer()
                        Text(expiresAt, style: .date)
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    Divider()
                    HStack {
                        Label("남은 기간", systemImage: "hourglass")
                            .font(.subheadline)
                        Spacer()
                        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
                        Text(remaining > 0 ? "\(remaining)일 남음" : "만료됨")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(remaining > 7 ? AppPalette.forest : .red)
                    }
                } else if plan == "lifetime" {
                    Divider()
                    HStack {
                        Label("남은 기간", systemImage: "infinity")
                            .font(.subheadline)
                        Spacer()
                        Text("영구")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppPalette.forest)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.leaf.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Code Input Sheet

    private var codeInputSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "gift.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppPalette.forest)

                VStack(spacing: 8) {
                    Text("코드 입력")
                        .font(.title2).fontWeight(.bold)
                    Text("보유하신 구독 코드를 입력해주세요.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    TextField("코드를 입력하세요", text: $codeInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 32)

                    if let error = codeError {
                        Text(error)
                            .font(.caption).foregroundStyle(.red)
                    }

                    if codeSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppPalette.forest)
                            Text("구독이 활성화되었습니다!")
                                .foregroundStyle(AppPalette.forest)
                        }
                        .font(.subheadline).fontWeight(.semibold)
                    }
                }

                Button {
                    redeemCode()
                } label: {
                    Text("적용하기")
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppPalette.forest)
                        )
                }
                .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("코드 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { showCodeInput = false }
                }
            }
        }
    }
}

