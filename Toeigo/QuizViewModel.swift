//
//  QuizViewModel.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  문법 퀴즈 ViewModel.
//  ──────────────────────────────────────────────
//  역할:
//    1. Grammar 데이터에서 빈칸 채우기 문제 생성
//    2. 정답 + 3개 오답 보기 구성
//    3. 정답/오답 판정 및 SRS 기록
//    4. 퀴즈 세션 진행 관리
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

// MARK: - Quiz Question Model

/// 하나의 퀴즈 문제를 나타내는 구조체.
struct QuizQuestion: Identifiable {
    let id = UUID()
    let grammar: Grammar
    /// 빈칸이 있는 문장 (___로 표시)
    let sentenceWithBlank: String
    /// 정답
    let correctAnswer: String
    /// 보기 목록 (정답 포함, 셔플됨)
    let options: [String]
    /// 오답 문장 (해설용)
    let incorrectExample: String
    /// 팁 (해설용)
    let tip: String
}

/// 사용자의 답변 결과
struct QuizAnswer {
    let question: QuizQuestion
    let selectedAnswer: String
    let isCorrect: Bool
}

// MARK: - QuizViewModel

@MainActor
@Observable
final class QuizViewModel {

    // MARK: - State

    /// 전체 문제 목록
    var questions: [QuizQuestion] = []

    /// 현재 문제 인덱스
    var currentIndex: Int = 0

    /// 사용자 답변 기록
    var answers: [QuizAnswer] = []

    /// 현재 선택된 답
    var selectedAnswer: String? = nil

    /// 정답 공개 여부
    var isAnswerRevealed: Bool = false

    /// 퀴즈 완료 여부
    var isQuizComplete: Bool = false

    /// 해설 시트 표시 여부
    var showExplanation: Bool = false

    /// 로딩 중
    var isLoading: Bool = false

    // MARK: - Computed

    /// 현재 문제
    var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    /// 진행률 (0.0 ~ 1.0)
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    /// 정답 수
    var correctCount: Int {
        answers.filter(\.isCorrect).count
    }

    /// 오답 수
    var incorrectCount: Int {
        answers.filter { !$0.isCorrect }.count
    }

    /// 정답률
    var accuracy: Double {
        guard !answers.isEmpty else { return 0 }
        return Double(correctCount) / Double(answers.count)
    }

    // MARK: - Dependencies

    private let sessionManager: LearningSessionManager

