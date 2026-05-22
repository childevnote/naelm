//
//  FriendService.swift
//  Naelm
//
//  CloudKit Public DB 기반 친구 기능 서비스.
//  ──────────────────────────────────────────────
//  역할:
//    1. UserPublicProfile 레코드 생성/업데이트
//    2. 닉네임 기반 유저 검색
//    3. 친구 요청 송/수신 관리
//  ──────────────────────────────────────────────
//  보안 참고:
//    레코드 이름은 SHA256(userID)로 파생된 해시를 사용하여
//    예측 가능한 이름 선점/스푸핑을 방지합니다.
//    CloudKit record 필드의 userID 노출 최소화를 위해
//    추후 CloudKit creator record ID 기반 소유자 검증을 권장합니다.
//  ──────────────────────────────────────────────

import Foundation
import CloudKit
import CryptoKit
import os

// MARK: - CloudKit 레코드 타입 상수

private enum CKRecordType {
    static let userPublicProfile = "UserPublicProfile"
    static let friendRequest = "FriendRequest"
    static let streakChallenge = "StreakChallenge"
    static let friendCodeIndex = "FriendCodeIndex"
}

private nonisolated enum CKRecordField {
    static let publicID = "publicID"
    static let legacyUserID = "userID"
    static let fromPublicID = "fromPublicID"
    static let toPublicID = "toPublicID"
    static let legacyFromUserID = "fromUserID"
    static let legacyToUserID = "toUserID"
    static let fromNickname = "fromNickname"
    static let nickname = "nickname"
    static let friendCode = "friendCode"
    static let estimatedLevel = "estimatedLevel"
    static let targetScore = "targetScore"
    static let monthlyXP = "monthlyXP"
    static let totalXP = "totalXP"
    static let streak = "streak"
    static let weeklyXP = "weeklyXP"
    static let status = "status"
    static let createdAt = "createdAt"
    static let updatedAt = "updatedAt"
    static let friendCodeIndexPublicID = "indexedPublicID"

    static let challengerPublicID = "challengerPublicID"
    static let challengerNickname = "challengerNickname"
    static let challengerStreak = "challengerStreak"
    static let opponentPublicID = "opponentPublicID"
    static let opponentNickname = "opponentNickname"
    
    // 연락처 기반 매칭을 위한 해시 배열 (전화번호, 이메일 해시)
    static let contactHashes = "contactHashes"
}

// MARK: - 공개 프로필 데이터 구조체

/// CloudKit Public DB에서 조회한 유저 공개 정보
struct PublicUserInfo: Identifiable {
    let id = UUID()
    let publicID: String      // SHA-256 hashed public identifier
    let nickname: String      // 닉네임
    let friendCode: String    // 친구 추가용 고유 코드
    let estimatedLevel: Int   // 현재 수준(0~5)
    let targetScore: Int      // 목표 점수
    let monthlyXP: Int        // 이번 달 XP (랭킹용)
    let totalXP: Int          // 누적 총 XP
    let streak: Int           // 연속 학습일
    let weeklyXP: Int         // 이번 주 XP
    let recordName: String    // CKRecord.ID.recordName (업데이트용)
    let contactHashes: [String] // 매칭용 해시 배열
}

/// CloudKit의 StreakChallenge 레코드 파싱 결과
struct StreakChallengeInfo: Identifiable {
    let id = UUID()
    let recordName: String
    let challengerPublicID: String
    let challengerNickname: String
    let challengerStreak: Int
    let opponentPublicID: String
    let opponentNickname: String
    let status: String        // "pending" | "active" | "declined" | "completed" | "cancelled"
    let createdAt: Date
}

// MARK: - 친구 요청 데이터 구조체

/// CloudKit의 FriendRequest 레코드 파싱 결과
struct FriendRequestInfo: Identifiable {
    let id = UUID()
    let recordName: String    // CKRecord.ID.recordName
    let fromPublicID: String
    let fromNickname: String
    let toPublicID: String
    let status: String        // "pending" | "accepted" | "declined" | "removed"
    let createdAt: Date
}

// MARK: - FriendService

/// CloudKit Public DB 기반 친구 기능 서비스
final class FriendService {

    static let shared = FriendService()
    private let publicDB = CKContainer.default().publicCloudDatabase

    private init() {}

    // ── 내부 유틸리티 ────────────────────────────────────────

