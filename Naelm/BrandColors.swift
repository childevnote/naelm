//
//  BrandColors.swift
//  Naelm
//
//  Created by 김동진 on 4/4/26.
//
//  ══════════════════════════════════════════════
//  Naelm 디자인 시스템 — 색상 토큰 & 테마
//  ══════════════════════════════════════════════
//
//  팔레트 (4가지 대표 브랜드 색상):
//    Forest    #346739  — 진한 숲 초록 (Primary)
//    Leaf      #79AE6F  — 중간 잎 초록 (Secondary)
//    Mint      #9FCB98  — 연한 민트 초록 (Accent/Light)
//    Cream     #F2EDC2  — 크림 베이지 (Background/Highlight)
//
//  사용 원칙:
//    • AppColor.*   — 시맨틱 토큰 (라이트/다크 자동 분기)
//    • AppPalette.* — 원시 팔레트 색상 (직접 참조는 최소화)
//    • BrandTheme.* — 기존 API 하위 호환용 (deprecated 예정)
//  ══════════════════════════════════════════════

import SwiftUI

// MARK: - Raw Palette (원시 팔레트)

/// 브랜드 4원색 + 보조 원시 색상.
/// 뷰에서 직접 사용하기보다 AppColor 시맨틱 토큰을 통해 사용하세요.
enum AppPalette {
    // ── Brand 4 Colors ─────────────────────────
    /// #346739  진한 숲 초록
    static let forest   = Color(hex: "#346739")
    /// #79AE6F  중간 잎 초록
    static let leaf     = Color(hex: "#79AE6F")
    /// #9FCB98  연한 민트 초록
    static let mint     = Color(hex: "#9FCB98")
    /// #F2EDC2  크림 베이지
    static let cream    = Color(hex: "#F2EDC2")

    // ── Semantic Supplement ─────────────────────
    /// 경고/틀림 — 빨강 계열
    static let error    = Color(hex: "#E05050")
    /// 성공/맞음 — 밝은 초록
    static let success  = Color(hex: "#4CAF50")
    /// 주의/보류 — 앰버
    static let warning  = Color(hex: "#F5A623")
    /// XP/포인트 — 골드
    static let gold     = Color(hex: "#F5C842")
    /// 문법 — 진한 갈색
    static let grammarBrown = Color(hex: "#6B4226")
}

// MARK: - Semantic Color Tokens (시맨틱 토큰)

/// 앱 전체에서 사용하는 컬러 토큰.
/// 라이트/다크 모드에 따라 자동으로 적절한 원시 팔레트 색상을 반환합니다.
struct AppColor {

    // ══ Primary ════════════════════════════════
    /// 가장 중요한 브랜드 색상 — 버튼, 강조 텍스트, 아이콘
    /// Light: Forest  |  Dark: Mint
    static let primary = Color("ACPrimary")

    /// Primary의 불투명 배경용 — 배지, 태그 배경
    /// Light: Forest 12%  |  Dark: Mint 18%
    static let primaryContainer = Color("ACPrimaryContainer")

    // ══ Secondary ══════════════════════════════
    /// 보조 강조 색상 — 부제목, 아이콘 보조
    /// Light: Leaf  |  Dark: Leaf (slightly brighter)
    static let secondary = Color("ACSecondary")

    // ══ Accent ═════════════════════════════════
    /// 경량 액센트 — 진행 바, 하이라이트
    /// Light: Mint  |  Dark: Mint lighter
    static let accent = Color("ACAccent")

    // ══ Background ════════════════════════════
    /// 앱 배경
    /// Light: White  |  Dark: #0F1A10 (거의 검정)
    static let background = Color("ACBackground")

    /// 카드/시트 배경
    /// Light: White  |  Dark: #1A2B1B
    static let surface = Color("ACSurface")

    /// 그룹형 목록 배경
    /// Light: #F7F7F0 (크림빛 흰색)  |  Dark: #0D160E
    static let groupedBackground = Color("ACGroupedBackground")

    // ══ Highlight ══════════════════════════════
    /// 크림 하이라이트 — 완료 배너, 칭찬 배경
    /// Light: Cream  |  Dark: Cream 20%
    static let highlight = Color("ACHighlight")

    // ══ Text / Label ═══════════════════════════
    /// 기본 텍스트
    static let label = Color.primary

    /// 보조 텍스트
    static let labelSecondary = Color.secondary

    // ══ Status ═════════════════════════════════
    /// "알았어요" 정답 색상
    static let correct  = AppPalette.success
    /// "틀렸어요" 오답 색상
    static let incorrect = AppPalette.error
    /// XP / 포인트 색상
    static let xp       = AppPalette.gold
    /// 경고 색상
    static let caution  = AppPalette.warning
}

// MARK: - Color Asset Fallback Extension

/// Assets.xcassets 에 색상이 등록되지 않은 경우를 위한 폴백.
/// ColorAsset이 없을 때 프로그래밍적 색상을 반환합니다.
extension Color {
    /// 16진수 문자열로 Color 생성. "#RRGGBB" 또는 "RRGGBB" 형식 지원.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Gradient Tokens (그라데이션 토큰)

/// 앱 전반에서 사용하는 표준 그라데이션.
struct AppGradient {

