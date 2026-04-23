//
//  QuizViewModel.swift
//  Naelm
//
//  문법 퀴즈 ViewModel — 개선된 보기 생성.
//  ──────────────────────────────────────────────
//  핵심 개선:
//    • Grammar.blankTarget: 빈칸으로 만들 정답이 JSON에 미리 지정
//    • Grammar.distractors: 토익 수준의 애매한 오답 3개가 JSON에 미리 지정
//    • fallback: blankTarget 없으면 기존 자동 추출 로직 사용
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

// MARK: - Quiz Question Model

struct QuizQuestion: Identifiable {
    let id = UUID()
    let grammar: Grammar
    let sentenceWithBlank: String
    let correctAnswer: String
    let options: [String]
    let incorrectExample: String
    let tip: String
}

struct QuizAnswer {
    let question: QuizQuestion
    let selectedAnswer: String
    let isCorrect: Bool
}

// MARK: - QuizViewModel

@MainActor
@Observable
final class QuizViewModel {

    var questions: [QuizQuestion] = []
    var currentIndex: Int = 0
    var answers: [QuizAnswer] = []
    var selectedAnswer: String? = nil
    var isAnswerRevealed: Bool = false
    var isQuizComplete: Bool = false
    var showExplanation: Bool = false
    var isLoading: Bool = false

    /// 현재 문제 시작 시각 (응답 시간 측정용)
    private var questionStartTime: Date = Date()

    var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    var correctCount: Int { answers.filter(\.isCorrect).count }
    var incorrectCount: Int { answers.filter { !$0.isCorrect }.count }
    var accuracy: Double {
        guard !answers.isEmpty else { return 0 }
        return Double(correctCount) / Double(answers.count)
    }

    private let sessionManager: LearningSessionManager

    init(sessionManager: LearningSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Load Quiz

    func loadQuiz(userID: String, context: ModelContext, targetScore: Int = 700) {
        isLoading = true
        isQuizComplete = false
        currentIndex = 0
        answers = []
        selectedAnswer = nil
        isAnswerRevealed = false
        questionStartTime = Date()

        // 사용자 프로필에서 수준 로드
        let profilePred = #Predicate<UserProfile> { $0.userID == userID }
        let estimatedLevel = (try? context.fetch(FetchDescriptor<UserProfile>(predicate: profilePred)).first?.estimatedLevel) ?? 2

        let targetLevels = TOEICScoreRange.frequencyLevels(forTarget: targetScore)

        // 이미 숙달한 문법 ID 가져오기
        let masteredPred = #Predicate<LearningProgress> {
            $0.userID == userID && $0.itemType == "grammar" && $0.isMastered == true
        }
        let masteredIDs = Set((try? context.fetch(FetchDescriptor<LearningProgress>(predicate: masteredPred)))?.compactMap { $0.grammar?.grammarID } ?? [])

        // 전체 문법 가져오기
        let allDescriptor = FetchDescriptor<Grammar>(sortBy: [SortDescriptor(\.difficultyLevel)])
        let allGrammar: [Grammar]
        do { allGrammar = try context.fetch(allDescriptor) }
        catch { isLoading = false; return }

        // 비숙달 문법만
        let nonMastered = allGrammar.filter { !masteredIDs.contains($0.grammarID) }

        let totalQuiz = 10

        // ── SRS 복습 우선 편입 (최대 30%) ──
        let srsReview = SpacedRepetitionService.fetchDueGrammar(userID: userID, context: context)
            .filter { !masteredIDs.contains($0.grammarID) }
        let srsSlot = min(srsReview.count, totalQuiz * 3 / 10)
        let srsItems = Array(srsReview.prefix(srsSlot))
        let srsIDs = Set(srsItems.map(\.grammarID))

        // ── 워밍업 (첫 1~2문제: difficultyLevel=1) ──
        let warmupCandidates = nonMastered.filter {
            $0.difficultyLevel == 1 && !srsIDs.contains($0.grammarID)
        }.shuffled()
        let warmupCount = min(1, warmupCandidates.count)
        let warmupItems = Array(warmupCandidates.prefix(warmupCount))
        let warmupIDs = Set(warmupItems.map(\.grammarID))

        // ── 메인 덱 (40%/60%) ──
        let remainSlot = totalQuiz - srsSlot - warmupCount
        let currentLevelFreq = max(1, estimatedLevel)
        let currentLevel = nonMastered.filter {
            $0.difficultyLevel == currentLevelFreq && !srsIDs.contains($0.grammarID) && !warmupIDs.contains($0.grammarID)
        }.shuffled()
        let targetLevel = nonMastered.filter {
            targetLevels.contains($0.difficultyLevel) && $0.difficultyLevel != currentLevelFreq
            && !srsIDs.contains($0.grammarID) && !warmupIDs.contains($0.grammarID)
        }.shuffled()

        let currentCount = max(1, Int(Double(remainSlot) * 0.4))
        let targetCount = remainSlot - currentCount

        var mainItems: [Grammar] = []
        mainItems += Array(currentLevel.prefix(currentCount))
        mainItems += Array(targetLevel.prefix(targetCount))

        // 부족분 보충
        if mainItems.count < remainSlot {
            let existing = Set(mainItems.map(\.grammarID)).union(srsIDs).union(warmupIDs)
            let more = nonMastered.filter { !existing.contains($0.grammarID) }.shuffled()
            mainItems += Array(more.prefix(remainSlot - mainItems.count))
        }

        // 최종 조립: 워밍업 → SRS → 메인 (메인만 셔플)
        mainItems.shuffle()
        var quizItems: [Grammar] = warmupItems + srsItems + mainItems

        // 중복 제거
        var seenIDs = Set<String>()
        quizItems = quizItems.filter { seenIDs.insert($0.grammarID).inserted }

        questions = quizItems.compactMap { grammar in
            generateQuestion(from: grammar, allGrammar: allGrammar)
        }

        sessionManager.startSession(userID: userID)
        isLoading = false
    }

