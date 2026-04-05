//
//  OnboardingView.swift
//  Toeigo
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
    @State private var placementAnswers: [Bool] = []
    @State private var currentQ: Int = 0
    @State private var placementQuestions: [PlacementQuestion] = []
    @State private var showResult = false
    @State private var estimatedLevel: Int = 0

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
                .font(.title2).fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("선택한 점수에 맞는 단어와 문법을 추천해 드립니다")
                .font(.subheadline).foregroundStyle(.secondary)
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
                            if score == 900 {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
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
                .font(.title2).fontWeight(.bold)

            Text("단어 10문제 + 문법 10문제로\n현재 실력을 진단합니다.\n약 3분 소요됩니다.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    loadPlacementQuestions()
                    step = .placementTest
                } label: {
                    Text("테스트 시작")
                        .font(.headline).frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent)

                Button {
                    // 테스트 건너뛰기 → 기본 수준 설정
                    finishOnboarding(level: 2) // 600점대로 기본 설정
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
        VStack(spacing: 20) {
            // Progress
            ProgressView(value: Double(currentQ), total: Double(placementQuestions.count))
                .tint(BrandTheme.accent)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Text("\(currentQ + 1) / \(placementQuestions.count)")
                .font(.caption).foregroundStyle(.secondary)

            if currentQ < placementQuestions.count {
                let q = placementQuestions[currentQ]

                VStack(spacing: 16) {
                    // 문제 유형 표시
                    Text(q.type == .vocabulary ? "📖 단어" : "📝 문법")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(BrandTheme.accent)

                    // 문제
                    Text(q.question)
                        .font(.title3).fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // 4지선다
                    VStack(spacing: 10) {
                        ForEach(q.options, id: \.self) { option in
                            Button {
                                let correct = option == q.correctAnswer
                                placementAnswers.append(correct)
                                if correct { HapticManager.shared.playCorrect() }
                                else { HapticManager.shared.playIncorrect() }

                                if currentQ + 1 >= placementQuestions.count {
                                    calculateLevel()
                                    step = .result
                                } else {
                                    withAnimation { currentQ += 1 }
                                }
                            } label: {
                                Text(option)
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
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

            let correctCount = placementAnswers.filter { $0 }.count
            let total = placementAnswers.count

            Text("\(total)문제 중 \(correctCount)문제 정답")
                .font(.headline).foregroundStyle(.secondary)

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

    // MARK: - Logic

    private func loadPlacementQuestions() {
        // 번들의 Vocabulary/Grammar에서 난이도별로 골고루 뽑아 20문제 생성
        let vocabs = fetchVocabSample()
        let grammars = fetchGrammarSample()

        var qs: [PlacementQuestion] = []

        // 단어 10문제: 영어→한국어 사지선다
        for v in vocabs {
            let wrongOptions = generateVocabDistractors(correct: v.korean, allVocabs: vocabs)
            var options = [v.korean] + wrongOptions
            options.shuffle()
            qs.append(PlacementQuestion(
                type: .vocabulary,
                question: "'\(v.english)'의 뜻은?",
                options: options,
                correctAnswer: v.korean,
                difficulty: v.frequencyLevel
            ))
        }

        // 문법 10문제: 빈칸 채우기
        for g in grammars {
            let words = g.correctExample.split(separator: " ").map(String.init)
            let skip = Set(["the","a","an","is","are","was","were","in","on","at","to","of","for","and","or","but","by","it","be"])
            let candidates = words.enumerated().filter { $0.element.lowercased().trimmingCharacters(in: .punctuationCharacters).count >= 3 && !skip.contains($0.element.lowercased().trimmingCharacters(in: .punctuationCharacters)) }

            if let target = candidates.randomElement() {
                var blanked = words
                blanked[target.offset] = "___"
                let correct = target.element.trimmingCharacters(in: .punctuationCharacters)
                let fallbacks = ["however", "therefore", "although", "nevertheless", "moreover", "consequently"]
                var wrongs = Array(fallbacks.filter { $0 != correct.lowercased() }.shuffled().prefix(3))
                while wrongs.count < 3 { wrongs.append("otherwise") }
                var options = [correct] + wrongs
                options.shuffle()
                qs.append(PlacementQuestion(
                    type: .grammar,
                    question: blanked.joined(separator: " "),
                    options: options,
                    correctAnswer: correct,
                    difficulty: g.difficultyLevel
                ))
            }
        }

        placementQuestions = qs.shuffled()
        currentQ = 0
        placementAnswers = []
    }

    private func fetchVocabSample() -> [Vocabulary] {
        let descriptor = FetchDescriptor<Vocabulary>(sortBy: [SortDescriptor(\.frequencyLevel)])
        guard let all = try? modelContext.fetch(descriptor), !all.isEmpty else { return [] }
        // 난이도별로 골고루 뽑기
        let grouped = Dictionary(grouping: all, by: \.frequencyLevel)
        var result: [Vocabulary] = []
        for level in grouped.keys.sorted() {
            let items = grouped[level] ?? []
            result.append(contentsOf: items.shuffled().prefix(4))
        }
        return Array(result.shuffled().prefix(10))
    }

    private func fetchGrammarSample() -> [Grammar] {
        let descriptor = FetchDescriptor<Grammar>(sortBy: [SortDescriptor(\.difficultyLevel)])
        guard let all = try? modelContext.fetch(descriptor), !all.isEmpty else { return [] }
        let grouped = Dictionary(grouping: all, by: \.difficultyLevel)
        var result: [Grammar] = []
        for level in grouped.keys.sorted() {
            let items = grouped[level] ?? []
            result.append(contentsOf: items.shuffled().prefix(4))
        }
        return Array(result.shuffled().prefix(10))
    }

    private func generateVocabDistractors(correct: String, allVocabs: [Vocabulary]) -> [String] {
        let pool = allVocabs.map(\.korean).filter { $0 != correct }
        return Array(pool.shuffled().prefix(3))
    }

    private func calculateLevel() {
        let correctCount = placementAnswers.filter { $0 }.count
        // 20문제 중 정답 수에 따라 수준 결정
        switch correctCount {
        case 0..<5:   estimatedLevel = 1  // 600점 미만
        case 5..<10:  estimatedLevel = 2  // 600점대
        case 10..<14: estimatedLevel = 3  // 700점대
        case 14..<18: estimatedLevel = 4  // 800점대
        default:      estimatedLevel = 5  // 900점대
        }
    }

    private func finishOnboarding(level: Int) {
        guard let userID = authManager.userID else { return }

        // UserProfile 생성 또는 업데이트
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

        // 목표 점수와 수준에 따른 일일 학습량 자동 설정
        let gap = max(0, selectedTarget - level * 100 - 400)
        profile.dailyVocabGoal = min(40, max(10, 15 + gap / 50))
        profile.dailyGrammarGoal = min(20, max(5, 8 + gap / 80))

        try? modelContext.save()

        // RootView에 온보딩 완료 알림 → MainDashboardView로 전환
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
    let difficulty: Int

    enum QuestionType {
        case vocabulary, grammar
    }
}
