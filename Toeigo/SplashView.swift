//
//  SplashView.swift
//  Toeigo
//
//  ══════════════════════════════════════════════
//  앱 초기 로딩 스플래시 화면
//  ══════════════════════════════════════════════
//  흐름:
//    1. 앱 아이콘(placeholder) + 이름 + 슬로건 페이드인
//    2. 2초 대기
//    3. 페이드아웃 후 메인 화면 전환
//  ══════════════════════════════════════════════

import SwiftUI

struct SplashView: View {

    @Environment(\.colorScheme) private var colorScheme

    /// 스플래시 완료 콜백
    let onComplete: () -> Void

    // ── 애니메이션 상태 ──
    @State private var logoScale: CGFloat     = 0.5
    @State private var logoOpacity: Double    = 0.0
    @State private var titleOpacity: Double   = 0.0
    @State private var titleOffset: CGFloat   = 20
    @State private var sloganOpacity: Double  = 0.0
    @State private var sloganOffset: CGFloat  = 16
    @State private var bgOpacity: Double      = 0.0
    @State private var wholeOpacity: Double   = 1.0

    var body: some View {
        ZStack {
            // 배경 그라데이션
            splashBackground
                .ignoresSafeArea()
                .opacity(bgOpacity)

            VStack(spacing: 0) {
                Spacer()

                // ── 앱 아이콘 영역 ─────────────────────
                appIconView
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Spacer().frame(height: 32)

                // ── 앱 이름 ────────────────────────────
                Text("Toeigo")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Spacer().frame(height: 10)

                // ── 슬로건 ─────────────────────────────
                Text("토익 영단어 · 문법 마스터")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(sloganColor)
                    .opacity(sloganOpacity)
                    .offset(y: sloganOffset)

                Spacer()

                // ── 하단 로딩 인디케이터 ───────────────
                loadingDots
                    .opacity(sloganOpacity)
                    .padding(.bottom, 60)
            }
        }
        .opacity(wholeOpacity)
        .onAppear { startAnimation() }
    }

    // MARK: - Background

    private var splashBackground: some View {
        colorScheme == .dark
        ? LinearGradient(
            colors: [
                Color(hex: "#0B1A0C"),
                Color(hex: "#0F2210"),
                Color(hex: "#091408")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        : LinearGradient(
            colors: [
                AppPalette.forest,
                Color(hex: "#2A5430"),
                Color(hex: "#1E3D22")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - App Icon

    private var appIconView: some View {
        ZStack {
            // 외곽 글로우 링
            Circle()
                .fill(AppPalette.mint.opacity(colorScheme == .dark ? 0.15 : 0.20))
                .frame(width: 150, height: 150)
                .blur(radius: 20)

            // 아이콘 배경
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            AppPalette.mint.opacity(colorScheme == .dark ? 0.9 : 1.0),
                            AppPalette.leaf.opacity(colorScheme == .dark ? 0.9 : 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 108, height: 108)
                .shadow(
                    color: AppPalette.forest.opacity(0.5),
                    radius: 20, x: 0, y: 8
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                )

            // 아이콘 심볼 (캐릭터 추가 전 placeholder)
            VStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                Text("T")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    // MARK: - Loading Dots

    private var loadingDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                BouncingDot(delay: Double(i) * 0.2)
                    .foregroundStyle(dotColor)
            }
        }
    }

    // MARK: - Colors (다크/라이트 분기)

    private var titleColor: Color {
        colorScheme == .dark ? AppPalette.mint : Color.white
    }

    private var sloganColor: Color {
        colorScheme == .dark ? AppPalette.cream.opacity(0.75) : Color.white.opacity(0.80)
    }

    private var dotColor: Color {
        colorScheme == .dark ? AppPalette.mint.opacity(0.6) : Color.white.opacity(0.55)
    }

    // MARK: - Animation

    private func startAnimation() {
        // 배경 페이드인
        withAnimation(.easeIn(duration: 0.35)) {
            bgOpacity = 1.0
        }

        // 로고 팝인
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.15)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }

        // 타이틀 슬라이드업
        withAnimation(.easeOut(duration: 0.45).delay(0.5)) {
            titleOpacity = 1.0
            titleOffset  = 0
        }

        // 슬로건 슬라이드업
        withAnimation(.easeOut(duration: 0.40).delay(0.7)) {
            sloganOpacity = 1.0
            sloganOffset  = 0
        }

        // 2초 후 페이드아웃 후 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.45)) {
                wholeOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onComplete()
            }
        }
    }
}

// MARK: - Bouncing Dot

private struct BouncingDot: View {
    let delay: Double
    @State private var isUp = false

    var body: some View {
        Circle()
            .frame(width: 7, height: 7)
            .offset(y: isUp ? -6 : 0)
            .animation(
                .easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isUp
            )
            .onAppear { isUp = true }
    }
}

// MARK: - Preview

#Preview("Splash — Light") {
    SplashView(onComplete: {})
        .preferredColorScheme(.light)
}

#Preview("Splash — Dark") {
    SplashView(onComplete: {})
        .preferredColorScheme(.dark)
}