    func selectAnswer(_ answer: String, context: ModelContext) {
        guard !isAnswerRevealed, let question = currentQuestion else { return }
        selectedAnswer = answer
        isAnswerRevealed = true
        let isCorrect = answer == question.correctAnswer
        let responseTime = Date().timeIntervalSince(questionStartTime)
        answers.append(QuizAnswer(question: question, selectedAnswer: answer, isCorrect: isCorrect))
        sessionManager.recordGrammarQuiz(
            grammar: question.grammar,
            isCorrect: isCorrect,
            isTimeout: false,
            responseTime: responseTime,
            context: context
        )
        if isCorrect { HapticManager.shared.playCorrect() }
        else { HapticManager.shared.playIncorrect() }
    }

    func moveToNext(context: ModelContext) {
        selectedAnswer = nil
        isAnswerRevealed = false
        showExplanation = false
        if currentIndex + 1 >= questions.count {
            sessionManager.endSession(context: context)
            isQuizComplete = true
            HapticManager.shared.playCelebration()
        } else {
            currentIndex += 1
            questionStartTime = Date()
        }
    }

    /// 시간 초과 시: 복습에 추가하고 다음 문제로 넘어감
    func skipAsTimeout(context: ModelContext) {
        skipQuestion(reason: "(시간 초과)", context: context)
    }

    /// "모르겠다" 선택 시: 복습 추가 후 다음 문제로 넘어감
    func skipAsDontKnow(context: ModelContext) {
        skipQuestion(reason: "(모르겠다)", context: context)
    }

    /// 문제를 건너뛰는 공통 로직 (시간 초과 / 모르겠다)
    private func skipQuestion(reason: String, context: ModelContext) {
        guard let question = currentQuestion else { return }
        let responseTime = Date().timeIntervalSince(questionStartTime)
        let isTimeout = reason == "(시간 초과)"
        answers.append(QuizAnswer(question: question, selectedAnswer: reason, isCorrect: false))
        sessionManager.recordGrammarQuiz(
            grammar: question.grammar,
            isCorrect: false,
            isTimeout: isTimeout,
            responseTime: responseTime,
            context: context
        )
        HapticManager.shared.playIncorrect()

        if currentIndex + 1 >= questions.count {
            sessionManager.endSession(context: context)
            isQuizComplete = true
            HapticManager.shared.playCelebration()
        } else {
            currentIndex += 1
            selectedAnswer = nil
            isAnswerRevealed = false
            showExplanation = false
            questionStartTime = Date()
        }
    }

    // MARK: - Question Generation (개선)

