//
//  HapticManager.swift
//  Naelm
//
//  Created by 김동진 on 4/4/26.
//
//  햅틱 피드백 매니저.
//  ──────────────────────────────────────────────
//  iOS: UIImpactFeedbackGenerator / UINotificationFeedbackGenerator 사용
//  macOS: 햅틱 미지원이므로 no-op 처리
//  ──────────────────────────────────────────────

import SwiftUI

/// 앱 전체에서 사용하는 햅틱 피드백 유틸리티.
/// 정답/오답/스와이프 등 주요 인터랙션에 촉각 피드백을 제공합니다.
@MainActor
final class HapticManager {

    // MARK: - Singleton

    static let shared = HapticManager()
    private init() {}

    // MARK: - Public API

    /// 정답 시 햅틱 (성공 느낌)
    func playCorrect() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// 문법 퀴즈 정답 시 햅틱 (팝 느낌 — success + soft impact)
    func playCorrectAnswer() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred(intensity: 0.6)
        }
        #endif
    }

    /// 문법 퀴즈 오답 시 햅틱 (흔들림 느낌 — error + rigid impact)
    func playWrongAnswer() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred(intensity: 0.7)
        }
        #endif
    }

    /// 오답 시 햅틱 (에러 느낌)
    func playIncorrect() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    /// 카드 스와이프 시 가벼운 햅틱
    func playSwipe() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// 카드 스와이프 완료 (방향 확정) 시 중간 햅틱
    func playSwipeComplete() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    /// 버튼 탭 시 미세한 햅틱
    func playTap() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        #endif
    }

    /// 스트릭 달성 등 축하 이벤트 시 강한 햅틱
    func playCelebration() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        // 짧은 딜레이 후 한 번 더 (더블 탭 느낌)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let second = UIImpactFeedbackGenerator(style: .heavy)
            second.impactOccurred()
        }
        #endif
    }

    /// 선택 변경 시 미세한 피드백
    func playSelection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}
