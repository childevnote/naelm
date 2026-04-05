//
//  QuizViewModel.swift
//  Toeigo
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

        let targetLevels = TOEICScoreRange.frequencyLevels(forTarget: targetScore)

        // 복습 대상
        let dueGrammar = SpacedRepetitionService.fetchDueGrammar(userID: userID, context: context)

        // 전체
        let allDescriptor = FetchDescriptor<Grammar>(sortBy: [SortDescriptor(\.difficultyLevel)])
        let allGrammar: [Grammar]
        do { allGrammar = try context.fetch(allDescriptor) }
        catch { isLoading = false; return }

        // 목표 점수에 맞는 문법만
        let filtered = allGrammar.filter { targetLevels.isEmpty || targetLevels.contains($0.difficultyLevel) }

        var quizItems = dueGrammar.filter { targetLevels.isEmpty || targetLevels.contains($0.difficultyLevel) }
        let dueIDs = Set(quizItems.map(\.grammarID))
        let newItems = filtered.filter { !dueIDs.contains($0.grammarID) }
        let needed = max(0, 10 - quizItems.count)
        quizItems += Array(newItems.shuffled().prefix(needed))
        quizItems.shuffle()

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
        answers.append(QuizAnswer(question: question, selectedAnswer: answer, isCorrect: isCorrect))
        sessionManager.recordGrammarQuiz(grammar: question.grammar, isCorrect: isCorrect, context: context)
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