    private func generateQuestion(from grammar: Grammar, allGrammar: [Grammar]) -> QuizQuestion? {
        let sentence = grammar.correctExample
        guard !sentence.isEmpty else { return nil }

        // 1) blankTarget이 JSON에 지정되어 있으면 사용
        if !grammar.blankTarget.isEmpty {
            let sentenceWithBlank = sentence.replacingOccurrences(of: grammar.blankTarget, with: "___")
            // 문장에 blankTarget이 실제로 있는지 확인
            if sentenceWithBlank != sentence {
                let correctAnswer = grammar.blankTarget

                // distractors가 지정되어 있으면 사용
                var distractorList: [String] = []
                if !grammar.distractors.isEmpty {
                    distractorList = grammar.distractors
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && $0 != correctAnswer }
                }

                // 오답이 3개 미만이면 보충
                if distractorList.count < 3 {
                    let more = generateSmartDistractors(
                        correctAnswer: correctAnswer,
                        quizType: grammar.quizType,
                        category: grammar.category,
                        allGrammar: allGrammar
                    )
                    for d in more where !distractorList.contains(d) && d != correctAnswer {
                        distractorList.append(d)
                        if distractorList.count >= 3 { break }
                    }
                }

                var options = [correctAnswer] + Array(distractorList.prefix(3))
                options.shuffle()
                return QuizQuestion(
                    grammar: grammar,
                    sentenceWithBlank: sentenceWithBlank,
                    correctAnswer: correctAnswer,
                    options: options,
                    incorrectExample: grammar.incorrectExample,
                    tip: grammar.tip
                )
            }
        }

        // 2) Fallback: 자동 추출
        return generateQuestionFallback(from: grammar, allGrammar: allGrammar)
    }

    /// quizType에 따라 적절한 오답 생성
    private func generateSmartDistractors(correctAnswer: String, quizType: String, category: String, allGrammar: [Grammar]) -> [String] {
        switch quizType {
        case "form":
            // 같은 어근의 다른 형태 생성
            return generateFormDistractors(correctAnswer)
        case "meaning":
            // 같은 카테고리 다른 문법의 blankTarget에서 추출
            return allGrammar
                .filter { $0.category == category && !$0.blankTarget.isEmpty && $0.blankTarget != correctAnswer }
                .map(\.blankTarget)
                .shuffled()
        default:
            return generateFormDistractors(correctAnswer)
        }
    }

    /// 형태 변환 오답 (reaching, to reach, being reached 등)
    private func generateFormDistractors(_ word: String) -> [String] {
        let base = word.lowercased()
        var forms: [String] = []

        // -ing form
        if !base.hasSuffix("ing") {
            if base.hasSuffix("e") { forms.append(String(base.dropLast()) + "ing") }
            else { forms.append(base + "ing") }
        }
        // -ed form
        if !base.hasSuffix("ed") {
            if base.hasSuffix("e") { forms.append(base + "d") }
            else { forms.append(base + "ed") }
        }
        // to + base
        if !base.hasPrefix("to ") { forms.append("to " + base) }
        // being + past participle
        if !base.hasPrefix("being ") { forms.append("being " + base + "ed") }
        // has/have + past participle
        forms.append("has " + base + "ed")

        return forms.filter { $0 != word.lowercased() && $0 != word }
    }

    /// Fallback 문제 생성 (blankTarget 없을 때)
    private func generateQuestionFallback(from grammar: Grammar, allGrammar: [Grammar]) -> QuizQuestion? {
        let sentence = grammar.correctExample
        let words = sentence.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }

        let skip = Set(["the","a","an","is","are","was","were","in","on","at","to","of","for","and","or","but","by","it","be"])
        let candidates = words.enumerated().filter {
            let cleaned = $0.element.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return cleaned.count >= 3 && !skip.contains(cleaned)
        }
        guard let target = candidates.randomElement() else { return nil }

        var blanked = words
        blanked[target.offset] = "___"
        let correctAnswer = target.element.trimmingCharacters(in: .punctuationCharacters)

        var distractors = generateSmartDistractors(
            correctAnswer: correctAnswer,
            quizType: grammar.quizType,
            category: grammar.category,
            allGrammar: allGrammar
        )
        let fallbacks = ["however","therefore","although","moreover","consequently","nevertheless"]
        while distractors.count < 3 {
            if let f = fallbacks.randomElement(), f != correctAnswer, !distractors.contains(f) {
                distractors.append(f)
            } else { break }
        }

        var options = [correctAnswer] + Array(distractors.prefix(3))
        options.shuffle()

        return QuizQuestion(
            grammar: grammar,
            sentenceWithBlank: blanked.joined(separator: " "),
            correctAnswer: correctAnswer,
            options: options,
            incorrectExample: grammar.incorrectExample,
            tip: grammar.tip
        )
    }
}
