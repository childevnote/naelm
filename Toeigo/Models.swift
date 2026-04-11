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

// MARK: - TOEIC Score Range (점수 구간 열거형)

/// 토익 점수 구간 (600~900, 100점 단위)
/// frequencyLevel 1→600, 2→700, 3→800, 4→900 매핑
enum TOEICScoreRange: Int, CaseIterable, Codable {
    case below600 = 0   // 600점 미만
    case range600 = 1   // 600점대
    case range700 = 2   // 700점대
    case range800 = 3   // 800점대
    case range900 = 4   // 900점대

    var label: String {
        switch self {
        case .below600: return "600점 미만"
        case .range600: return "600점대"
        case .range700: return "700점대"
        case .range800: return "800점대"
        case .range900: return "900점대"
        }
    }

    var shortLabel: String {
        switch self {
        case .below600: return "~600"
        case .range600: return "600"
        case .range700: return "700"
        case .range800: return "800"
        case .range900: return "900"
        }
    }

    /// frequencyLevel → scoreRange 변환
    static func from(frequencyLevel: Int) -> TOEICScoreRange {
        switch frequencyLevel {
        case 1: return .range600
        case 2: return .range700
        case 3: return .range800
        case 4: return .range900
        default: return .range600
        }
    }

    /// 목표 점수에 해당하는 구간까지의 모든 구간 반환
    /// 예: 800점 목표 → [.range600, .range700, .range800]
    static func rangesUpTo(target: Int) -> [TOEICScoreRange] {
        let targetRange: TOEICScoreRange
        switch target {
        case ..<600: targetRange = .below600
        case 600..<700: targetRange = .range600
        case 700..<800: targetRange = .range700
        case 800..<900: targetRange = .range800
        default: targetRange = .range900
        }
        return allCases.filter { $0.rawValue <= targetRange.rawValue && $0 != .below600 }
    }

    /// frequencyLevel 목록 반환
    static func frequencyLevels(forTarget target: Int) -> [Int] {
        rangesUpTo(target: target).map(\.rawValue)
    }
}

// MARK: - 👤 UserProfile (사용자 프로필 — 목표 점수 + 수준)

@Model
final class UserProfile {

    /// 사용자 식별자 (Sign in with Apple)
    var userID: String = ""

    /// 목표 토익 점수 (600, 700, 800, 900)
    var targetScore: Int = 700

    /// 추정 현재 수준 (수준 파악 테스트 결과)
    /// 0=미측정, 1=600점미만, 2=600점대, 3=700점대, 4=800점대, 5=900점대
    var estimatedLevel: Int = 0

    /// 온보딩 완료 여부
    var hasCompletedOnboarding: Bool = false

    /// 수준 파악 테스트 완료 여부
    var hasCompletedPlacementTest: Bool = false

    /// 단어 일일 목표 개수 (AI 추천 또는 수동 설정)
    var dailyVocabGoal: Int = 20

    /// 문법 일일 목표 개수
    var dailyGrammarGoal: Int = 10

    /// 시간 제한 기능 활성화 여부
    var timerEnabled: Bool = true

    /// 단어 학습 제한 시간 (초, 5~25)
    var vocabTimerSeconds: Int = 15

    /// 문법 학습 제한 시간 (초, 5~25)
    var grammarTimerSeconds: Int = 15

    /// 프로 구독 여부
    var isPro: Bool = false

    /// 프로 구독 만료일 (nil이면 미구독 또는 평생 구독)
    var proExpiresAt: Date? = nil

    /// 구독 플랜 타입 ("monthly" / "annual" / "")
    var subscriptionPlan: String = ""

    /// Pro 상태 평가 (만료일 체크 포함)
    /// isPro && (만료일 없음 또는 만료일 > 현재) 일 때만 true.
    /// 만료된 경우 isPro를 자동으로 false로 리셋합니다.
    var isProActive: Bool {
        guard isPro else { return false }
        guard let expiresAt = proExpiresAt else { return true }  // 만료일 없으면 영구 구독
        if expiresAt > Date() {
            return true
        } else {
            // 만료됨 — 자동 리셋
            isPro = false
            subscriptionPlan = ""
            return false
        }
    }

    /// 프로필 생성일
    var createdAt: Date = Date()

    init(userID: String, targetScore: Int = 700) {
        self.userID = userID
        self.targetScore = targetScore
        self.createdAt = Date()
    }
}

