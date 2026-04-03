//
//  Models.swift
//  Toeigo
//
//  Created by 김동진 on 4/3/26.
//
//  TOEIC 학습 앱의 핵심 데이터 모델 정의.
//  ──────────────────────────────────────────────
//  CloudKit 동기화 제약 사항:
//    • 모든 프로퍼티는 Optional이거나 기본값 필수
//    • @Attribute(.unique)는 CloudKit에서 지원되지 않으므로
//      코드 레벨의 중복 방지 로직으로 대체
//    • Relationship inverse는 반드시 명시
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

// MARK: - 📚 Vocabulary (정적 데이터 — 번들 JSON에서 시딩)

/// TOEIC 빈출 어휘 모델.
/// 번들에서 시딩되며 사용자가 직접 수정하지 않는 정적 데이터입니다.
@Model
final class Vocabulary {

    // ── 식별자 ──────────────────────────────
    /// JSON 시딩 시 중복 삽입 방지를 위한 고유 키.
    /// CloudKit은 @Attribute(.unique)를 지원하지 않으므로,
    /// DataLoader에서 코드 레벨로 중복 체크합니다.
    @Attribute(.spotlight)
    var wordID: String = ""

    // ── 핵심 필드 ───────────────────────────
    /// 영어 단어 (예: "revenue")
    var english: String = ""

    /// 한국어 뜻 (예: "수익, 매출")
    var korean: String = ""

    /// 발음 기호 (예: "/ˈrev.ən.uː/")
    var pronunciation: String = ""

    /// 품사 (예: "noun", "verb", "adjective")
    var partOfSpeech: String = ""

    /// TOEIC 출제 빈도 등급 (1 = 최빈출, 5 = 저빈출)
    var frequencyLevel: Int = 1

    // ── 학습 보조 ───────────────────────────
    /// 예문 (영어)
    var exampleSentence: String = ""

    /// 예문 (한국어 번역)
    var exampleTranslation: String = ""

    /// TOEIC 카테고리 (예: "Finance", "HR", "Marketing")
    var category: String = ""

    /// 동의어 목록 (쉼표 구분 문자열)
    var synonyms: String = ""

    // ── 메타 ────────────────────────────────
    /// 데이터 버전 — 시드 업데이트 시 비교용
    var dataVersion: Int = 1

    /// 생성 일시
    var createdAt: Date = Date()

    // ── 관계 ────────────────────────────────
    /// 이 단어에 대한 학습 진행 기록 (1:N)
    @Relationship(deleteRule: .cascade, inverse: \LearningProgress.vocabulary)
    var learningProgress: [LearningProgress] = []

    // ── 이니셜라이저 ────────────────────────
    init(
        wordID: String,
        english: String,
        korean: String,
        pronunciation: String = "",
        partOfSpeech: String = "",
        frequencyLevel: Int = 1,
        exampleSentence: String = "",
        exampleTranslation: String = "",
        category: String = "",
        synonyms: String = "",
        dataVersion: Int = 1
    ) {
        self.wordID = wordID
        self.english = english
        self.korean = korean
        self.pronunciation = pronunciation
        self.partOfSpeech = partOfSpeech
        self.frequencyLevel = frequencyLevel
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
        self.category = category
        self.synonyms = synonyms
        self.dataVersion = dataVersion
        self.createdAt = Date()
    }
}


// MARK: - 📖 Grammar (정적 데이터 — 번들 JSON에서 시딩)

/// TOEIC 핵심 문법 포인트 모델.
@Model
final class Grammar {

    // ── 식별자 ──────────────────────────────
    @Attribute(.spotlight)
    var grammarID: String = ""

    // ── 핵심 필드 ───────────────────────────
    /// 문법 규칙 제목 (예: "현재완료 vs 과거시제")
    var title: String = ""

    /// 문법 설명 (한국어)
    var explanation: String = ""

    /// TOEIC Part 분류 (예: "Part 5", "Part 6")
    var toeicPart: String = ""

    /// 난이도 (1 = 초급, 2 = 중급, 3 = 고급)
    var difficultyLevel: Int = 1

    // ── 학습 보조 ───────────────────────────
    /// 올바른 예문
    var correctExample: String = ""

    /// 틀린 예문 (오류 패턴 학습용)
    var incorrectExample: String = ""

    /// 팁 / 암기 요령
    var tip: String = ""

    /// 카테고리 (예: "Tense", "Preposition", "Conjunction")
    var category: String = ""

    // ── 메타 ────────────────────────────────
    var dataVersion: Int = 1
    var createdAt: Date = Date()

