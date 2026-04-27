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
}

// MARK: - 공개 프로필 데이터 구조체

/// CloudKit Public DB에서 조회한 유저 공개 정보
struct PublicUserInfo: Identifiable {
    let id = UUID()
    let userID: String        // Sign in with Apple userIdentifier
    let nickname: String      // 닉네임
    let monthlyXP: Int        // 이번 달 XP (랭킹용)
    let totalXP: Int          // 누적 총 XP
    let streak: Int           // 연속 학습일
    let weeklyXP: Int         // 이번 주 XP
    let recordName: String    // CKRecord.ID.recordName (업데이트용)
}

// MARK: - 친구 요청 데이터 구조체

/// CloudKit의 FriendRequest 레코드 파싱 결과
struct FriendRequestInfo: Identifiable {
    let id = UUID()
    let recordName: String    // CKRecord.ID.recordName
    let fromUserID: String
    let fromNickname: String
    let toUserID: String
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

    /// UserPublicProfile 레코드 이름 (해시 기반)
    nonisolated private static func profileRecordName(for userID: String) -> String {
        "profile_\(hashedPublicID(from: userID))"
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
        weeklyXP: Int = 0
    ) async throws {
        let recordName = Self.profileRecordName(for: userID)
        let recordID = CKRecord.ID(recordName: recordName)

        // 기존 레코드 조회 시도 후 없으면 새로 생성
        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: CKRecordType.userPublicProfile, recordID: recordID)
        }

        record["userID"] = userID as CKRecordValue
        record["nickname"] = nickname as CKRecordValue
        record["monthlyXP"] = Int64(monthlyXP) as CKRecordValue
        record["totalXP"] = Int64(totalXP) as CKRecordValue
        record["streak"] = Int64(streak) as CKRecordValue
        record["weeklyXP"] = Int64(weeklyXP) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        try await publicDB.save(record)
    }

    /// 닉네임으로 Public Profile을 검색합니다.
    func searchUsers(nickname: String) async throws -> [PublicUserInfo] {
        let predicate = NSPredicate(format: "nickname BEGINSWITH[cd] %@", nickname)
        let query = CKQuery(recordType: CKRecordType.userPublicProfile, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "nickname", ascending: true)]

        let (results, _) = try await publicDB.records(
            matching: query,
            desiredKeys: ["userID", "nickname", "monthlyXP", "totalXP", "streak", "weeklyXP"],
            resultsLimit: 20
        )

        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Self.parsePublicProfile(record)
        }
    }

    /// 특정 userID의 Public Profile을 가져옵니다.
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
            operation.desiredKeys = ["userID", "nickname", "monthlyXP", "totalXP", "streak", "weeklyXP"]

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

    // ── 친구 요청 관리 ──────────────────────────────────────

    /// 친구 요청을 Public DB에 생성합니다.
    /// 반환값: 생성된 CKRecord의 recordName (String)
    func sendFriendRequest(
        fromUserID: String,
        fromNickname: String,
        toUserID: String
    ) async throws -> String {
        let record = CKRecord(recordType: CKRecordType.friendRequest)
        record["fromUserID"] = fromUserID as CKRecordValue
        record["fromNickname"] = fromNickname as CKRecordValue
        record["toUserID"] = toUserID as CKRecordValue
        record["status"] = "pending" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        let saved = try await publicDB.save(record)
        return saved.recordID.recordName
    }

    /// 내가 받은 대기 중인 친구 요청 목록을 가져옵니다.
    func fetchPendingRequests(toUserID: String) async throws -> [FriendRequestInfo] {
        let predicate = NSPredicate(format: "toUserID == %@ AND status == 'pending'", toUserID)
        let query = CKQuery(recordType: CKRecordType.friendRequest, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)

        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Self.parseFriendRequest(record)
        }
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
        let predicate = NSPredicate(
            format: "fromUserID == %@ AND toUserID == %@ AND status == 'pending'",
            fromUserID, toUserID
        )
        let query = CKQuery(recordType: CKRecordType.friendRequest, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        return !results.isEmpty
    }

    // MARK: - 정적 파싱 헬퍼
    // static으로 선언하여 CKFetchRecordsOperation 백그라운드 콜백에서도 actor 격리 없이 호출 가능

    nonisolated static func parsePublicProfile(_ record: CKRecord) -> PublicUserInfo? {
        guard let userID = record["userID"] as? String,
              let nickname = record["nickname"] as? String else { return nil }

        let monthlyXP = (record["monthlyXP"] as? Int64).map(Int.init) ?? 0
        let totalXP = (record["totalXP"] as? Int64).map(Int.init) ?? 0
        let streak = (record["streak"] as? Int64).map(Int.init) ?? 0
        let weeklyXP = (record["weeklyXP"] as? Int64).map(Int.init) ?? 0

        return PublicUserInfo(
            userID: userID,
            nickname: nickname,
            monthlyXP: monthlyXP,
            totalXP: totalXP,
            streak: streak,
            weeklyXP: weeklyXP,
            recordName: record.recordID.recordName
        )
    }

    nonisolated static func parseFriendRequest(_ record: CKRecord) -> FriendRequestInfo? {
        guard let fromUserID = record["fromUserID"] as? String,
              let fromNickname = record["fromNickname"] as? String,
              let toUserID = record["toUserID"] as? String,
              let status = record["status"] as? String else { return nil }

        let createdAt = record["createdAt"] as? Date ?? Date()

        return FriendRequestInfo(
            recordName: record.recordID.recordName,
            fromUserID: fromUserID,
            fromNickname: fromNickname,
            toUserID: toUserID,
            status: status,
            createdAt: createdAt
        )
    }
}
