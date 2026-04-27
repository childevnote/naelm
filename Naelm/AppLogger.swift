//
//  AppLogger.swift
//  Naelm
//
//  디버그 전용 로깅 유틸리티.
//  Release 빌드에서는 로그가 출력되지 않아 보안 위험을 방지한다.
//
import Foundation
import os

/// 앱 전용 로거. os.Logger는 Release 빌드에서 문자열 interpolation을 자동 redact합니다.
/// ARCH FIX: 민감 정보(userID 등)는 \(value, privacy: .private) 사용 권장
enum AppLogger {

    private static let subsystem = "com.toeigo"

    static let auth     = Logger(subsystem: subsystem, category: "Auth")
    static let data     = Logger(subsystem: subsystem, category: "Data")
    static let session  = Logger(subsystem: subsystem, category: "Session")
    static let srs      = Logger(subsystem: subsystem, category: "SRS")
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
    static let friend   = Logger(subsystem: subsystem, category: "Friend")
}
