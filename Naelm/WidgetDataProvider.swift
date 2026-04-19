//
//  WidgetDataProvider.swift
//  Naelm
//
//  홈 화면 위젯과 앱 간 데이터 공유 유틸리티.
//  App Group UserDefaults를 통해 위젯에 최신 학습 데이터를 전달합니다.
//  ──────────────────────────────────────────────

import Foundation
import WidgetKit

/// 위젯과 앱이 공유하는 UserDefaults 키 정의
enum WidgetDataKey {
    static let streak           = "naelm.widget.streak"
    static let vocabCompleted   = "naelm.widget.vocabCompleted"
    static let grammarCompleted = "naelm.widget.grammarCompleted"
    static let lastUpdated      = "naelm.widget.lastUpdated"
}

/// 앱 그룹 식별자 (Apple Developer Console에서 동일하게 설정해야 합니다)
let naelmAppGroupID = "group.naelm.shared"

@MainActor
final class WidgetDataProvider {

    static let shared = WidgetDataProvider()

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: naelmAppGroupID)
    }

    // MARK: - 위젯 데이터 업데이트

    /// 앱 측에서 호출하여 위젯에 최신 학습 현황을 전달합니다.
    func update(streak: Int, vocabCompleted: Bool, grammarCompleted: Bool) {
        defaults?.set(streak, forKey: WidgetDataKey.streak)
        defaults?.set(vocabCompleted, forKey: WidgetDataKey.vocabCompleted)
        defaults?.set(grammarCompleted, forKey: WidgetDataKey.grammarCompleted)
        defaults?.set(Date(), forKey: WidgetDataKey.lastUpdated)

        // WidgetKit 타임라인 리로드 요청
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 위젯 측 데이터 읽기 (Widget Extension에서도 호출 가능)

    var streak: Int {
        defaults?.integer(forKey: WidgetDataKey.streak) ?? 0
    }

    var vocabCompleted: Bool {
        defaults?.bool(forKey: WidgetDataKey.vocabCompleted) ?? false
    }

    var grammarCompleted: Bool {
        defaults?.bool(forKey: WidgetDataKey.grammarCompleted) ?? false
    }

    var lastUpdated: Date? {
        defaults?.object(forKey: WidgetDataKey.lastUpdated) as? Date
    }
}
