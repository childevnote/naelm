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

    // ARCH FIX: Replaced all DispatchQueue.main.asyncAfter with Task for @MainActor safety

    /// 문법 퀴즈 정답 시 햅틱 (팝 느낌 — success + soft impact)
    func playCorrectAnswer() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
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

    /// 앱 시작 시 환영 햅틱 (부드러운 중간 임팩트)
    func playAppLaunch() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.5)
        #endif
    }

    /// 구독 완료 시 축하 햅틱 (성공 + 더블 임팩트 리듬)
    func playSubscriptionComplete() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
            try? await Task.sleep(nanoseconds: 180_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.6)
        }
        #endif
    }

    /// 북마크 저장 시 가벼운 탭 햅틱
    func playBookmark() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.7)
        #endif
    }

    /// 레벨업 시 강렬한 축하 햅틱 (트리플 임팩트)
    func playLevelUp() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try? await Task.sleep(nanoseconds: 150_000_000)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try? await Task.sleep(nanoseconds: 150_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.5)
        }
        #endif
    }

    /// 온보딩 완료 시 부드러운 성공 햅틱
    func playOnboardingComplete() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.8)
        }
        #endif
    }

    /// 세션 완료 시 보상감 있는 햅틱
    func playSessionComplete() {
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
            try? await Task.sleep(nanoseconds: 150_000_000)
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        }
        #endif
    }

    /// 경고/에러 알림 시 경고 햅틱
    func playWarning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// 토글 변경 시 미세한 임팩트
    func playToggle() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.4)
        #endif
    }
}
