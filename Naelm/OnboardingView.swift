//
//  OnboardingView.swift
//  Naelm
//
//  온보딩 플로우: 목표 점수 선택 → 수준 파악 테스트 → 완료
//

import SwiftUI
import SwiftData

// MARK: - Onboarding Flow

struct OnboardingView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// 온보딩 완료 시 RootView에 알림
    var onComplete: () -> Void = {}

    @State private var step: OnboardingStep = .targetScore
    @State private var selectedTarget: Int = 700
    @State private var placementAnswers: [(level: Int, correct: Bool)] = []
    @State private var currentQ: Int = 0
    @State private var placementQuestions: [PlacementQuestion] = []
    @State private var estimatedLevel: Int = 0

    // 타이머
    @State private var timerRemaining: Double = 10.0
    @State private var timerRunning: Bool = false
    @State private var timer: Timer? = nil

    enum OnboardingStep {
        case targetScore, placementIntro, placementTest, result
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? BrandTheme.backgroundGradientDark : BrandTheme.backgroundGradient)
                .ignoresSafeArea()

            switch step {
            case .targetScore:
                targetScoreView
            case .placementIntro:
                placementIntroView
            case .placementTest:
                placementTestView
            case .result:
                resultView
            }
        }
    }

    // MARK: - Step 1: Target Score

    private var targetScoreView: some View {
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
                step = .placementIntro
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

    // MARK: - Step 2: Placement Intro

    private var placementIntroView: some View {
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
                    loadPlacementQuestions()
                    step = .placementTest
                    startTimer()
                } label: {
                    Text("테스트 시작")
                        .font(.headline).frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent)

                Button {
                    finishOnboarding(level: 2)
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

    // MARK: - Step 3: Placement Test

    private var placementTestView: some View {
        VStack(spacing: 16) {
            // Progress
            ProgressView(value: Double(currentQ), total: Double(placementQuestions.count))
                .tint(BrandTheme.accent)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            HStack {
                Text("\(currentQ + 1) / \(placementQuestions.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if currentQ < placementQuestions.count {
                    let lvl = placementQuestions[currentQ].difficulty
                    let scoreLbl = TOEICScoreRange.from(frequencyLevel: lvl).shortLabel
                    Text("\(scoreLbl)++")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(BrandTheme.accent.opacity(0.15)))
                }
            }
            .padding(.horizontal, 24)

            // 타이머 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(timerRemaining > 5 ? BrandTheme.knewIt : timerRemaining > 3 ? .orange : .red)
                        .frame(width: geo.size.width * max(0, timerRemaining / 10.0), height: 5)
                        .animation(.linear(duration: 0.1), value: timerRemaining)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 24)

            if currentQ < placementQuestions.count {
                let q = placementQuestions[currentQ]

                VStack(spacing: 16) {
                    // 문제 유형 표시
                    Text(q.type == .vocabulary ? "단어" : "문법")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(BrandTheme.accent)

                    // 문제
                    Text(q.question)
                        .font(.title3).fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // 보기 (5지선다: 4개 + 모르겠다)
                    VStack(spacing: 10) {
                        ForEach(q.options, id: \.self) { option in
                            Button {
                                answerQuestion(option: option, question: q)
                            } label: {
                                Text(option)
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                        }

                        // 모르겠다 버튼
                        Button {
                            answerQuestion(option: nil, question: q)
                        } label: {
                            Text("모르겠다")
                                .font(.body).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Step 4: Result

    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundStyle(BrandTheme.accent)

            Text("수준 파악 완료!")
                .font(.title).fontWeight(.bold)

            let correctCount = placementAnswers.filter(\.correct).count
            let total = placementAnswers.count

            Text("\(total)문제 중 \(correctCount)문제 정답")
                .font(.headline).foregroundStyle(.secondary)

            // 구간별 결과 표시
            VStack(spacing: 8) {
                ForEach([1, 2, 3, 4], id: \.self) { lvl in
                    let lvlAnswers = placementAnswers.filter { $0.level == lvl }
                    let lvlCorrect = lvlAnswers.filter(\.correct).count
                    let scoreLbl = TOEICScoreRange(rawValue: lvl)?.label ?? ""
                    HStack {
                        Text(scoreLbl).font(.caption).frame(width: 60, alignment: .leading)
                        ProgressView(value: Double(lvlCorrect), total: 5.0)
                            .tint(lvlCorrect >= 3 ? BrandTheme.knewIt : .orange)
                        Text("\(lvlCorrect)/5").font(.caption).fontWeight(.bold).frame(width: 30)
                    }
                }
            }
            .padding(.horizontal, 32)

            let levelRange = TOEICScoreRange(rawValue: estimatedLevel) ?? .range600
            Text("추정 수준: \(levelRange.label)")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(BrandTheme.accent)

            Text("목표: \(selectedTarget)점")
                .font(.subheadline).foregroundStyle(.secondary)

            Spacer()

            Button {
                finishOnboarding(level: estimatedLevel)
            } label: {
                Text("학습 시작하기")
                    .font(.headline).frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandTheme.accent)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Timer

    // ARCH FIX: Timer uses Task @MainActor for safe struct state mutation
    private func startTimer() {
        timerRemaining = 10.0
        timerRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard timerRunning else { return }
                timerRemaining -= 0.1
                if timerRemaining <= 0 {
                    if currentQ < placementQuestions.count {
                        let q = placementQuestions[currentQ]
                        placementAnswers.append((level: q.difficulty, correct: false))
                        HapticManager.shared.playIncorrect()
                        moveToNextQuestion()
                    }
                }
            }
        }
    }

    private func resetTimer() {
        timerRemaining = 10.0
    }

    private func stopTimer() {
        timerRunning = false
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Answer Logic

    private func answerQuestion(option: String?, question: PlacementQuestion) {
        let correct: Bool
        if let opt = option {
            correct = opt == question.correctAnswer
        } else {
            correct = false // "모르겠다" → 오답
        }

        placementAnswers.append((level: question.difficulty, correct: correct))

        if correct { HapticManager.shared.playCorrect() }
        else { HapticManager.shared.playIncorrect() }

        moveToNextQuestion()
    }

    private func moveToNextQuestion() {
        if currentQ + 1 >= placementQuestions.count {
            stopTimer()
            calculateLevel()
            step = .result
        } else {
            withAnimation { currentQ += 1 }
            resetTimer()
        }
    }

    // MARK: - Question Loading

    private func loadPlacementQuestions() {
        // 각 수준별 5문제씩 = 20문제
        // 기존 Vocabulary/Grammar 데이터에서 수준별 선정
        let vocabs = fetchAllVocab()
        let grammars = fetchAllGrammar()

        var qs: [PlacementQuestion] = []
        // 전역 중복 방지용 영어 단어 집합 (모든 makeVocabQuestions 호출 간 공유)
        var usedEnglish = Set<String>()

        // 600점대 5문제: vocab level 1 (3) + grammar level 1 (2)
        qs += makeVocabQuestions(from: vocabs, level: 1, count: 3, targetLevel: 1, allVocabs: vocabs, usedEnglish: &usedEnglish)
        qs += makeGrammarQuestions(from: grammars, level: 1, count: 2, targetLevel: 1)

        // 700점대 5문제: vocab level 2 (3) + grammar level 2 (2)
        qs += makeVocabQuestions(from: vocabs, level: 2, count: 3, targetLevel: 2, allVocabs: vocabs, usedEnglish: &usedEnglish)
        qs += makeGrammarQuestions(from: grammars, level: 2, count: 2, targetLevel: 2)

        // 800점대 5문제: vocab level 3 (3) + grammar level 3 (2)
        qs += makeVocabQuestions(from: vocabs, level: 3, count: 3, targetLevel: 3, allVocabs: vocabs, usedEnglish: &usedEnglish)
        qs += makeGrammarQuestions(from: grammars, level: 3, count: 2, targetLevel: 3)

        // 900점대 5문제: vocab level 3 고급 (3) + grammar level 4 (2)
        qs += makeVocabQuestions(from: vocabs, level: 3, count: 3, targetLevel: 4, allVocabs: vocabs, usedEnglish: &usedEnglish)
        qs += makeGrammarQuestions(from: grammars, level: 4, count: 2, targetLevel: 4)

        // 600→700→800→900 순서대로 배치 (섞지 않고 점점 어려워지게)
        placementQuestions = qs
        currentQ = 0
        placementAnswers = []
    }

    private func makeVocabQuestions(from vocabs: [Vocabulary], level: Int, count: Int, targetLevel: Int, allVocabs: [Vocabulary], usedEnglish: inout Set<String>) -> [PlacementQuestion] {
        // 전역 usedEnglish 집합에 없는 항목만 후보로 사용
        let filtered = vocabs.filter {
            $0.frequencyLevel == level && !usedEnglish.contains($0.english.lowercased())
        }.shuffled()
        var result: [PlacementQuestion] = []
        for v in filtered {
            guard result.count < count else { break }

            // 같은 품사에서 오답을 뽑되, 정답과 동일 korean이 아닌 것만
            let samePOS = allVocabs.filter {
                $0.partOfSpeech == v.partOfSpeech &&
                $0.korean != v.korean &&
                $0.english.lowercased() != v.english.lowercased()
            }
            var distractors = Array(samePOS.map(\.korean).shuffled().prefix(3))
            // 빈 문자열 필터링 및 중복 제거
            distractors = distractors.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != v.korean }
            // 부족하면 다른 단어에서 채움
            if distractors.count < 3 {
                let others = allVocabs.filter {
                    $0.korean != v.korean &&
                    !distractors.contains($0.korean) &&
                    !$0.korean.trimmingCharacters(in: .whitespaces).isEmpty
                }
                distractors += Array(others.map(\.korean).shuffled().prefix(3 - distractors.count))
            }
            // 최종 빈칸/정답과 동일한 보기 제거
            distractors = Array(Set(distractors)).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != v.korean }
            var options = [v.korean] + Array(distractors.prefix(3))
            options.shuffle()
            // 옵션이 4개 미만이면 건너뜀 (4지선다 보장)
            guard options.count >= 4 else { continue }
            usedEnglish.insert(v.english.lowercased())
            result.append(PlacementQuestion(
                type: .vocabulary,
                question: "'\(v.english)'의 뜻은?",
                options: options,
                correctAnswer: v.korean,
                difficulty: targetLevel
            ))
        }
        return result
    }

    private func makeGrammarQuestions(from grammars: [Grammar], level: Int, count: Int, targetLevel: Int) -> [PlacementQuestion] {
        let filtered = grammars.filter { $0.difficultyLevel == level }.shuffled()
        // blankTarget이 있고 correctExample에 실제로 포함되는 문법만 선택
        let validGrammars = filtered.filter { g in
            !g.blankTarget.isEmpty &&
            !g.correctExample.isEmpty &&
            g.correctExample.contains(g.blankTarget) &&
            !g.distractors.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let selected = Array(validGrammars.prefix(count))
        // 이미 사용된 blankTarget 추적 (중복 방지)
        var usedTargets = Set<String>()
        var result: [PlacementQuestion] = []
        for g in selected {
            guard !usedTargets.contains(g.blankTarget.lowercased()) else { continue }
            usedTargets.insert(g.blankTarget.lowercased())

            let sentenceWithBlank = g.correctExample.replacingOccurrences(of: g.blankTarget, with: "___")
            guard sentenceWithBlank != g.correctExample else { continue }

            var distractors = g.distractors.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0 != g.blankTarget }
            // 빈칸인 보기 제거 및 중복 제거
            distractors = Array(Set(distractors)).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let fallbacks = ["however", "therefore", "although", "moreover", "consequently", "nevertheless"]
            for f in fallbacks.shuffled() {
                guard distractors.count < 3 else { break }
                if f != g.blankTarget && !distractors.contains(f) {
                    distractors.append(f)
                }
            }
            var options = [g.blankTarget] + Array(distractors.prefix(3))
            options.shuffle()

            result.append(PlacementQuestion(
                type: .grammar,
                question: sentenceWithBlank,
                options: options,
                correctAnswer: g.blankTarget,
                difficulty: targetLevel
            ))
        }
        return result
    }

    private func fetchAllVocab() -> [Vocabulary] {
        let descriptor = FetchDescriptor<Vocabulary>(sortBy: [SortDescriptor(\.frequencyLevel)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllGrammar() -> [Grammar] {
        let descriptor = FetchDescriptor<Grammar>(sortBy: [SortDescriptor(\.difficultyLevel)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Level Calculation

    private func calculateLevel() {
        // 각 구간별 정답 수 계산
        var scoreByLevel: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
        for a in placementAnswers {
            if a.correct { scoreByLevel[a.level, default: 0] += 1 }
        }

        let s600 = scoreByLevel[1] ?? 0  // /5
        let s700 = scoreByLevel[2] ?? 0  // /5
        let s800 = scoreByLevel[3] ?? 0  // /5
        let s900 = scoreByLevel[4] ?? 0  // /5
        let totalCorrect = s600 + s700 + s800 + s900

        // 수준 결정 알고리즘:
        // 1) 해당 구간 3개 이상 맞춰야 해당 구간 인정
        // 2) 하위 구간 기본 점수 조건: 해당 구간 인정하려면 바로 아래 구간도 2개 이상 맞춰야 함
        // 3) 가장 높은 인정 구간을 수준으로 결정
        // 4) 어디도 인정 안되면 600점 미만

        var level = 1  // 기본: 600점 미만 → estimatedLevel 1

        if s600 >= 3 {
            level = 2  // 600점대
        }
        if s600 >= 2 && s700 >= 3 {
            level = 3  // 700점대
        }
        if s700 >= 2 && s800 >= 3 {
            level = 4  // 800점대
        }
        if s800 >= 2 && s900 >= 3 {
            level = 5  // 900점대
        }

        // 보정: 전체 정답이 매우 적으면 하향
        if totalCorrect < 4 { level = 1 }

        estimatedLevel = level
    }

    // MARK: - Finish

    private func finishOnboarding(level: Int) {
        guard let userID = authManager.userID else { return }

        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        let profile: UserProfile
        if let existing = try? modelContext.fetch(descriptor).first {
            profile = existing
        } else {
            profile = UserProfile(userID: userID)
            modelContext.insert(profile)
        }

        profile.targetScore = selectedTarget
        profile.estimatedLevel = level
        profile.hasCompletedOnboarding = true
        profile.hasCompletedPlacementTest = (step == .result)

        let gap = max(0, selectedTarget - level * 100 - 400)
        profile.dailyVocabGoal = min(40, max(10, 15 + gap / 50))
        profile.dailyGrammarGoal = min(20, max(5, 8 + gap / 80))

        try? modelContext.save()
        HapticManager.shared.playOnboardingComplete()
        onComplete()
    }
}

// MARK: - Placement Question

struct PlacementQuestion: Identifiable {
    let id = UUID()
    let type: QuestionType
    let question: String
    let options: [String]
    let correctAnswer: String
    let difficulty: Int  // 1=600, 2=700, 3=800, 4=900

    enum QuestionType {
        case vocabulary, grammar
    }
}
