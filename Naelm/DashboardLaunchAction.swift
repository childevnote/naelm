//
//  DashboardLaunchAction.swift
//  Naelm
//
//  딥링크 / URL scheme 기반 대시보드 실행 액션.
//  ──────────────────────────────────────────────
//  지원 URL 형식 (대소문자 무관):
//    naelm://study/vocabulary  → 단어 학습 시작
//    naelm://study/grammar     → 문법 퀴즈 시작
//    naelm://study/review      → 복습 세션 시작
//  ──────────────────────────────────────────────

import Foundation

/// 딥링크 URL을 파싱하여 대시보드 실행 액션으로 변환합니다.
enum DashboardLaunchAction: Equatable {
    case startVocabulary
    case startGrammar
    case startReview

    /// URL을 받아 매칭되는 액션을 반환합니다.
    /// 스킴, 호스트, 경로 모두 대소문자를 무시합니다.
    /// 매칭되지 않으면 nil을 반환합니다.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "naelm" else { return nil }
        guard let host = url.host?.lowercased(), host == "study" else { return nil }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // 경로는 정확히 "/vocabulary", "/grammar", "/review" 이어야 합니다
        // 후행 슬래시가 있는 "/vocabulary/" 등은 불일치
        switch components.path.lowercased() {
        case "/vocabulary": self = .startVocabulary
        case "/grammar":    self = .startGrammar
        case "/review":     self = .startReview
        default:            return nil
        }
    }
}
