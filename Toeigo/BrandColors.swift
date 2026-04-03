//
//  BrandColors.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  브랜딩 컬러 시스템 — 숲 느낌의 어두운 초록색 기반.
//  ──────────────────────────────────────────────
//  라이트모드: 흰색 배경 + 다크 그린 액센트
//  다크모드: 거의 검정 배경 + 밝은 그린 액센트
//  ──────────────────────────────────────────────

import SwiftUI

// MARK: - Brand Colors

extension Color {

    // ── Primary Brand ───────────────────────
    /// 메인 브랜딩 컬러 — 숲의 어두운 초록
    static let brand = Color("Brand", bundle: nil)

    /// 라이트 버전 — 배지, 배경 틴트 등에 사용
    static let brandLight = Color("BrandLight", bundle: nil)

    /// 다크 버전 — 그림자, 강조 배경 등에 사용
    static let brandDark = Color("BrandDark", bundle: nil)

    // ── Semantic Colors ─────────────────────
    /// "알고있어요" — 숙달 (초록 계열)
    static let knewIt = Color("KnewIt", bundle: nil)

    /// "학습할게요" — 학습 필요 (주황 계열)
    static let studyIt = Color("StudyIt", bundle: nil)

    // ── Fallback (Assets 없을 때) ───────────
    /// 프로그래밍적 브랜드 컬러 (Assets 미등록 시 사용)
    static let brandFallback = Color(red: 0.13, green: 0.30, blue: 0.21)      // #224E36
    static let brandLightFallback = Color(red: 0.20, green: 0.45, blue: 0.32) // #337352
    static let brandDarkFallback = Color(red: 0.08, green: 0.20, blue: 0.14)  // #143324
}

// MARK: - Brand Theme

/// 앱 전체에서 일관된 스타일을 적용하기 위한 테마 유틸리티.
struct BrandTheme {

    // ── Colors ──────────────────────────────

    /// Primary accent color
    static let accent = Color(red: 0.13, green: 0.30, blue: 0.21)          // #224E36 deep forest
    static let accentLight = Color(red: 0.24, green: 0.50, blue: 0.36)     // #3D805C lighter green
    static let accentSoft = Color(red: 0.13, green: 0.30, blue: 0.21).opacity(0.12)

    /// "알고있어요" 버튼/오버레이
    static let knewIt = Color(red: 0.18, green: 0.55, blue: 0.34)          // #2E8C57 medium green
    /// "학습할게요" 버튼/오버레이
    static let studyIt = Color(red: 0.85, green: 0.55, blue: 0.15)         // #D98C26 amber/gold

    /// 카드 배경 (라이트)
    static let cardBackground = Color(red: 0.98, green: 0.98, blue: 0.97)  // warm white
    /// 카드 배경 (다크)
    static let cardBackgroundDark = Color(red: 0.12, green: 0.14, blue: 0.13)

    // ── Gradients ───────────────────────────

    /// 메인 배경 그라데이션
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.13, green: 0.30, blue: 0.21).opacity(0.06),
            Color(red: 0.10, green: 0.22, blue: 0.16).opacity(0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 다크모드 배경 그라데이션
    static let backgroundGradientDark = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.10, blue: 0.08).opacity(0.95),
            Color(red: 0.04, green: 0.06, blue: 0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
