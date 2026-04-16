//
//  AppFonts.swift
//  Naelm
//
//  Pretendard 폰트 + SF Pro Rounded 조합 타이포그래피 시스템
//

import SwiftUI
import UIKit

// MARK: - Font Name Constants

enum PretendardFont {
    static let regular   = "Pretendard-Regular"
    static let medium    = "Pretendard-Medium"
    static let semiBold  = "Pretendard-SemiBold"
    static let bold      = "Pretendard-Bold"
}

// MARK: - Global Font Setup

/// NaelmApp.init()에서 호출 — UIKit 기반 뷰(NavigationBar 타이틀 등)에도 Pretendard 적용
func applyPretendardFonts() {
    // 네비게이션 바 타이틀 (Large)
    let largeTitleAttrs: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: PretendardFont.bold, size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
    ]
    UINavigationBar.appearance().largeTitleTextAttributes = largeTitleAttrs

    // 네비게이션 바 타이틀 (Inline)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: PretendardFont.semiBold, size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
    ]
    UINavigationBar.appearance().titleTextAttributes = titleAttrs

    // 탭 바 아이템 폰트
    let tabItemFont = UIFont(name: PretendardFont.medium, size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .medium)
    UITabBarItem.appearance().setTitleTextAttributes([.font: tabItemFont], for: .normal)
    UITabBarItem.appearance().setTitleTextAttributes([.font: tabItemFont], for: .selected)
}

// MARK: - Font Extension

extension Font {

    // ── Pretendard ─────────────────────────────────────────────────

    /// Pretendard Regular
    static func pretendard(_ size: CGFloat) -> Font {
        .custom(PretendardFont.regular, size: size)
    }

    /// Pretendard Medium
    static func pretendardMedium(_ size: CGFloat) -> Font {
        .custom(PretendardFont.medium, size: size)
    }

    /// Pretendard SemiBold
    static func pretendardSemiBold(_ size: CGFloat) -> Font {
        .custom(PretendardFont.semiBold, size: size)
    }

    /// Pretendard Bold
    static func pretendardBold(_ size: CGFloat) -> Font {
        .custom(PretendardFont.bold, size: size)
    }

    // ── SF Pro Rounded ──────────────────────────────────────────────

    /// SF Pro Rounded — 숫자, 아이콘 레이블, XP 등 게임피케이션 요소에 사용
    static func sfRounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // ── App Typography Scale ────────────────────────────────────────

    /// 단어 카드 영어 단어 (Large Title급, Bold)
    static let cardWordTitle: Font    = pretendardBold(44)

    /// 단어 카드 한국어 뜻 — 단일 (Bold, 큰 사이즈)
    static let cardMeaningLarge: Font = pretendardBold(34)

    /// 단어 카드 한국어 뜻 — 복수 (Bold, 중간 사이즈)
    static let cardMeaningMedium: Font = pretendardBold(28)

    /// 카드 뒷면 멀티 뜻 항목
    static let cardMeaningSmall: Font  = pretendardBold(24)

    /// 발음 기호 (Monospaced-like, Medium)
    static let pronunciation: Font     = pretendardMedium(18)

    /// 예문 (Medium, 이탤릭 처리는 뷰에서)
    static let exampleSentence: Font   = pretendardMedium(15)

    /// 예문 번역 (Regular, Small)
    static let exampleTranslation: Font = pretendard(14)

    /// 일반 본문
    static let body: Font              = pretendard(16)

    /// 부제목 / 레이블
    static let subheadline: Font       = pretendardMedium(15)

    /// 캡션
    static let caption: Font           = pretendard(12)

    /// 캡션 강조
    static let captionBold: Font       = pretendardSemiBold(12)

    /// 네비게이션 타이틀 (SF Pro Rounded)
    static let navTitle: Font          = sfRounded(17, weight: .semibold)

    /// 버튼 텍스트
    static let buttonLabel: Font       = pretendardSemiBold(15)

    /// 탭 항목 레이블
    static let tabLabel: Font          = pretendardMedium(10)

    /// XP / 숫자 강조 (SF Pro Rounded)
    static let xpBadge: Font           = sfRounded(14, weight: .bold)

    /// 뱃지/태그 텍스트
    static let badge: Font             = pretendardSemiBold(11)

    /// 섹션 헤더
    static let sectionHeader: Font     = pretendardSemiBold(13)

    /// 대시보드 대형 숫자 (SF Pro Rounded)
    static let dashboardNumber: Font   = sfRounded(34, weight: .bold)
}