// MARK: - � Vocabulary (정적 데이터 — 번들 JSON에서 시딩)

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

    /// 다중 의미/품사 목록 (순서: order 필드 기준)
    @Relationship(deleteRule: .cascade, inverse: \VocabularyMeaning.vocabulary)
    var meanings: [VocabularyMeaning] = []

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

    /// 퀴즈에서 빈칸으로 만들 정답 단어
    var blankTarget: String = ""

    /// 오답 보기 3개 (쉼표 구분 문자열, 예: "reaching,to reach,being reached")
    var distractors: String = ""

    /// 퀴즈 유형 (예: "form" = 형태변환, "meaning" = 의미, "grammar" = 문법구조)
    var quizType: String = "grammar"

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
        blankTarget: String = "",
        distractors: String = "",
        quizType: String = "grammar",
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
        self.blankTarget = blankTarget
        self.distractors = distractors
        self.quizType = quizType
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

    /// 사용자가 "학습할게요"로 표시한 복습 대상 단어
    var markedForReview: Bool = false

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


// MARK: - 📅 MonthlyScore (동적 데이터 — 월별 점수 기록)

/// 사용자의 월별 토익 점수 기록.
/// 매월 말일에 자동으로 생성되며, 수동 수정은 불가합니다.
@Model
final class MonthlyScore {

    // ── 식별자 ──────────────────────────────
    /// 사용자 식별자 (Sign in with Apple의 userIdentifier)
    var userID: String = ""

    /// 기록된 월 (예: 2023-03)
    var month: String = ""

    // ── 점수 ────────────────────────────────
    /// 측정된 토익 점수
    var score: Int = 0

    /// 목표 대비 달성률 (예: 0.85 = 85% 달성)
    var achievementRate: Double = 0.0

    // ── 메타 ────────────────────────────────
    var createdAt: Date = Date()

    // ── 이니셜라이저 ────────────────────────
    init(
        userID: String,
        month: String,
        score: Int,
        achievementRate: Double = 0.0
    ) {
        self.userID = userID
        self.month = month
        self.score = score
        self.achievementRate = achievementRate
        self.createdAt = Date()
    }
}


// MARK: - 🤝 Friendship (동적 데이터 — 사용자 간 관계)

/// 사용자 간의 친구 관계 모델.
/// 친구 추가, 차단 등의 정보가 포함됩니다.
@Model
final class Friendship {

    // ── 식별자 ──────────────────────────────
    /// 사용자 식별자 (Sign in with Apple의 userIdentifier)
    var userID: String = ""

    /// 친구 사용자 식별자
    var friendID: String = ""

    // ── 관계 상태 ───────────────────────────
    /// 차단 여부
    var isBlocked: Bool = false

    /// 친구 추가 여부
    var isFriend: Bool = false

    // ── 메타 ────────────────────────────────
    var createdAt: Date = Date()

    // ── 이니셜라이저 ────────────────────────
    init(
        userID: String,
        friendID: String,
        isBlocked: Bool = false,
        isFriend: Bool = false
    ) {
        self.userID = userID
        self.friendID = friendID
        self.isBlocked = isBlocked
        self.isFriend = isFriend
        self.createdAt = Date()
    }
}

// MARK: - BookmarkedWord (저장한 단어)

@Model
final class BookmarkedWord {    var userID: String = ""
    var wordID: String = ""

    @Relationship var vocabulary: Vocabulary?

    var createdAt: Date = Date()

    init(userID: String, wordID: String, vocabulary: Vocabulary? = nil) {
        self.userID = userID
        self.wordID = wordID
        self.vocabulary = vocabulary
        self.createdAt = Date()
    }
}

// MARK: - VocabularyMeaning (단어별 다중 의미/품사)

@Model
final class VocabularyMeaning {

    @Attribute(.spotlight)
    var meaningID: String = ""

    var pos: String = ""
    var korean: String = ""
    var exampleSentence: String = ""
    var exampleTranslation: String = ""
    var synonyms: String = ""
    var order: Int = 1

    var vocabulary: Vocabulary?

    init(
        meaningID: String,
        pos: String = "",
        korean: String = "",
        exampleSentence: String = "",
        exampleTranslation: String = "",
        synonyms: String = "",
        order: Int = 1
    ) {
        self.meaningID = meaningID
        self.pos = pos
        self.korean = korean
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
        self.synonyms = synonyms
        self.order = order
    }
}
