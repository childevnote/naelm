import Foundation
import SwiftData

@MainActor
final class GuestDataMigrationService {
    static let shared = GuestDataMigrationService()

    private init() {}

    func migrateIfNeeded(from oldUserID: String, to newUserID: String, context: ModelContext) {
        guard oldUserID.hasPrefix("guest_"),
              !newUserID.hasPrefix("guest_"),
              oldUserID != newUserID else { return }

        migrateUserProfile(from: oldUserID, to: newUserID, context: context)
        migrateUserField(LearningProgress.self, from: oldUserID, to: newUserID, context: context)
        migrateUserField(UserActivity.self, from: oldUserID, to: newUserID, context: context)
        migrateUserField(MonthlyScore.self, from: oldUserID, to: newUserID, context: context)
        migrateUserField(BookmarkedWord.self, from: oldUserID, to: newUserID, context: context)
        migrateFriendships(from: oldUserID, to: newUserID, context: context)

        try? context.save()
    }

    private func migrateUserProfile(from oldUserID: String, to newUserID: String, context: ModelContext) {
        let oldPredicate = #Predicate<UserProfile> { $0.userID == oldUserID }
        let oldDescriptor = FetchDescriptor<UserProfile>(predicate: oldPredicate)
        guard let oldProfile = try? context.fetch(oldDescriptor).first else { return }

        let newPredicate = #Predicate<UserProfile> { $0.userID == newUserID }
        let newDescriptor = FetchDescriptor<UserProfile>(predicate: newPredicate)

        if let newProfile = try? context.fetch(newDescriptor).first {
            if newProfile.nickname.isEmpty { newProfile.nickname = oldProfile.nickname }
            newProfile.targetScore = oldProfile.targetScore
            newProfile.estimatedLevel = oldProfile.estimatedLevel
            newProfile.hasCompletedOnboarding = oldProfile.hasCompletedOnboarding
            newProfile.hasCompletedPlacementTest = oldProfile.hasCompletedPlacementTest
            newProfile.dailyVocabGoal = oldProfile.dailyVocabGoal
            newProfile.dailyGrammarGoal = oldProfile.dailyGrammarGoal
            newProfile.nicknameChangedAt = oldProfile.nicknameChangedAt
            newProfile.isPublicProfileRegistered = oldProfile.isPublicProfileRegistered
            newProfile.hasExplicitlySetNickname = oldProfile.hasExplicitlySetNickname
            context.delete(oldProfile)
            return
        }

        oldProfile.userID = newUserID
    }

    private func migrateFriendships(from oldUserID: String, to newUserID: String, context: ModelContext) {
        let predicate = #Predicate<Friendship> { $0.userID == oldUserID }
        let descriptor = FetchDescriptor<Friendship>(predicate: predicate)
        let friendships = (try? context.fetch(descriptor)) ?? []
        for friendship in friendships {
            friendship.userID = newUserID
        }
    }

    private func migrateUserField<T: PersistentModel>(
        _ type: T.Type,
        from oldUserID: String,
        to newUserID: String,
        context: ModelContext
    ) {
        switch type {
        case is LearningProgress.Type:
            let predicate = #Predicate<LearningProgress> { $0.userID == oldUserID }
            let descriptor = FetchDescriptor<LearningProgress>(predicate: predicate)
            let items = (try? context.fetch(descriptor)) ?? []
            items.forEach { $0.userID = newUserID }

        case is UserActivity.Type:
            let predicate = #Predicate<UserActivity> { $0.userID == oldUserID }
            let descriptor = FetchDescriptor<UserActivity>(predicate: predicate)
            let items = (try? context.fetch(descriptor)) ?? []
            items.forEach { $0.userID = newUserID }

        case is MonthlyScore.Type:
            let predicate = #Predicate<MonthlyScore> { $0.userID == oldUserID }
            let descriptor = FetchDescriptor<MonthlyScore>(predicate: predicate)
            let items = (try? context.fetch(descriptor)) ?? []
            items.forEach { $0.userID = newUserID }

        case is BookmarkedWord.Type:
            let predicate = #Predicate<BookmarkedWord> { $0.userID == oldUserID }
            let descriptor = FetchDescriptor<BookmarkedWord>(predicate: predicate)
            let items = (try? context.fetch(descriptor)) ?? []
            items.forEach { $0.userID = newUserID }

        default:
            break
        }
    }
}