    /// 메인 화면 배경 그라데이션 — 은은한 숲초록 → 흰색
    static func background(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(
            colors: [
                Color(hex: "#0E1612"),
                Color(hex: "#0A0A0A")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        : LinearGradient(
            colors: [
                AppPalette.forest.opacity(0.06),
                AppPalette.leaf.opacity(0.04),
                Color.white
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// 완료/축하 화면 배경 그라데이션
    static func celebration(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(
            colors: [
                AppPalette.forest.opacity(0.25),
                Color(hex: "#111111"),
                Color(hex: "#0A0A0A")
            ],
            startPoint: .top, endPoint: .bottom
        )
        : LinearGradient(
            colors: [
                AppPalette.forest.opacity(0.10),
                AppPalette.leaf.opacity(0.06),
                Color.white
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Hero / 로그인 배경 — 더 진한 그라데이션
    static func hero(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(
            colors: [
                Color(hex: "#0E1612"),
                Color(hex: "#1A2B1C"),
                Color(hex: "#0E1612")
            ],
            startPoint: .top, endPoint: .bottom
        )
        : LinearGradient(
            colors: [
                AppPalette.forest.opacity(0.10),
                AppPalette.mint.opacity(0.08),
                Color(hex: "#F4F8F4")
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// XP / 포인트 뱃지 그라데이션
    static let xpBadge = LinearGradient(
        colors: [Color(hex: "#F5C842"), Color(hex: "#F5A623")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Primary 버튼 그라데이션
    static func primaryButton(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(
            colors: [AppPalette.leaf, AppPalette.forest],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        : LinearGradient(
            colors: [AppPalette.forest, Color(hex: "#2A5430")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// 카드 하이라이트 그라데이션 (카드 상단 shimmer용)
    static func cardShimmer(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(
            colors: [AppPalette.leaf.opacity(0.12), .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        : LinearGradient(
            colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Design Helpers (리퀴드 글래스 디자인)

extension View {
    /// 리퀴드 글래스 카드 배경을 적용합니다 (iOS 26+).
    func glassCard(cornerRadius: CGFloat = 20, scheme: ColorScheme = .light) -> some View {
        self.background(
            GlassCardBackground(cornerRadius: cornerRadius, scheme: scheme)
        )
    }

    /// 탭바 / 네비게이션 글래스 배경 설정
    func glassTabBar() -> some View {
        self
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
    }

    /// 리퀴드 글래스 프레스 애니메이션 — 터치 시 물방울 효과
    func pressAnimation() -> some View {
        self.modifier(LiquidPressModifier())
    }
}

/// 리퀴드 글래스 카드 배경 뷰.
/// ultraThinMaterial + 그라데이션 오버레이 + 테두리로 glass 효과를 구현합니다.
struct GlassCardBackground: View {
    let cornerRadius: CGFloat
    let scheme: ColorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)

            // 상단 shimmer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppGradient.cardShimmer(scheme: scheme))

            // 테두리
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: scheme == .dark
                            ? [Color.white.opacity(0.15), Color.white.opacity(0.04)]
                            : [Color.white.opacity(0.8), AppPalette.leaf.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Liquid Press Effect (물방울 터치 효과)

/// 터치 시 눌린 부분이 물방울처럼 살짝 확대되었다가 원래 크기로 돌아오는 효과.
struct LiquidPressModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? 0.02 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: 10,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
    }
}


// MARK: - Typography Helpers (텍스트 스타일 보조)

extension Font {
    /// 앱 표준 타이틀 폰트
    static let appTitle     = Font.system(size: 28, weight: .bold, design: .rounded)
    /// 앱 표준 헤드라인
    static let appHeadline  = Font.system(size: 20, weight: .semibold, design: .rounded)
    /// 앱 표준 서브헤드라인
    static let appSubhead   = Font.system(size: 15, weight: .medium, design: .rounded)
    /// 앱 표준 캡션
    static let appCaption   = Font.system(size: 12, weight: .regular, design: .rounded)
}

// MARK: - BrandTheme (하위 호환 — Deprecated)
// 기존 코드에서 BrandTheme.*를 사용하는 부분과의 호환성 유지.
// 신규 코드에서는 AppColor.* / AppPalette.* 를 사용하세요.

struct BrandTheme {

    // ── Colors ──────────────────────────────────
    /// Primary accent (Forest green)
    static let accent       = AppPalette.forest        // #346739
    static let accentLight  = AppPalette.leaf          // #79AE6F
    static let accentSoft   = AppPalette.forest.opacity(0.12)

    /// 정답 색상 — 차분한 초록 (forest 계열 통일)
    static let knewIt       = AppPalette.leaf          // #79AE6F
    /// 학습 필요 색상 — 부드러운 테라코타 (눈에 덜 자극적)
    static let studyIt      = Color(hex: "#C4886B")    // Muted terracotta

    /// 카드 배경 (라이트)
    static let cardBackground     = Color(hex: "#FAFAF8")
    /// 카드 배경 (다크)
    static let cardBackgroundDark = Color(hex: "#1C1C1E")

    // ── Gradients ────────────────────────────────
    /// 메인 배경 그라데이션 (라이트)
    static let backgroundGradient = LinearGradient(
        colors: [
            AppPalette.forest.opacity(0.06),
            AppPalette.leaf.opacity(0.04),
            Color.white
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// 다크모드 배경 그라데이션
    static let backgroundGradientDark = LinearGradient(
        colors: [
            Color(hex: "#0E1612"),
            Color(hex: "#0A0A0A")
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