    /// Apple userID를 SHA256으로 해시하여 예측 불가능한 공개 식별자를 반환합니다.
    /// 동일 userID → 항상 동일 결과 (결정론적), 외부에서 역산 불가.
    nonisolated static func hashedPublicID(from userID: String) -> String {
        let digest = SHA256.hash(data: Data(userID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func isLikelyPublicID(_ value: String) -> Bool {
        let lower = value.lowercased()
        guard lower.count == 64 else { return false }
        let hexSet = CharacterSet(charactersIn: "0123456789abcdef")
        return lower.unicodeScalars.allSatisfy { hexSet.contains($0) }
    }

    /// userID 또는 publicID를 받아 항상 publicID(해시)를 반환합니다.
    nonisolated static func publicID(from userIDOrPublicID: String) -> String {
        let lower = userIDOrPublicID.lowercased()
        return isLikelyPublicID(lower) ? lower : hashedPublicID(from: userIDOrPublicID)
    }
    
    /// 전화번호나 이메일 등의 개인정보를 해시(SHA-256)하여 반환합니다.
    nonisolated static func hashContactIdentifier(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// UserPublicProfile 레코드 이름 (해시 기반)
    nonisolated private static func profileRecordName(for userIDOrPublicID: String) -> String {
        "profile_\(publicID(from: userIDOrPublicID))"
    }

    nonisolated private static func friendCodeIndexRecordName(for friendCode: String) -> String {
        "friendcode_\(normalizedFriendCode(friendCode))"
    }

    /// 고유 친구코드 포맷으로 정규화합니다. 예) naelm-abc12345 -> NAELM-ABC12345
    nonisolated static func normalizedFriendCode(_ rawValue: String) -> String {
        let upper = rawValue.uppercased()
        let trimmed = upper.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("NAELM-") ? String(trimmed.dropFirst(6)) : trimmed
        let filtered = withoutPrefix.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return "NAELM-\(String(filtered.prefix(8)))"
    }

    /// publicID 기반 고유 친구코드를 생성합니다. (결정론적)
    nonisolated static func friendCode(from userIDOrPublicID: String) -> String {
        let publicID = Self.publicID(from: userIDOrPublicID)
        let digest = SHA256.hash(data: Data((publicID + "_naelm_friend_code_v1").utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().uppercased()
        return "NAELM-\(String(hex.prefix(8)))"
    }

    // ── Public Profile 관리 ──────────────────────────────────

    /// UserPublicProfile 레코드를 생성하거나 업데이트합니다.
    /// recordName은 SHA256(userID) 기반으로 고정하여 예측 선점을 방지합니다.
    func upsertPublicProfile(
        userID: String,
        nickname: String,
        monthlyXP: Int,
        totalXP: Int,
        streak: Int,
        weeklyXP: Int = 0,
        estimatedLevel: Int = 0,
        targetScore: Int = 700,
        friendCode: String? = nil,
        contactHashes: [String] = []
    ) async throws {
        let publicID = Self.publicID(from: userID)
        let normalizedCode = Self.normalizedFriendCode(friendCode ?? Self.friendCode(from: publicID))
        let recordName = Self.profileRecordName(for: publicID)
        let recordID = CKRecord.ID(recordName: recordName)

        // 기존 레코드 조회 시도 후 없으면 새로 생성
        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: CKRecordType.userPublicProfile, recordID: recordID)
        }

        record[CKRecordField.publicID] = publicID as CKRecordValue
        record[CKRecordField.nickname] = nickname as CKRecordValue
        record[CKRecordField.friendCode] = normalizedCode as CKRecordValue
        record[CKRecordField.estimatedLevel] = Int64(estimatedLevel) as CKRecordValue
        record[CKRecordField.targetScore] = Int64(targetScore) as CKRecordValue
        record[CKRecordField.monthlyXP] = Int64(monthlyXP) as CKRecordValue
        record[CKRecordField.totalXP] = Int64(totalXP) as CKRecordValue
        record[CKRecordField.streak] = Int64(streak) as CKRecordValue
        record[CKRecordField.weeklyXP] = Int64(weeklyXP) as CKRecordValue
        record[CKRecordField.contactHashes] = contactHashes as CKRecordValue
        record[CKRecordField.updatedAt] = Date() as CKRecordValue

        do {
            try await publicDB.save(record)
            do {
                try await upsertFriendCodeIndex(friendCode: normalizedCode, publicID: publicID)
            } catch {
                AppLogger.friend.warning("[PublicProfileUpsert] friend code index 비활성(fallback): \(error.localizedDescription, privacy: .public)")
            }
        } catch let ckError as CKError where ckError.code == .invalidArguments {
            // Production schema에 신규 필드가 아직 배포되지 않은 경우 레거시 필드만 저장
            record[CKRecordField.friendCode] = nil
            record[CKRecordField.estimatedLevel] = nil
            record[CKRecordField.targetScore] = nil
            try await publicDB.save(record)
            do {
                try await upsertFriendCodeIndex(friendCode: normalizedCode, publicID: publicID)
            } catch {
                AppLogger.friend.warning("[PublicProfileUpsert] friend code index 비활성(fallback): \(error.localizedDescription, privacy: .public)")
            }
            record[CKRecordField.estimatedLevel] = nil
            record[CKRecordField.targetScore] = nil
            try await publicDB.save(record)
            do {
                try await upsertFriendCodeIndex(friendCode: normalizedCode, publicID: publicID)
            } catch let indexError as CKError where indexError.code == .invalidArguments {
                AppLogger.friend.warning("[PublicProfileUpsert] friend code index 비활성(fallback): \(indexError.localizedDescription, privacy: .public)")
            }
            AppLogger.friend.warning("[PublicProfileUpsert] schema fallback 적용: friendCode/estimatedLevel/targetScore/contactHashes 미배포")
        }
    }

    /// 닉네임으로 Public Profile을 검색합니다.
    func searchUsers(nickname: String) async throws -> [PublicUserInfo] {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let desiredKeys = [
            CKRecordField.publicID,
            CKRecordField.nickname,
            CKRecordField.friendCode,
            CKRecordField.estimatedLevel,
            CKRecordField.targetScore,
            CKRecordField.monthlyXP,
            CKRecordField.totalXP,
            CKRecordField.streak,
            CKRecordField.weeklyXP,
            CKRecordField.contactHashes,
        ]

        // CloudKit에서 [cd] 수식어는 tokenized 인덱스가 필요하므로
        // 우선 case-sensitive BEGINSWITH (일반 queryable 인덱스로 가능)를 시도하고
        // 실패 시 lowercase로 변환한 값으로 재시도합니다.
        // NSPredicate(value: true) 전체조회는 CloudKit Production에서 지원되지 않으므로 사용하지 않습니다.
        let queries: [NSPredicate] = [
            NSPredicate(format: "nickname BEGINSWITH[cd] %@", trimmed),
            NSPredicate(format: "nickname BEGINSWITH %@", trimmed),
            NSPredicate(format: "nickname BEGINSWITH %@", trimmed.lowercased()),
        ]

        for predicate in queries {
            do {
                let query = CKQuery(recordType: CKRecordType.userPublicProfile, predicate: predicate)
                // sortDescriptors를 생략하면 서버 기본 정렬 사용 → 클라이언트 정렬로 보정
                let (results, _) = try await publicDB.records(
                    matching: query,
                    desiredKeys: desiredKeys,
                    resultsLimit: 20
                )
                let profiles = results.compactMap { _, result -> PublicUserInfo? in
                    guard let record = try? result.get() else { return nil }
                    return Self.parsePublicProfile(record)
                }
                // 클라이언트 사이드 prefix 필터 + 정렬
                return profiles
                    .filter { $0.nickname.lowercased().hasPrefix(trimmed.lowercased()) }
                    .sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
                    .prefix(20)
                    .map { $0 }
            } catch let ckError as CKError {
                AppLogger.friend.warning("[FriendSearch] predicate 실패(\(ckError.code.rawValue, privacy: .public)): \(ckError.localizedDescription, privacy: .public)")
                // 다음 predicate 전략 시도
                continue
            }
        }
        // 모든 전략 실패
        AppLogger.friend.error("[FriendSearch] 모든 검색 전략 실패. CloudKit Dashboard에서 nickname 필드가 Queryable로 설정되어 있는지 확인하세요.")
        return []
    }

    /// 고유코드로 단일 사용자를 조회합니다.
    func lookupUser(friendCode: String) async throws -> PublicUserInfo? {
        let normalized = Self.normalizedFriendCode(friendCode)
        guard normalized.count == 14 else { return nil }

        // 우선 friendCode 전용 인덱스 레코드를 recordID로 직접 조회 (CloudKit 쿼리 인덱스 불필요)
        if let indexedPublicID = try await fetchIndexedPublicID(for: normalized),
           let profile = try await fetchPublicProfile(userID: indexedPublicID) {
            return profile
        }

        let desiredKeys = [
            CKRecordField.publicID,
            CKRecordField.nickname,
            CKRecordField.friendCode,
            CKRecordField.estimatedLevel,
            CKRecordField.targetScore,
            CKRecordField.monthlyXP,
            CKRecordField.totalXP,
            CKRecordField.streak,
            CKRecordField.weeklyXP,
            CKRecordField.contactHashes,
        ]

        do {
            let predicate = NSPredicate(format: "friendCode == %@", normalized)
            let query = CKQuery(recordType: CKRecordType.userPublicProfile, predicate: predicate)
            let (results, _) = try await publicDB.records(matching: query, desiredKeys: desiredKeys, resultsLimit: 1)
            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                if let parsed = Self.parsePublicProfile(record) { return parsed }
            }
        } catch let ckError as CKError {
            // CloudKit schema에서 friendCode를 Queryable로 배포하지 않은 경우(code:12) fallback으로 계속 진행
            AppLogger.friend.warning("[FriendCodeLookup] code query fallback(\(ckError.code.rawValue, privacy: .public)): \(ckError.localizedDescription, privacy: .public)")
        }

        // 백필 전 레코드 대응: friendCode 필드가 비어있는 기존 프로필을 클라이언트 계산값으로 보정
        let fallbackProfiles = try await fetchAllPublicProfiles(limit: 300, desiredKeys: desiredKeys)
        return fallbackProfiles.first { Self.friendCode(from: $0.publicID) == normalized }
    }

    /// 연락처에서 추출한 친구코드 목록을 일괄 조회합니다.
    func lookupUsers(friendCodes: [String], excludingUserID: String? = nil) async -> [PublicUserInfo] {
        let uniqueCodes = Set(friendCodes.map(Self.normalizedFriendCode).filter { $0.count == 14 })
        guard !uniqueCodes.isEmpty else { return [] }

        let excludingPublicID = excludingUserID.map(Self.publicID(from:))
        var users: [PublicUserInfo] = []
        await withTaskGroup(of: PublicUserInfo?.self) { group in
            for code in uniqueCodes {
                group.addTask {
                    try? await self.lookupUser(friendCode: code)
                }
            }
            for await info in group {
                guard let info else { continue }
                if info.publicID == excludingPublicID { continue }
                users.append(info)
            }
        }

        let deduplicated = Dictionary(grouping: users, by: { $0.publicID }).compactMap { $0.value.first }
        return deduplicated.sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
    }
    
    /// 여러 연락처 해시(전화번호/이메일 해시)를 기반으로 사용자 목록을 조회합니다. (현업 스탠다드 로직)
    func findUsersByContactHashes(hashes: [String], excludingUserID: String? = nil) async throws -> [PublicUserInfo] {
        guard !hashes.isEmpty else { return [] }
        
        let desiredKeys = [
            CKRecordField.publicID,
            CKRecordField.nickname,
            CKRecordField.friendCode,
            CKRecordField.estimatedLevel,
            CKRecordField.targetScore,
            CKRecordField.monthlyXP,
            CKRecordField.totalXP,
            CKRecordField.streak,
            CKRecordField.weeklyXP,
            CKRecordField.contactHashes,
        ]

        let uniqueHashes = Array(Set(hashes))
        var allUsers: [PublicUserInfo] = []
        let excludingPublicID = excludingUserID.map(Self.publicID(from:))

        // CloudKit IN 쿼리는 250개 제약이 있으므로 청크 단위로 검색
        let chunkSize = 200
        for i in stride(from: 0, to: uniqueHashes.count, by: chunkSize) {
            let chunk = Array(uniqueHashes[i..<min(i + chunkSize, uniqueHashes.count)])
            let predicate = NSPredicate(format: "ANY %K IN %@", CKRecordField.contactHashes, chunk)
            let query = CKQuery(recordType: CKRecordType.userPublicProfile, predicate: predicate)
            
            do {
                let (results, _) = try await publicDB.records(matching: query, desiredKeys: desiredKeys, resultsLimit: 100)
                let profiles = results.compactMap { _, result -> PublicUserInfo? in
                    guard let record = try? result.get() else { return nil }
                    let profile = Self.parsePublicProfile(record)
                    // 본인은 제외
                    if let profile, profile.publicID != excludingPublicID {
                        return profile
                    }
                    return nil
                }
                allUsers.append(contentsOf: profiles)
            } catch let ckError as CKError {
                AppLogger.friend.warning("[ContactHashMatching] query failed(\(ckError.code.rawValue, privacy: .public)): \(ckError.localizedDescription, privacy: .public)")
            }
        }
        
        let deduplicated = Dictionary(grouping: allUsers, by: { $0.publicID }).compactMap { $0.value.first }
        return deduplicated.sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
    }

    /// 닉네임 중복 여부를 확인합니다. true = 사용 가능.
    /// - Parameter excludingPublicID: 자기 자신의 publicID (본인 제외)
    /// CloudKit은 ==[cd] 인덱스를 지원하지 않으므로 BEGINSWITH[cd] 후 클라이언트 사이드 정확 매칭으로 처리합니다.
    func isNicknameAvailable(_ nickname: String, excludingPublicID: String? = nil) async throws -> Bool {
        let normalized = nickname.trimmingCharacters(in: .whitespaces).lowercased()
        let desiredKeys = [CKRecordField.publicID, CKRecordField.nickname]

        let exactMatches: [String]
        do {
            let predicate = NSPredicate(format: "nickname BEGINSWITH[cd] %@", normalized)
            let query = CKQuery(recordType: CKRecordType.userPublicProfile, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKRecordField.nickname, ascending: true)]

            let (results, _) = try await publicDB.records(
                matching: query,
                desiredKeys: desiredKeys,
                resultsLimit: 20
            )

            exactMatches = results.compactMap { _, result -> String? in
                guard let record = try? result.get(),
                      let storedNickname = record[CKRecordField.nickname] as? String,
                      storedNickname.lowercased() == normalized else { return nil }
                return record[CKRecordField.publicID] as? String
            }
        } catch let ckError as CKError {
            AppLogger.friend.warning("[NicknameAvailability] query 실패(\(ckError.code.rawValue, privacy: .public)): \(ckError.localizedDescription, privacy: .public)")
            // fallback: monthlyXP >= 0 조건으로 전체 조회 후 클라이언트 필터
            let allProfiles = try await fetchAllPublicProfiles(limit: 200, desiredKeys: desiredKeys)
            exactMatches = allProfiles
                .filter { $0.nickname.lowercased() == normalized }
                .map(\.publicID)
        }

        if let exclude = excludingPublicID {
            return exactMatches.filter { $0 != exclude }.isEmpty
        }
        return exactMatches.isEmpty
    }

    /// 공개 프로필 전체에서 월간 XP 기준 상위 유저를 가져옵니다.
    /// 인덱스/정렬 스키마 미배포 환경에서도 동작하도록 클라이언트 사이드 정렬을 사용합니다.
    func fetchGlobalRankingProfiles(limit: Int = 100) async throws -> [PublicUserInfo] {
        let desiredKeys = [
            CKRecordField.publicID,
            CKRecordField.nickname,
            CKRecordField.friendCode,
            CKRecordField.estimatedLevel,
            CKRecordField.targetScore,
            CKRecordField.monthlyXP,
            CKRecordField.totalXP,
            CKRecordField.streak,
            CKRecordField.weeklyXP,
        ]
        let profiles = try await fetchAllPublicProfiles(limit: max(limit * 2, limit), desiredKeys: desiredKeys)
        return profiles
            .sorted {
                if $0.monthlyXP != $1.monthlyXP { return $0.monthlyXP > $1.monthlyXP }
                return $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    /// 특정 userID의 Public Profile을 가져옵니다.
    /// userID 또는 publicID를 받아 Public Profile을 가져옵니다.
    func fetchPublicProfile(userID: String) async throws -> PublicUserInfo? {
        let recordName = Self.profileRecordName(for: userID)
        let recordID = CKRecord.ID(recordName: recordName)

        do {
            let record = try await publicDB.record(for: recordID)
            return Self.parsePublicProfile(record)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    /// 여러 userID의 Public Profile을 한 번에 가져옵니다.
    /// CKFetchRecordsOperation 콜백은 백그라운드 스레드에서 호출되므로
    /// 파서 함수를 static으로 선언하여 actor 격리 문제를 방지합니다.
    func fetchPublicProfiles(userIDs: [String]) async throws -> [PublicUserInfo] {
        guard !userIDs.isEmpty else { return [] }

        let recordIDs = userIDs.map { CKRecord.ID(recordName: Self.profileRecordName(for: $0)) }

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            operation.desiredKeys = [
                CKRecordField.publicID,
                CKRecordField.nickname,
                CKRecordField.friendCode,
                CKRecordField.estimatedLevel,
                CKRecordField.targetScore,
                CKRecordField.monthlyXP,
                CKRecordField.totalXP,
                CKRecordField.streak,
                CKRecordField.weeklyXP,
                CKRecordField.contactHashes,
            ]

            var infos: [PublicUserInfo] = []
            let lock = NSLock()

            // static 파서 사용: 백그라운드 스레드에서 actor 격리 없이 안전하게 호출
            operation.perRecordResultBlock = { _, result in
                guard let record = try? result.get() else { return }
                if let info = FriendService.parsePublicProfile(record) {
                    lock.withLock { infos.append(info) }
                }
            }

            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: infos)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            publicDB.add(operation)
        }
    }

    /// 두 사용자 간 대기 중인 스트릭 대결 요청 존재 여부를 확인합니다.
    func hasPendingStreakChallenge(fromUserID: String, toUserID: String) async throws -> Bool {
        let challengerPublicID = Self.publicID(from: fromUserID)
        let opponentPublicID = Self.publicID(from: toUserID)

        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == 'pending'",
            CKRecordField.challengerPublicID, challengerPublicID,
            CKRecordField.opponentPublicID, opponentPublicID,
            CKRecordField.status
        )
        let query = CKQuery(recordType: CKRecordType.streakChallenge, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        return !results.isEmpty
    }

    /// 1:1 스트릭 대결 요청을 생성합니다.
    func sendStreakChallenge(
        fromUserID: String,
        fromNickname: String,
        challengerStreak: Int,
        toPublicID: String,
        toNickname: String
    ) async throws -> String {
        let challengerPublicID = Self.publicID(from: fromUserID)
        let opponentPublicID = Self.publicID(from: toPublicID)
        let record = CKRecord(recordType: CKRecordType.streakChallenge)
        record[CKRecordField.challengerPublicID] = challengerPublicID as CKRecordValue
        record[CKRecordField.challengerNickname] = fromNickname as CKRecordValue
        record[CKRecordField.challengerStreak] = Int64(challengerStreak) as CKRecordValue
        record[CKRecordField.opponentPublicID] = opponentPublicID as CKRecordValue
        record[CKRecordField.opponentNickname] = toNickname as CKRecordValue
        record[CKRecordField.status] = "pending" as CKRecordValue
        record[CKRecordField.createdAt] = Date() as CKRecordValue

        let saved = try await publicDB.save(record)
        return saved.recordID.recordName
    }

    /// 내가 받은 대기 중인 스트릭 대결 요청 목록을 가져옵니다.
    func fetchPendingStreakChallenges(toUserID: String) async throws -> [StreakChallengeInfo] {
        let myPublicID = Self.publicID(from: toUserID)
        return try await fetchStreakChallenges(fieldName: CKRecordField.opponentPublicID, value: myPublicID, status: "pending")
    }

    /// 특정 상대와 진행 중(active) 대결이 있는지 조회합니다.
    func fetchActiveChallenge(myUserID: String, withFriendPublicID friendPublicID: String) async throws -> StreakChallengeInfo? {
        let myPublicID = Self.publicID(from: myUserID)
        let normalizedFriendID = Self.publicID(from: friendPublicID)

        let predicate = NSPredicate(
            format: "((%K == %@ AND %K == %@) OR (%K == %@ AND %K == %@)) AND %K == 'active'",
            CKRecordField.challengerPublicID, myPublicID,
            CKRecordField.opponentPublicID, normalizedFriendID,
            CKRecordField.challengerPublicID, normalizedFriendID,
            CKRecordField.opponentPublicID, myPublicID,
            CKRecordField.status
        )
        let query = CKQuery(recordType: CKRecordType.streakChallenge, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        for (_, result) in results {
            guard let record = try? result.get() else { continue }
            if let info = Self.parseStreakChallenge(record) { return info }
        }
        return nil
    }

    /// 스트릭 대결 요청 상태를 업데이트합니다.
    func updateStreakChallengeStatus(recordName: String, status: String) async throws {
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await publicDB.record(for: recordID)
        record[CKRecordField.status] = status as CKRecordValue
        record[CKRecordField.updatedAt] = Date() as CKRecordValue
        try await publicDB.save(record)
    }

    // ── 친구 요청 관리 ──────────────────────────────────────

    /// 친구 요청을 Public DB에 생성합니다.
    /// 반환값: 생성된 CKRecord의 recordName (String)
    func sendFriendRequest(
        fromUserID: String,
        fromNickname: String,
        toPublicID: String
    ) async throws -> String {
        let fromPublicID = Self.publicID(from: fromUserID)
        let normalizedToPublicID = Self.publicID(from: toPublicID)
        let record = CKRecord(recordType: CKRecordType.friendRequest)
        record[CKRecordField.fromPublicID] = fromPublicID as CKRecordValue
        record[CKRecordField.fromNickname] = fromNickname as CKRecordValue
        record[CKRecordField.toPublicID] = normalizedToPublicID as CKRecordValue
        record[CKRecordField.status] = "pending" as CKRecordValue
        record[CKRecordField.createdAt] = Date() as CKRecordValue

        let saved = try await publicDB.save(record)
        return saved.recordID.recordName
    }

    /// 내가 받은 대기 중인 친구 요청 목록을 가져옵니다.
    func fetchPendingRequests(toUserID: String) async throws -> [FriendRequestInfo] {
        let publicID = Self.publicID(from: toUserID)
        async let newResults = fetchFriendRequests(fieldName: CKRecordField.toPublicID, value: publicID)
        async let legacyResults = fetchFriendRequests(fieldName: CKRecordField.legacyToUserID, value: toUserID)
        let combined = try await newResults + legacyResults
        var uniqueByRecord: [String: FriendRequestInfo] = [:]
        for info in combined {
            uniqueByRecord[info.recordName] = info
        }
        return Array(uniqueByRecord.values).sorted { $0.createdAt > $1.createdAt }
    }

    /// 내가 보낸 특정 요청의 현재 status를 가져옵니다. (발신자 동기화용)
    func fetchSentRequest(recordName: String) async throws -> FriendRequestInfo? {
        let recordID = CKRecord.ID(recordName: recordName)
        do {
            let record = try await publicDB.record(for: recordID)
            return Self.parseFriendRequest(record)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    /// 친구 요청의 status 필드를 업데이트합니다.
    func updateFriendRequestStatus(recordName: String, status: String) async throws {
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await publicDB.record(for: recordID)
        record["status"] = status as CKRecordValue
        try await publicDB.save(record)
    }

    /// 이미 요청을 보낸 적이 있는지 CloudKit에서 확인합니다.
    /// 앱 재설치 / 기기 변경 후 중복 요청 방지에 사용합니다.
    func hasPendingRequest(fromUserID: String, toUserID: String) async throws -> Bool {
        let fromPublicID = Self.publicID(from: fromUserID)
        let toPublicID = Self.publicID(from: toUserID)
        async let newExists = hasPendingRequest(
            fromField: CKRecordField.fromPublicID,
            fromValue: fromPublicID,
            toField: CKRecordField.toPublicID,
            toValue: toPublicID
        )
        async let legacyExists = hasPendingRequest(
            fromField: CKRecordField.legacyFromUserID,
            fromValue: fromUserID,
            toField: CKRecordField.legacyToUserID,
            toValue: toUserID
        )
        let (newExistsValue, legacyExistsValue) = try await (newExists, legacyExists)
        return newExistsValue || legacyExistsValue
    }

    /// 계정 삭제 시 Public DB에 남아있는 공개 프로필/친구 요청 데이터를 제거합니다.
    func deletePublicData(for userID: String) async {
        let publicID = Self.publicID(from: userID)
        let recordID = CKRecord.ID(recordName: Self.profileRecordName(for: publicID))
        do {
            if let record = try? await publicDB.record(for: recordID),
               let currentCode = record[CKRecordField.friendCode] as? String {
                let currentIndexRecordID = CKRecord.ID(recordName: Self.friendCodeIndexRecordName(for: currentCode))
                _ = try? await publicDB.deleteRecord(withID: currentIndexRecordID)
            }
            _ = try await publicDB.deleteRecord(withID: recordID)
        } catch {
            AppLogger.friend.warning("Failed to delete public profile: \(error.localizedDescription)")
        }

        let derivedCodeRecordID = CKRecord.ID(recordName: Self.friendCodeIndexRecordName(for: Self.friendCode(from: publicID)))
        _ = try? await publicDB.deleteRecord(withID: derivedCodeRecordID)

        do {
            try await deleteFriendRequests(
                predicate: NSPredicate(
                    format: "fromPublicID == %@ OR toPublicID == %@",
                    publicID, publicID
                )
            )
        } catch {
            AppLogger.friend.warning("Failed to delete public friend requests: \(error.localizedDescription)")
        }

        do {
            try await deleteFriendRequests(
                predicate: NSPredicate(
                    format: "fromUserID == %@ OR toUserID == %@",
                    userID, userID
                )
            )
        } catch {
            AppLogger.friend.warning("Failed to delete legacy friend requests: \(error.localizedDescription)")
        }

        do {
            try await deleteStreakChallenges(
                predicate: NSPredicate(
                    format: "%K == %@ OR %K == %@",
                    CKRecordField.challengerPublicID, publicID,
                    CKRecordField.opponentPublicID, publicID
                )
            )
        } catch {
            AppLogger.friend.warning("Failed to delete streak challenges: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func fetchFriendRequests(fieldName: String, value: String) async throws -> [FriendRequestInfo] {
        let predicate = NSPredicate(format: "%K == %@ AND status == 'pending'", fieldName, value)
        let query = CKQuery(recordType: CKRecordType.friendRequest, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKRecordField.createdAt, ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Self.parseFriendRequest(record)
        }
    }

    private func hasPendingRequest(
        fromField: String,
        fromValue: String,
        toField: String,
        toValue: String
    ) async throws -> Bool {
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND status == 'pending'",
            fromField, fromValue, toField, toValue
        )
        let query = CKQuery(recordType: CKRecordType.friendRequest, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        return !results.isEmpty
    }

    private func fetchStreakChallenges(fieldName: String, value: String, status: String) async throws -> [StreakChallengeInfo] {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", fieldName, value, CKRecordField.status, status)
        let query = CKQuery(recordType: CKRecordType.streakChallenge, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKRecordField.createdAt, ascending: false)]
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Self.parseStreakChallenge(record)
        }
    }

    private func upsertFriendCodeIndex(friendCode: String, publicID: String) async throws {
        let normalizedCode = Self.normalizedFriendCode(friendCode)
        let recordID = CKRecord.ID(recordName: Self.friendCodeIndexRecordName(for: normalizedCode))

        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: CKRecordType.friendCodeIndex, recordID: recordID)
        }

        record[CKRecordField.friendCode] = normalizedCode as CKRecordValue
        record[CKRecordField.friendCodeIndexPublicID] = publicID as CKRecordValue
        record[CKRecordField.updatedAt] = Date() as CKRecordValue
        try await publicDB.save(record)
    }

    private func fetchIndexedPublicID(for friendCode: String) async throws -> String? {
        let recordID = CKRecord.ID(recordName: Self.friendCodeIndexRecordName(for: friendCode))
        do {
            let record = try await publicDB.record(for: recordID)
            if let publicID = record[CKRecordField.friendCodeIndexPublicID] as? String {
                return publicID
            }
            if let publicID = record[CKRecordField.publicID] as? String {
                return publicID
            }
            return nil
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    private func deleteFriendRequests(predicate: NSPredicate) async throws {
        let query = CKQuery(recordType: CKRecordType.friendRequest, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 200)
        for (recordID, result) in results {
            guard (try? result.get()) != nil else { continue }
            _ = try? await publicDB.deleteRecord(withID: recordID)
        }
    }

    private func deleteStreakChallenges(predicate: NSPredicate) async throws {
        let query = CKQuery(recordType: CKRecordType.streakChallenge, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 200)
        for (recordID, result) in results {
            guard (try? result.get()) != nil else { continue }
            _ = try? await publicDB.deleteRecord(withID: recordID)
        }
    }

    private func fetchAllPublicProfiles(limit: Int, desiredKeys: [String]) async throws -> [PublicUserInfo] {
        // Production 스키마 인덱스 상태가 환경마다 달라질 수 있어 여러 predicate를 순차 시도합니다.
        let predicates: [NSPredicate] = [
            NSPredicate(format: "monthlyXP >= -1"),
            NSPredicate(format: "totalXP >= -1"),
            NSPredicate(format: "friendCode != ''"),
            NSPredicate(value: true) // 최후의 수단 (recordName 인덱스가 Queryable 이어야 함)
        ]

        for predicate in predicates {
            do {
                let query = CKQuery(recordType: CKRecordType.userPublicProfile, predicate: predicate)
                let (results, _) = try await publicDB.records(
                    matching: query,
                    desiredKeys: desiredKeys,
                    resultsLimit: limit
                )
                return results.compactMap { _, result in
                    guard let record = try? result.get() else { return nil }
                    return Self.parsePublicProfile(record)
                }
            } catch let ckError as CKError {
                AppLogger.friend.warning("[PublicProfileFetchAll] predicate 실패(\(ckError.code.rawValue, privacy: .public)): \(ckError.localizedDescription, privacy: .public)")
                continue
            }
        }

        AppLogger.friend.error("[PublicProfileFetchAll] 모든 조회 전략 실패. CloudKit Dashboard에서 UserPublicProfile 조회 인덱스를 확인하세요.")
        return []
    }

    // MARK: - 정적 파싱 헬퍼
    // static으로 선언하여 CKFetchRecordsOperation 백그라운드 콜백에서도 actor 격리 없이 호출 가능

    nonisolated static func parsePublicProfile(_ record: CKRecord) -> PublicUserInfo? {
        let publicID: String?
        if let value = record[CKRecordField.publicID] as? String {
            publicID = value
        } else if let legacyUserID = record[CKRecordField.legacyUserID] as? String {
            publicID = Self.publicID(from: legacyUserID)
        } else if record.recordID.recordName.hasPrefix("profile_") {
            publicID = String(record.recordID.recordName.dropFirst("profile_".count))
        } else {
            publicID = nil
        }

        guard let publicID,
              let nickname = record[CKRecordField.nickname] as? String else { return nil }

        let monthlyXP = (record[CKRecordField.monthlyXP] as? Int64).map(Int.init) ?? 0
        let totalXP = (record[CKRecordField.totalXP] as? Int64).map(Int.init) ?? 0
        let streak = (record[CKRecordField.streak] as? Int64).map(Int.init) ?? 0
        let weeklyXP = (record[CKRecordField.weeklyXP] as? Int64).map(Int.init) ?? 0
        let estimatedLevel = (record[CKRecordField.estimatedLevel] as? Int64).map(Int.init) ?? 0
        let targetScore = (record[CKRecordField.targetScore] as? Int64).map(Int.init) ?? 700
        let contactHashes = (record[CKRecordField.contactHashes] as? [String]) ?? []
        let friendCode = (record[CKRecordField.friendCode] as? String)
            .map(Self.normalizedFriendCode)
            ?? Self.friendCode(from: publicID)

        return PublicUserInfo(
            publicID: publicID,
            nickname: nickname,
            friendCode: friendCode,
            estimatedLevel: estimatedLevel,
            targetScore: targetScore,
            monthlyXP: monthlyXP,
            totalXP: totalXP,
            streak: streak,
            weeklyXP: weeklyXP,
            recordName: record.recordID.recordName,
            contactHashes: contactHashes
        )
    }

    nonisolated static func parseFriendRequest(_ record: CKRecord) -> FriendRequestInfo? {
        let fromPublicID = (record[CKRecordField.fromPublicID] as? String)
            ?? (record[CKRecordField.legacyFromUserID] as? String).map(Self.publicID(from:))
        let toPublicID = (record[CKRecordField.toPublicID] as? String)
            ?? (record[CKRecordField.legacyToUserID] as? String).map(Self.publicID(from:))
        guard let fromPublicID,
              let fromNickname = record[CKRecordField.fromNickname] as? String,
              let toPublicID,
              let status = record[CKRecordField.status] as? String else { return nil }

        let createdAt = record[CKRecordField.createdAt] as? Date ?? Date()

        return FriendRequestInfo(
            recordName: record.recordID.recordName,
            fromPublicID: fromPublicID,
            fromNickname: fromNickname,
            toPublicID: toPublicID,
            status: status,
            createdAt: createdAt
        )
    }

    nonisolated static func parseStreakChallenge(_ record: CKRecord) -> StreakChallengeInfo? {
        guard let challengerPublicID = record[CKRecordField.challengerPublicID] as? String,
              let challengerNickname = record[CKRecordField.challengerNickname] as? String,
              let opponentPublicID = record[CKRecordField.opponentPublicID] as? String,
              let opponentNickname = record[CKRecordField.opponentNickname] as? String,
              let status = record[CKRecordField.status] as? String else { return nil }

        let challengerStreak = (record[CKRecordField.challengerStreak] as? Int64).map(Int.init) ?? 0
        let createdAt = record[CKRecordField.createdAt] as? Date ?? Date()
        return StreakChallengeInfo(
            recordName: record.recordID.recordName,
            challengerPublicID: challengerPublicID,
            challengerNickname: challengerNickname,
            challengerStreak: challengerStreak,
            opponentPublicID: opponentPublicID,
            opponentNickname: opponentNickname,
            status: status,
            createdAt: createdAt
        )
    }
}
