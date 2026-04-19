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
    private let morningReminderIdentifier = "naelm.daily.reminder.morning"
    private let eveningReminderIdentifier = "naelm.daily.reminder.evening"

    /// 하위 호환용 — 기존 단일 식별자 (제거 대상)
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

    /// 오늘의 학습(단어 또는 문법)이 미완료인 경우 08시, 20시 두 번 알림을 예약합니다.
    /// 이미 두 가지 모두 완료된 경우 예약된 알림을 취소합니다.
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

        // 두 가지 모두 완료된 경우 모든 알림 취소
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

        // 08시, 20시 두 번 예약
        let schedule: [(id: String, hour: Int)] = [
            (morningReminderIdentifier, 8),
            (eveningReminderIdentifier, 20)
        ]

        center.removePendingNotificationRequests(
            withIdentifiers: [morningReminderIdentifier, eveningReminderIdentifier, dailyReminderIdentifier]
        )

        for item in schedule {
            let content = UNMutableNotificationContent()
            content.title = "Naelm — 오늘의 학습"
            content.body = body
            content.sound = .default
            content.badge = 1

            var dateComponents = DateComponents()
            dateComponents.hour = item.hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)

            do {
                try await center.add(request)
                AppLogger.session.info("일일 학습 알림 예약 완료 (\(item.hour)시)")
            } catch {
                AppLogger.session.error("알림 예약 실패 (\(item.hour)시): \(error)")
            }
        }
    }

    // MARK: - 알림 취소

    /// 예약된 모든 일일 학습 알림을 취소합니다.
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [morningReminderIdentifier, eveningReminderIdentifier, dailyReminderIdentifier]
        )
        AppLogger.session.info("일일 학습 알림 취소됨")
    }
}
