//
//  KeychainHelper.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  Keychain 저장/조회 유틸리티.
//  ──────────────────────────────────────────────
//  Security 프레임워크를 사용하여 Sign in with Apple의
//  userIdentifier를 안전하게 저장합니다.
//  앱 삭제 후에도 Keychain 데이터는 유지됩니다.
//  ──────────────────────────────────────────────

import Foundation
import Security

/// Keychain 기본 CRUD 래퍼.
final class KeychainHelper {

    // MARK: - Constants

    /// Keychain 서비스 식별자
    private static let service = "com.toeigo.auth"

    /// userIdentifier 저장 키
    static let userIDKey = "apple_user_identifier"

    // MARK: - Save

    /// Keychain에 문자열 값을 저장합니다.
    /// 이미 같은 키가 있으면 업데이트합니다.
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // 기존 항목 삭제 (upsert 패턴)
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✅ [Keychain] Saved key: \(key)")
            return true
        } else {
            print("❌ [Keychain] Save failed for key: \(key), status: \(status)")
            return false
        }
    }

    // MARK: - Read

    /// Keychain에서 문자열 값을 읽습니다.
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Delete

    /// Keychain에서 항목을 삭제합니다.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Exists

    /// Keychain에 해당 키가 존재하는지 확인합니다.
    static func exists(key: String) -> Bool {
        return read(key: key) != nil
    }
}