    // ── 관계 ────────────────────────────────
    @Relationship(deleteRule: .cascade, inverse: \LearningProgress.grammar)
    var learningProgress: [LearningProgress] = []

    // ── 이니셜라이저 ────────────────────────
    init(
        grammarID: String,
        title: String,
        explanation: String,
        toeicPart: String = "",
        difficultyLevel: Int = 1,
        correctExample: String = "",
        incorrectExample: String = "",
        tip: String = "",
        category: String = "",
        dataVersion: Int = 1
    ) {
        self.grammarID = grammarID
        self.title = title
        self.explanation = explanation
        self.toeicPart = toeicPart
        self.difficultyLevel = difficultyLevel
        self.correctExample = correctExample
        self.incorrectExample = incorrectExample
        self.tip = tip
        self.category = category
        self.dataVersion = dataVersion
        self.createdAt = Date()
    }
}


// MARK: - 📊 LearningProgress (동적 데이터 — 사용자별 학습 진행)

/// 각 학습 항목(단어/문법)에 대한 사용자의 개별 학습 진행 상태.
/// Spaced-repetition (간격 반복) 알고리즘의 핵심 데이터.
@Model
final class LearningProgress {

    // ── 식별자 ──────────────────────────────
    /// 사용자 식별자 (Sign in with Apple의 userIdentifier)
    var userID: String = ""

    /// 학습 항목 타입 ("vocabulary" 또는 "grammar")
    var itemType: String = "vocabulary"

    // ── 간격 반복 (Spaced Repetition) 필드 ──
    /// SM-2 알고리즘 기반 복습 간격 (일 단위)
    var interval: Int = 0

    /// 반복 횟수
    var repetitions: Int = 0

    /// 난이도 계수 (기본 2.5, SM-2 기준)
    var easeFactor: Double = 2.5

    /// 다음 복습 예정일
    var nextReviewDate: Date = Date()

    /// 마지막 복습일
    var lastReviewedAt: Date = Date()

    // ── 통계 ────────────────────────────────
    /// 정답 횟수
    var correctCount: Int = 0

    /// 오답 횟수
    var incorrectCount: Int = 0

    /// 연속 정답 스트릭
    var streak: Int = 0

    /// 숙달 여부
    var isMastered: Bool = false

    // ── 메타 ────────────────────────────────
    var createdAt: Date = Date()

    // ── 관계 ────────────────────────────────
    /// 연결된 단어 (Optional — 문법이면 nil)
    var vocabulary: Vocabulary?

    /// 연결된 문법 (Optional — 단어이면 nil)
    var grammar: Grammar?

    // ── 이니셜라이저 ────────────────────────
    init(
        userID: String,
        itemType: String = "vocabulary",
        vocabulary: Vocabulary? = nil,
        grammar: Grammar? = nil
    ) {
        self.userID = userID
        self.itemType = itemType
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.nextReviewDate = Date()
        self.lastReviewedAt = Date()
        self.createdAt = Date()
    }
}


// MARK: - 🏃 UserActivity (동적 데이터 — 학습 활동 로그)

/// 사용자의 일별 학습 활동 기록.
/// 대시보드의 통계, 스트릭, 학습 그래프 등에 활용됩니다.
@Model
final class UserActivity {

    // ── 식별자 ──────────────────────────────
    /// 사용자 식별자 (Sign in with Apple의 userIdentifier)
    var userID: String = ""

    /// 활동 날짜 (시간 제외, 일 단위 집계용)
    var activityDate: Date = Date()

    // ── 학습 통계 ───────────────────────────
    /// 해당 일에 학습한 총 단어 수
    var wordsStudied: Int = 0

    /// 해당 일에 학습한 총 문법 수
    var grammarStudied: Int = 0

    /// 총 학습 시간 (초)
    var studyDurationSeconds: Int = 0

    /// 퀴즈 정답률 (0.0 ~ 1.0)
    var quizAccuracy: Double = 0.0

    /// 해당 일 퀴즈 총 문제 수
    var quizTotal: Int = 0

    /// 해당 일 퀴즈 정답 수
    var quizCorrect: Int = 0

    // ── 스트릭 / 보상 ───────────────────────
    /// 일일 목표 달성 여부
    var dailyGoalMet: Bool = false

    /// XP (경험치) — 게이미피케이션용
    var xpEarned: Int = 0

    // ── 메타 ────────────────────────────────
    var createdAt: Date = Date()

    // ── 이니셜라이저 ────────────────────────
    init(
        userID: String,
        activityDate: Date = Date()
    ) {
        self.userID = userID
        self.activityDate = activityDate
        self.createdAt = Date()
    }
}
