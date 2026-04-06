//
//  AppLogger.swift
//  Toeigo
//
//  디버그 전용 로깅 유틸리티.
//  Release 빌드에서는 로그가 출력되지 않아 보안 위험을 방지한다.
//

import os

/// 앱 전용 로거. Release 빌드에서 민감 정보 노출을 방지한다.
enum AppLogger {

    private static let subsystem = "com.toeigo"

    static let auth     = Logger(subsystem: subsystem, category: "Auth")
    static let data     = Logger(subsystem: subsystem, category: "Data")
    static let session  = Logger(subsystem: subsystem, category: "Session")
    static let srs      = Logger(subsystem: subsystem, category: "SRS")
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
}
