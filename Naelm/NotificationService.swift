//
//  NotificationService.swift
//  Naelm
//
//  일일 학습 알림 서비스.
//  ──────────────────────────────────────────────
//  역할:
//    1. 알림 권한 요청 (최초 1회)
//    2. 오늘 단어/문법 학습이 미완료 시 당일 저녁 알림 예약
//    3. 학습 완료 시 당일 예약 알림 취소
//  ──────────────────────────────────────────────

import Foundation
import UserNotifications
import os

@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    /// 일일 알림 식별자 (취소 시 사용)
    private let dailyReminderIdentifier = "naelm.daily.reminder"

    private init() {}

    // MARK: - 권한 요청

    /// 알림 권한을 요청합니다. 이미 허용/거부된 경우 OS가 다시 묻지 않습니다.
    func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            AppLogger.session.info("알림 권한 요청 결과: \(granted)")
        } catch {
            AppLogger.session.error("알림 권한 요청 실패: \(error)")
        }
    }

    // MARK: - 일일 학습 알림 예약

    /// 오늘의 학습(단어 또는 문법)이 미완료인 경우 당일 저녁 알림을 예약합니다.
    /// 이미 두 가지 모두 완료된 경우 당일 예약을 취소합니다.
    /// - Parameters:
    ///   - vocabCompleted: 오늘 단어 학습 완료 여부
    ///   - grammarCompleted: 오늘 문법 학습 완료 여부
    ///   - reminderHour: 알림 시각 (기본 저녁 8시)
    func scheduleDailyReminderIfNeeded(
        vocabCompleted: Bool,
        grammarCompleted: Bool,
        reminderHour: Int = 20
    ) async {
        // 권한 상태 확인
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            AppLogger.session.info("알림 권한 없음 — 알림 예약 건너뜀")
            return
        }

        // 두 가지 모두 완료된 경우 당일 알림 취소
        if vocabCompleted && grammarCompleted {
            cancelDailyReminder()
            return
        }

        // 알림 메시지 구성
        let body: String
        switch (vocabCompleted, grammarCompleted) {
        case (false, false):
            body = "오늘 단어와 문법 학습이 아직 남아 있어요! 지금 시작해볼까요? 📚"
        case (true, false):
            body = "단어 학습은 완료했네요! 문법 퀴즈도 도전해보세요 ✏️"
        case (false, true):
            body = "문법 퀴즈는 완료했네요! 오늘의 단어 학습도 해볼까요? 📖"
        default:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Naelm — 오늘의 학습"
        content.body = body
        content.sound = .default
        content.badge = 1

        // 오늘 reminderHour시에 트리거.
        // 이미 해당 시각이 지난 경우 UNCalendarNotificationTrigger는 내일 같은 시각에 자동 예약됩니다.
        // repeats: false 이므로 매일 refreshStats() 호출 시 재예약됩니다.
        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        // 기존 예약 교체 (remove + add)
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])

        do {
            try await center.add(request)
            AppLogger.session.info("일일 학습 알림 예약 완료 (\(reminderHour)시)")
        } catch {
            AppLogger.session.error("알림 예약 실패: \(error)")
        }
    }

    // MARK: - 알림 취소

    /// 예약된 일일 학습 알림을 취소합니다.
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        AppLogger.session.info("일일 학습 알림 취소됨")
    }
}