    init(sessionManager: LearningSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Load Quiz

    /// 문법 퀴즈를 로드합니다.
    func loadQuiz(userID: String, context: ModelContext) {
        isLoading = true
        isQuizComplete = false
        currentIndex = 0
        answers = []
        selectedAnswer = nil
        isAnswerRevealed = false

        // 1) 복습 대상 문법
        let dueGrammar = SpacedRepetitionService.fetchDueGrammar(
            userID: userID,
            context: context
        )

        // 2) 전체 문법 (새 항목 포함)
        let allDescriptor = FetchDescriptor<Grammar>(
            sortBy: [SortDescriptor(\.difficultyLevel)]
        )
        let allGrammar: [Grammar]
        do {
            allGrammar = try context.fetch(allDescriptor)
        } catch {
            print("❌ [QuizVM] Failed to fetch grammar: \(error)")
            isLoading = false
            return
        }

        // 3) 복습 대상 + 새 문법 합치기
        var quizItems = dueGrammar
        let dueIDs = Set(dueGrammar.map(\.grammarID))
        let newItems = allGrammar.filter { !dueIDs.contains($0.grammarID) }
        let needed = max(0, 8 - quizItems.count)
        quizItems += Array(newItems.prefix(needed))
        quizItems.shuffle()

        // 4) 문제 생성
        questions = quizItems.compactMap { grammar in
            generateQuestion(from: grammar, allGrammar: allGrammar)
        }

        // 세션 시작
        sessionManager.startSession(userID: userID)

        isLoading = false
        print("📝 [QuizVM] Quiz loaded — \(questions.count) questions")
    }

    // MARK: - Answer Selection

    /// 보기를 선택합니다.
    func selectAnswer(_ answer: String, context: ModelContext) {
        guard !isAnswerRevealed, let question = currentQuestion else { return }

        selectedAnswer = answer
        isAnswerRevealed = true

        let isCorrect = answer == question.correctAnswer

        // 답변 기록
        let quizAnswer = QuizAnswer(
            question: question,
            selectedAnswer: answer,
            isCorrect: isCorrect
        )
        answers.append(quizAnswer)

        // SRS + XP 기록
        sessionManager.recordGrammarQuiz(
            grammar: question.grammar,
            isCorrect: isCorrect,
            context: context
        )

        // 햅틱
        if isCorrect {
            HapticManager.shared.playCorrect()
        } else {
            HapticManager.shared.playIncorrect()
        }
    }

    // MARK: - Next Question

    /// 다음 문제로 이동합니다.
    func moveToNext(context: ModelContext) {
        selectedAnswer = nil
        isAnswerRevealed = false
        showExplanation = false

        if currentIndex + 1 >= questions.count {
            // 퀴즈 완료
            sessionManager.endSession(context: context)
            isQuizComplete = true
            HapticManager.shared.playCelebration()
        } else {
            currentIndex += 1
        }
    }

    // MARK: - Question Generation

    /// Grammar 항목에서 빈칸 채우기 문제를 생성합니다.
    private func generateQuestion(
        from grammar: Grammar,
        allGrammar: [Grammar]
    ) -> QuizQuestion? {
        let sentence = grammar.correctExample
        guard !sentence.isEmpty else { return nil }

        // 문장에서 빈칸으로 만들 키워드 추출
        let words = sentence.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }

        // 적절한 단어를 빈칸으로 선택 (3글자 이상, 관사/전치사 제외)
        let skipWords = Set(["the", "a", "an", "is", "are", "was", "were", "in", "on", "at",
                              "to", "of", "for", "and", "or", "but", "by", "it", "be"])
        let candidates = words.enumerated().filter { index, word in
            let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return cleaned.count >= 3 && !skipWords.contains(cleaned)
        }

        guard let target = candidates.randomElement() else { return nil }
        let targetIndex = target.offset
        let targetWord = target.element

        // 빈칸 문장 생성
        var blankedWords = words
        blankedWords[targetIndex] = "___"
        let sentenceWithBlank = blankedWords.joined(separator: " ")

        // 정답 (구두점 제거)
        let correctAnswer = targetWord.trimmingCharacters(in: .punctuationCharacters)

        // 오답 보기 생성 (같은 카테고리의 다른 문법 예문에서 추출)
        var distractors = generateDistractors(
            correctAnswer: correctAnswer,
            category: grammar.category,
            allGrammar: allGrammar
        )

        // 오답이 부족하면 기본 오답 추가
        let fallbackDistractors = ["however", "therefore", "although", "moreover",
                                    "consequently", "nevertheless", "furthermore",
                                    "meanwhile", "accordingly", "regardless"]
        while distractors.count < 3 {
            if let fallback = fallbackDistractors.randomElement(),
               fallback != correctAnswer && !distractors.contains(fallback) {
                distractors.append(fallback)
            } else {
                break
            }
        }
        distractors = Array(distractors.prefix(3))

        // 보기 셔플
        var options = [correctAnswer] + distractors
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

    /// 오답 보기를 생성합니다.
    private func generateDistractors(
        correctAnswer: String,
        category: String,
        allGrammar: [Grammar]
    ) -> [String] {
        let skipWords = Set(["the", "a", "an", "is", "are", "was", "were", "in", "on", "at",
                              "to", "of", "for", "and", "or", "but", "by", "it", "be"])

        var pool = Set<String>()

        // 같은 카테고리 문법의 예문에서 단어 추출
        let sameCategory = allGrammar.filter { $0.category == category }
        for grammar in sameCategory {
            let words = grammar.correctExample.split(separator: " ").map(String.init)
            for word in words {
                let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if cleaned.count >= 3 && cleaned != correctAnswer.lowercased() && !skipWords.contains(cleaned) {
                    pool.insert(cleaned)
                }
            }
        }

        // 다른 카테고리에서도 추가
        if pool.count < 3 {
            for grammar in allGrammar {
                let words = grammar.correctExample.split(separator: " ").map(String.init)
                for word in words {
                    let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                    if cleaned.count >= 3 && cleaned != correctAnswer.lowercased() && !skipWords.contains(cleaned) {
                        pool.insert(cleaned)
                    }
                }
            }
        }

        return Array(pool.shuffled().prefix(3))
    }
}
