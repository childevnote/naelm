import Foundation
import SwiftData
import CloudKit
import os

enum ICloudProgressBackupError: LocalizedError {
    case backupNotFound
    case invalidPayload
    case notSignedIn
    case cloudError(CKError)

    var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "iCloud에 저장된 진행상황이 없어요."
        case .invalidPayload:
            return "백업 데이터 형식이 올바르지 않아요."
        case .notSignedIn:
            return "iCloud에 로그인되어 있지 않아요. 설정 앱에서 Apple ID를 확인해 주세요."
        case .cloudError(let e):
            return "iCloud 오류: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class ICloudProgressBackupService {
    static let shared = ICloudProgressBackupService()

    private let privateDB = CKContainer.default().privateCloudDatabase
    private let recordType = "UserProgressBackup"

    private enum Field {
        static let publicID = "publicID"
        static let payload = "payload"
        static let updatedAt = "updatedAt"
    }

    private init() {}

    func fetchLastBackupDate(userID: String) async -> Date? {
        let recordID = CKRecord.ID(recordName: recordName(userID: userID))
        guard let record = try? await privateDB.record(for: recordID) else { return nil }
        return record[Field.updatedAt] as? Date
    }

    func backupProgress(userID: String, context: ModelContext) async throws -> Date {
        // iCloud 로그인 여부 먼저 확인
        let status = try await CKContainer.default().accountStatus()
        guard status == .available else {
            throw ICloudProgressBackupError.notSignedIn
        }

        let snapshot = try makeSnapshot(userID: userID, context: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let payloadData = try encoder.encode(snapshot)

        let recordID = CKRecord.ID(recordName: recordName(userID: userID))
        let record: CKRecord
        do {
            record = try await privateDB.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        } catch let ckError as CKError {
            AppLogger.data.error("[iCloud Backup] fetch record 실패: \(ckError.code.rawValue, privacy: .public) \(ckError.localizedDescription, privacy: .public)")
            throw ICloudProgressBackupError.cloudError(ckError)
        }

        record[Field.payload] = payloadData as CKRecordValue
        let savedRecord: CKRecord
        do {
            savedRecord = try await privateDB.save(record)
        } catch let ckError as CKError {
            AppLogger.data.error("[iCloud Backup] save 실패: \(ckError.code.rawValue, privacy: .public) \(ckError.localizedDescription, privacy: .public)")
            throw ICloudProgressBackupError.cloudError(ckError)
        }
        return savedRecord.modificationDate ?? Date()
    }

    func restoreProgress(userID: String, context: ModelContext) async throws -> Date {
        let status = try await CKContainer.default().accountStatus()
        guard status == .available else {
            throw ICloudProgressBackupError.notSignedIn
        }

        let recordID = CKRecord.ID(recordName: recordName(userID: userID))
        let record: CKRecord

        do {
            record = try await privateDB.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            throw ICloudProgressBackupError.backupNotFound
        } catch let ckError as CKError {
            AppLogger.data.error("[iCloud Backup] restore fetch 실패: \(ckError.code.rawValue, privacy: .public) \(ckError.localizedDescription, privacy: .public)")
            throw ICloudProgressBackupError.cloudError(ckError)
        }

        // BYTES 타입으로 저장된 payload 읽기
        let payload: Data
        if let data = record[Field.payload] as? Data {
            payload = data
        } else {
            throw ICloudProgressBackupError.invalidPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(ProgressSnapshot.self, from: payload)
        restore(snapshot: snapshot, userID: userID, context: context)

        return (record[Field.updatedAt] as? Date) ?? record.modificationDate ?? Date()
    }

    private func recordName(userID: String) -> String {
        "progress_\(FriendService.publicID(from: userID))"
    }

    private func makeSnapshot(userID: String, context: ModelContext) throws -> ProgressSnapshot {
        let profile = fetchItems(UserProfile.self, predicate: #Predicate<UserProfile> { $0.userID == userID }, context: context).first
        let progresses = fetchItems(LearningProgress.self, predicate: #Predicate<LearningProgress> { $0.userID == userID }, context: context)
        let activities = fetchItems(UserActivity.self, predicate: #Predicate<UserActivity> { $0.userID == userID }, context: context)
        let monthlyScores = fetchItems(MonthlyScore.self, predicate: #Predicate<MonthlyScore> { $0.userID == userID }, context: context)
        let bookmarks = fetchItems(BookmarkedWord.self, predicate: #Predicate<BookmarkedWord> { $0.userID == userID }, context: context)

        return ProgressSnapshot(
            profile: profile.map(ProfilePayload.init),
            learningProgresses: progresses.map(LearningProgressPayload.init),
            activities: activities.map(ActivityPayload.init),
            monthlyScores: monthlyScores.map(MonthlyScorePayload.init),
            bookmarks: bookmarks.map(BookmarkPayload.init)
        )
    }

    private func restore(snapshot: ProgressSnapshot, userID: String, context: ModelContext) {
        clearUserData(userID: userID, context: context)

        if let profilePayload = snapshot.profile {
            let profile = UserProfile(userID: userID)
            profile.targetScore = profilePayload.targetScore
            profile.estimatedLevel = profilePayload.estimatedLevel
            profile.hasCompletedOnboarding = profilePayload.hasCompletedOnboarding
            profile.hasCompletedPlacementTest = profilePayload.hasCompletedPlacementTest
            profile.dailyVocabGoal = profilePayload.dailyVocabGoal
            profile.dailyGrammarGoal = profilePayload.dailyGrammarGoal
            profile.timerEnabled = profilePayload.timerEnabled
            profile.vocabTimerSeconds = profilePayload.vocabTimerSeconds
            profile.grammarTimerSeconds = profilePayload.grammarTimerSeconds
            profile.nickname = profilePayload.nickname
            profile.nicknameChangedAt = profilePayload.nicknameChangedAt
            profile.isPublicProfileRegistered = profilePayload.isPublicProfileRegistered
            context.insert(profile)
        }

        let vocabMap = vocabularyMap(context: context)
        let grammarMap = grammarMap(context: context)

        snapshot.learningProgresses.forEach { payload in
            let progress = LearningProgress(
                userID: userID,
                itemType: payload.itemType,
                vocabulary: payload.vocabularyID.flatMap { vocabMap[$0] },
                grammar: payload.grammarID.flatMap { grammarMap[$0] }
            )
            progress.interval = payload.interval
            progress.repetitions = payload.repetitions
            progress.easeFactor = payload.easeFactor
            progress.nextReviewDate = payload.nextReviewDate
            progress.lastReviewedAt = payload.lastReviewedAt
            progress.correctCount = payload.correctCount
            progress.incorrectCount = payload.incorrectCount
            progress.streak = payload.streak
            progress.isMastered = payload.isMastered
            progress.markedForReview = payload.markedForReview
            progress.createdAt = payload.createdAt
            context.insert(progress)
        }

        snapshot.activities.forEach { payload in
            let activity = UserActivity(userID: userID, activityDate: payload.activityDate)
            activity.wordsStudied = payload.wordsStudied
            activity.grammarStudied = payload.grammarStudied
            activity.studyDurationSeconds = payload.studyDurationSeconds
            activity.quizAccuracy = payload.quizAccuracy
            activity.quizTotal = payload.quizTotal
            activity.quizCorrect = payload.quizCorrect
            activity.dailyGoalMet = payload.dailyGoalMet
            activity.xpEarned = payload.xpEarned
            activity.createdAt = payload.createdAt
            context.insert(activity)
        }

        snapshot.monthlyScores.forEach { payload in
            let score = MonthlyScore(userID: userID, month: payload.month, score: payload.score, achievementRate: payload.achievementRate)
            score.createdAt = payload.createdAt
            context.insert(score)
        }

        snapshot.bookmarks.forEach { payload in
            let bookmark = BookmarkedWord(userID: userID, wordID: payload.wordID, vocabulary: vocabMap[payload.wordID])
            bookmark.createdAt = payload.createdAt
            context.insert(bookmark)
        }

        try? context.save()
    }

    private func clearUserData(userID: String, context: ModelContext) {
        deleteItems(UserProfile.self, predicate: #Predicate<UserProfile> { $0.userID == userID }, context: context)
        deleteItems(LearningProgress.self, predicate: #Predicate<LearningProgress> { $0.userID == userID }, context: context)
        deleteItems(UserActivity.self, predicate: #Predicate<UserActivity> { $0.userID == userID }, context: context)
        deleteItems(MonthlyScore.self, predicate: #Predicate<MonthlyScore> { $0.userID == userID }, context: context)
        deleteItems(BookmarkedWord.self, predicate: #Predicate<BookmarkedWord> { $0.userID == userID }, context: context)
    }

    private func vocabularyMap(context: ModelContext) -> [String: Vocabulary] {
        let items = (try? context.fetch(FetchDescriptor<Vocabulary>())) ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.wordID, $0) })
    }

    private func grammarMap(context: ModelContext) -> [String: Grammar] {
        let items = (try? context.fetch(FetchDescriptor<Grammar>())) ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.grammarID, $0) })
    }

    private func fetchItems<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>,
        context: ModelContext
    ) -> [T] {
        (try? context.fetch(FetchDescriptor<T>(predicate: predicate))) ?? []
    }

    private func deleteItems<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>,
        context: ModelContext
    ) {
        let items = fetchItems(type, predicate: predicate, context: context)
        items.forEach { context.delete($0) }
    }
}

private struct ProgressSnapshot: Codable {
    let profile: ProfilePayload?
    let learningProgresses: [LearningProgressPayload]
    let activities: [ActivityPayload]
    let monthlyScores: [MonthlyScorePayload]
    let bookmarks: [BookmarkPayload]
}

private struct ProfilePayload: Codable {
    let targetScore: Int
    let estimatedLevel: Int
    let hasCompletedOnboarding: Bool
    let hasCompletedPlacementTest: Bool
    let dailyVocabGoal: Int
    let dailyGrammarGoal: Int
    let timerEnabled: Bool
    let vocabTimerSeconds: Int
    let grammarTimerSeconds: Int
    let nickname: String
    let nicknameChangedAt: Date?
    let isPublicProfileRegistered: Bool

    init(_ profile: UserProfile) {
        targetScore = profile.targetScore
        estimatedLevel = profile.estimatedLevel
        hasCompletedOnboarding = profile.hasCompletedOnboarding
        hasCompletedPlacementTest = profile.hasCompletedPlacementTest
        dailyVocabGoal = profile.dailyVocabGoal
        dailyGrammarGoal = profile.dailyGrammarGoal
        timerEnabled = profile.timerEnabled
        vocabTimerSeconds = profile.vocabTimerSeconds
        grammarTimerSeconds = profile.grammarTimerSeconds
        nickname = profile.nickname
        nicknameChangedAt = profile.nicknameChangedAt
        isPublicProfileRegistered = profile.isPublicProfileRegistered
    }
}

private struct LearningProgressPayload: Codable {
    let itemType: String
    let interval: Int
    let repetitions: Int
    let easeFactor: Double
    let nextReviewDate: Date
    let lastReviewedAt: Date
    let correctCount: Int
    let incorrectCount: Int
    let streak: Int
    let isMastered: Bool
    let markedForReview: Bool
    let createdAt: Date
    let vocabularyID: String?
    let grammarID: String?

    init(_ progress: LearningProgress) {
        itemType = progress.itemType
        interval = progress.interval
        repetitions = progress.repetitions
        easeFactor = progress.easeFactor
        nextReviewDate = progress.nextReviewDate
        lastReviewedAt = progress.lastReviewedAt
        correctCount = progress.correctCount
        incorrectCount = progress.incorrectCount
        streak = progress.streak
        isMastered = progress.isMastered
        markedForReview = progress.markedForReview
        createdAt = progress.createdAt
        vocabularyID = progress.vocabulary?.wordID
        grammarID = progress.grammar?.grammarID
    }
}

private struct ActivityPayload: Codable {
    let activityDate: Date
    let wordsStudied: Int
    let grammarStudied: Int
    let studyDurationSeconds: Int
    let quizAccuracy: Double
    let quizTotal: Int
    let quizCorrect: Int
    let dailyGoalMet: Bool
    let xpEarned: Int
    let createdAt: Date

    init(_ activity: UserActivity) {
        activityDate = activity.activityDate
        wordsStudied = activity.wordsStudied
        grammarStudied = activity.grammarStudied
        studyDurationSeconds = activity.studyDurationSeconds
        quizAccuracy = activity.quizAccuracy
        quizTotal = activity.quizTotal
        quizCorrect = activity.quizCorrect
        dailyGoalMet = activity.dailyGoalMet
        xpEarned = activity.xpEarned
        createdAt = activity.createdAt
    }
}

private struct MonthlyScorePayload: Codable {
    let month: String
    let score: Int
    let achievementRate: Double
    let createdAt: Date

    init(_ score: MonthlyScore) {
        month = score.month
        self.score = score.score
        achievementRate = score.achievementRate
        createdAt = score.createdAt
    }
}

private struct BookmarkPayload: Codable {
    let wordID: String
    let createdAt: Date

    init(_ bookmark: BookmarkedWord) {
        wordID = bookmark.wordID
        createdAt = bookmark.createdAt
    }
}
