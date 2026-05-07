//
//  Models.swift
//  Naelm
//
//  Created by 김동진 on 4/3/26.
//
//  TOEIC 학습 앱의 핵심 데이터 모델 정의.
//  ──────────────────────────────────────────────
//  CloudKit 동기화 제약 사항:
//    • 모든 프로퍼티는 Optional이거나 기본값 필수
//    • @Attribute(.unique), @Attribute(.spotlight)는 CloudKit에서 지원되지 않으므로
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

    var plusLabel: String {
        switch self {
        case .below600: return "600 미만"
        case .range600: return "600++"
        case .range700: return "700++"
        case .range800: return "800++"
        case .range900: return "900++"
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

    /// estimatedLevel(0~5) → scoreRange 변환
    static func fromEstimatedLevel(_ level: Int) -> TOEICScoreRange {
        switch level {
        case 1: return .below600
        case 2: return .range600
        case 3: return .range700
        case 4: return .range800
        case 5: return .range900
        default: return .below600
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

    /// 프로필 생성일
    var createdAt: Date = Date()

    /// 앱 내 표시 닉네임 (친구 검색 및 식별에 사용)
    var nickname: String = ""

    /// 닉네임 마지막 변경일 (한 달 1회 제한)
    var nicknameChangedAt: Date? = nil

    /// 공개 프로필 등록 완료 여부 (CloudKit Public DB 등록 여부)
    var isPublicProfileRegistered: Bool = false

    init(userID: String, targetScore: Int = 700) {
        self.userID = userID
        self.targetScore = targetScore
        self.createdAt = Date()
    }
}

// MARK: - 📚 Vocabulary (정적 데이터 — 번들 JSON에서 시딩)

/// TOEIC 빈출 어휘 모델.
/// 번들에서 시딩되며 사용자가 직접 수정하지 않는 정적 데이터입니다.
@Model
final class Vocabulary {

    // ── 식별자 ──────────────────────────────
    /// JSON 시딩 시 중복 삽입 방지를 위한 고유 키.
    /// @Attribute(.unique/.spotlight)는 CloudKit 미지원 → DataLoader에서 코드 레벨 중복 체크
    var wordID: String = ""

    // ── 핵심 필드 ───────────────────────────
    var english: String = ""
    var korean: String = ""
    var pronunciation: String = ""
    var partOfSpeech: String = ""
    var frequencyLevel: Int = 1

    // ── 학습 보조 ───────────────────────────
    var exampleSentence: String = ""
    var exampleTranslation: String = ""
    var category: String = ""
    var synonyms: String = ""

    // ── 메타 ────────────────────────────────
    var dataVersion: Int = 1
    var createdAt: Date = Date()

    // ── 관계 ────────────────────────────────
    @Relationship(deleteRule: .cascade, inverse: \LearningProgress.vocabulary)
    var learningProgress: [LearningProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \VocabularyMeaning.vocabulary)
    var meanings: [VocabularyMeaning] = []

    /// BookmarkedWord 역관계 — 누락 시 ModelContainer 로드 실패
    @Relationship(deleteRule: .nullify, inverse: \BookmarkedWord.vocabulary)
    var bookmarks: [BookmarkedWord] = []

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
    var grammarID: String = ""

    // ── 핵심 필드 ───────────────────────────
    var title: String = ""
    var explanation: String = ""
    var toeicPart: String = ""
    var difficultyLevel: Int = 1

    // ── 학습 보조 ───────────────────────────
    var correctExample: String = ""
    var incorrectExample: String = ""
    var tip: String = ""
    var category: String = ""
    var blankTarget: String = ""
    var distractors: String = ""
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

    var userID: String = ""
    var itemType: String = "vocabulary"

    // ── 간격 반복 (Spaced Repetition) 필드 ──
    var interval: Int = 0
    var repetitions: Int = 0
    var easeFactor: Double = 2.5
    var nextReviewDate: Date = Date()
    var lastReviewedAt: Date = Date()

    // ── 통계 ────────────────────────────────
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var streak: Int = 0
    var isMastered: Bool = false
    var markedForReview: Bool = false

    // ── 메타 ────────────────────────────────
    var createdAt: Date = Date()

    // ── 관계 (inverse는 부모 쪽 Vocabulary/Grammar에서 선언) ──
    var vocabulary: Vocabulary?
    var grammar: Grammar?

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
@Model
final class UserActivity {

    var userID: String = ""
    var activityDate: Date = Date()
    var wordsStudied: Int = 0
    var grammarStudied: Int = 0
    var studyDurationSeconds: Int = 0
    var quizAccuracy: Double = 0.0
    var quizTotal: Int = 0
    var quizCorrect: Int = 0
    var dailyGoalMet: Bool = false
    var xpEarned: Int = 0
    var createdAt: Date = Date()

    init(userID: String, activityDate: Date = Date()) {
        self.userID = userID
        self.activityDate = activityDate
        self.createdAt = Date()
    }
}


// MARK: - 📅 MonthlyScore (동적 데이터 — 월별 점수 기록)

@Model
final class MonthlyScore {

    var userID: String = ""
    var month: String = ""
    var score: Int = 0
    var achievementRate: Double = 0.0
    var createdAt: Date = Date()

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

@Model
final class Friendship {

    var userID: String = ""
    var friendID: String = ""
    var isBlocked: Bool = false
    var isFriend: Bool = false
    var isPending: Bool = false
    var requestedByMe: Bool = true
    var friendNickname: String = ""
    var cloudRequestRecordID: String = ""
    var createdAt: Date = Date()

    init(
        userID: String,
        friendID: String,
        isBlocked: Bool = false,
        isFriend: Bool = false,
        isPending: Bool = false,
        requestedByMe: Bool = true,
        friendNickname: String = "",
        cloudRequestRecordID: String = ""
    ) {
        self.userID = userID
        self.friendID = friendID
        self.isBlocked = isBlocked
        self.isFriend = isFriend
        self.isPending = isPending
        self.requestedByMe = requestedByMe
        self.friendNickname = friendNickname
        self.cloudRequestRecordID = cloudRequestRecordID
        self.createdAt = Date()
    }
}

// MARK: - BookmarkedWord (저장한 단어)

@Model
final class BookmarkedWord {
    var userID: String = ""
    var wordID: String = ""

    /// inverse는 Vocabulary.bookmarks 쪽에서 선언
    var vocabulary: Vocabulary?

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

    var meaningID: String = ""
    var pos: String = ""
    var korean: String = ""
    var exampleSentence: String = ""
    var exampleTranslation: String = ""
    var synonyms: String = ""
    var order: Int = 1

    /// inverse는 Vocabulary.meanings 쪽에서 선언
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
