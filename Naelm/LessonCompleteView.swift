//
//  LessonCompleteView.swift
//  Naelm
//
//  ══════════════════════════════════════════════
//  학습 완료 축하 화면
//  ══════════════════════════════════════════════
//  표시 흐름:
//    1. "학습을 완료했어요!" 텍스트가 크게 나타났다 사라짐 (인트로 애니메이션)
//    2. XP 획득 카드 + (오늘 첫 학습이면) 연속 학습일 표시
//    3. 점수 변동 카드 (scoreDelta != 0인 경우)
//    4. 홈으로 버튼 + 인스타그램 스토리 공유 버튼
//  ══════════════════════════════════════════════

import SwiftUI

// MARK: - Data Model

/// 학습 완료 시 전달할 결과 데이터
struct LessonResult {
    /// 이번 세션에서 획득한 XP
    let xpEarned: Int
    /// 오늘 첫 학습 여부 (첫 학습이면 연속 학습일도 표시)
    let isFirstStudyToday: Bool
    /// 현재 연속 학습 일수 (isFirstStudyToday == true 일 때만 의미 있음)
    let streakDays: Int
    /// 학습 유형 레이블 (예: "단어 학습", "문법 퀴즈")
    let sessionLabel: String
    /// 이번 세션으로 변동된 추정 TOEIC 점수 (5의 배수, 0이면 미표시)
    let scoreDelta: Int
    /// 세션 후 갱신된 추정 점수 (scoreDelta != 0일 때 표시)
    let updatedEstimatedScore: Int
}

// MARK: - LessonCompleteView

struct LessonCompleteView: View {

    let result: LessonResult
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // ── 애니메이션 상태 ──
    @State private var phase: AnimationPhase = .intro
    @State private var introScale: CGFloat = 0.3
    @State private var introOpacity: Double = 0.0
    @State private var contentOpacity: Double = 0.0
    @State private var contentOffset: CGFloat = 40
    @State private var xpCountDisplayed: Int = 0
    @State private var xpCardScale: CGFloat = 0.7
    @State private var streakCardScale: CGFloat = 0.7
    @State private var scoreCardScale: CGFloat = 0.7
    @State private var buttonOpacity: Double = 0.0
    @State private var particleOpacity: Double = 0.0
    @State private var isShareSheetPresented: Bool = false
    @State private var shareImage: UIImage? = nil
    // 파티클들
    @State private var particles: [ParticleData] = LessonCompleteView.makeParticles()

    enum AnimationPhase {
        case intro       // "학습 완료!" 텍스트 표시
        case fadeOut     // 텍스트 사라짐
        case content     // 결과 카드 표시
    }

    var body: some View {
        ZStack {
            // 배경
            AppGradient.celebration(scheme: colorScheme)
                .ignoresSafeArea()

            // 파티클 레이어
            particleLayer
                .opacity(particleOpacity)
                .ignoresSafeArea()

            // 인트로 텍스트
            if phase == .intro || phase == .fadeOut {
                introTextView
            }

            // 결과 컨텐츠
            if phase == .content {
                resultContentView
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
            }
        }
        .onAppear { startAnimation() }
        .sheet(isPresented: $isShareSheetPresented) {
            if let img = shareImage {
                ShareSheet(activityItems: [img])
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Intro Text

    private var introTextView: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.system(size: 72))
            Text("학습을 완료했어요!")
                .font(.pretendardBold(34))
                .foregroundStyle(
                    colorScheme == .dark ? AppPalette.mint : AppPalette.forest
                )
                .multilineTextAlignment(.center)
            Text(result.sessionLabel)
                .font(.pretendardMedium(15))
                .foregroundStyle(.secondary)
        }
        .scaleEffect(introScale)
        .opacity(introOpacity)
        .padding(.horizontal, 32)
    }

    // MARK: - Result Content

    private var resultContentView: some View {
        VStack(spacing: 28) {
            Spacer()

            // 상단 아이콘
            ZStack {
                Circle()
                    .fill(AppPalette.forest.opacity(colorScheme == .dark ? 0.25 : 0.10))
                    .frame(width: 110, height: 110)
                Text("✅")
                    .font(.system(size: 56))
            }

            // 메인 타이틀
            VStack(spacing: 6) {
                Text("수고했어요! 👏")
                    .font(.pretendardBold(26))
                    .foregroundStyle(colorScheme == .dark ? AppPalette.mint : AppPalette.forest)
                Text(result.sessionLabel + " 완료")
                    .font(.pretendardMedium(15))
                    .foregroundStyle(.secondary)
            }

            // 카드 영역
            VStack(spacing: 16) {
                // XP 카드
                xpCard
                    .scaleEffect(xpCardScale)

                // 연속 학습일 카드 (오늘 첫 학습일 때만)
                if result.isFirstStudyToday && result.streakDays > 0 {
                    streakCard
                        .scaleEffect(streakCardScale)
                }

                // 추정 점수 변동 카드
                if result.scoreDelta != 0 {
                    scoreDeltaCard
                        .scaleEffect(scoreCardScale)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // 버튼 영역
            VStack(spacing: 12) {
                // 인스타그램 스토리 공유 버튼
                Button {
                    HapticManager.shared.playTap()
                    renderShareCard()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("스토리 공유하기")
                            .font(.pretendardSemiBold(16))
                    }
                    .foregroundStyle(colorScheme == .dark ? AppPalette.mint : AppPalette.forest)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                colorScheme == .dark ? AppPalette.mint.opacity(0.5) : AppPalette.forest.opacity(0.4),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                // 홈으로 버튼
                Button {
                    HapticManager.shared.playTap()
                    onDismiss()
                } label: {
                    Text("홈으로")
                        .font(.pretendardBold(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppGradient.primaryButton(scheme: colorScheme))
                                .shadow(
                                    color: AppPalette.forest.opacity(0.40),
                                    radius: 10, x: 0, y: 4
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
            .opacity(buttonOpacity)

            Spacer().frame(height: 20)
        }
    }

    // MARK: - XP Card

    private var xpCard: some View {
        HStack(spacing: 20) {
            // 번개 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppGradient.xpBadge)
                    .frame(width: 60, height: 60)
                    .shadow(color: AppPalette.gold.opacity(0.5), radius: 6, y: 2)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("획득한 XP")
                    .font(.captionBold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("+\(xpCountDisplayed)")
                        .font(.sfRounded(38, weight: .bold))
                        .foregroundStyle(AppPalette.gold)
                        .contentTransition(.numericText(value: Double(xpCountDisplayed)))
                    Text("XP")
                        .font(.pretendardSemiBold(18))
                        .foregroundStyle(AppPalette.gold.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(hex: "#1E2E1E") : Color.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppPalette.gold.opacity(0.25), lineWidth: 1.5)
        )
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 20) {
            // 불꽃 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF6B35"), Color(hex: "#FF4500")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(hex: "#FF6B35").opacity(0.5), radius: 6, y: 2)
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("연속 학습")
                    .font(.captionBold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(result.streakDays)")
                        .font(.sfRounded(38, weight: .bold))
                        .foregroundStyle(Color(hex: "#FF6B35"))
                    Text("일 연속! 🔥")
                        .font(.pretendardSemiBold(18))
                        .foregroundStyle(Color(hex: "#FF6B35").opacity(0.9))
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(hex: "#2B1E1A") : Color.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#FF6B35").opacity(0.25), lineWidth: 1.5)
        )
    }

    // MARK: - Score Delta Card

    private var scoreDeltaCard: some View {
        let isUp = result.scoreDelta > 0
        let accentColor: Color = isUp ? AppPalette.mint : Color(hex: "#FF4757")
        let bgColor: Color = colorScheme == .dark
            ? (isUp ? Color(hex: "#0D2B1E") : Color(hex: "#2B0D0D"))
            : Color.white
        let icon = isUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        let label = isUp ? "점수 상승 🎯" : "점수 하락"

        return HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isUp
                                ? [AppPalette.forest, AppPalette.mint]
                                : [Color(hex: "#FF4757"), Color(hex: "#C0392B")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: accentColor.opacity(0.5), radius: 6, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.captionBold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(isUp ? "+\(result.scoreDelta)" : "\(result.scoreDelta)")
                        .font(.sfRounded(38, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text("점")
                        .font(.pretendardSemiBold(18))
                        .foregroundStyle(accentColor.opacity(0.8))
                }
                Text("현재 추정: \(result.updatedEstimatedScore)점대")
                    .font(.pretendardMedium(12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(bgColor)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor.opacity(0.25), lineWidth: 1.5)
        )
    }

    // MARK: - Share Card (인스타 스토리용 렌더링)

    /// 공유용 카드 뷰 (ImageRenderer로 렌더링)
    @ViewBuilder
    private func shareCardContent() -> some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.forest, AppPalette.leaf, AppPalette.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 24) {
                Spacer()

                Text("낼름")
                    .font(.custom("Pretendard-Black", size: 42))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(4)

                Text("TOEIC 학습 완료")
                    .font(.custom("Pretendard-Medium", size: 18))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer().frame(height: 8)

                VStack(spacing: 16) {
                    shareStatRow(icon: "bolt.fill", label: "획득 XP", value: "+\(result.xpEarned) XP", color: AppPalette.gold)

                    if result.scoreDelta != 0 {
                        shareStatRow(
                            icon: result.scoreDelta > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                            label: "점수 변동",
                            value: (result.scoreDelta > 0 ? "+" : "") + "\(result.scoreDelta)점",
                            color: result.scoreDelta > 0 ? AppPalette.mint : Color(hex: "#FF4757")
                        )
                    }

                    if result.isFirstStudyToday && result.streakDays > 0 {
                        shareStatRow(icon: "flame.fill", label: "연속 학습", value: "\(result.streakDays)일 연속 🔥", color: Color(hex: "#FF6B35"))
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                Text("#낼름 #TOEIC #영어공부")
                    .font(.custom("Pretendard-Regular", size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 32)
            }
        }
        .frame(width: 390, height: 844) // iPhone 표준 비율 (9:19.5)
    }

    private func shareStatRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32)
            Text(label)
                .font(.custom("Pretendard-Medium", size: 16))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.custom("Pretendard-Bold", size: 18))
                .foregroundStyle(.white)
        }
    }

    /// ImageRenderer로 공유 카드를 이미지로 렌더링 후 UIActivityViewController 표시
    @MainActor
    private func renderShareCard() {
        let cardView = shareCardContent()
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // Retina
        guard let uiImage = renderer.uiImage else { return }
        shareImage = uiImage
        isShareSheetPresented = true
    }

    // MARK: - Particle Layer

    private var particleLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .position(
                            x: geo.size.width * p.x,
                            y: geo.size.height * p.y
                        )
                        .opacity(p.opacity)
                }
            }
        }
    }

    // MARK: - Animation Sequence

    // ARCH FIX: Replaced DispatchQueue.main.asyncAfter with structured Task for memory safety
    private func startAnimation() {
        // 1) 인트로 텍스트 팝인
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            introScale = 1.0
            introOpacity = 1.0
        }

        Task { @MainActor in
            // 파티클 폭발
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeOut(duration: 0.4)) {
                particleOpacity = 1.0
            }
            HapticManager.shared.playCelebration()
            animateParticles()

            // 2) 인트로 텍스트 페이드아웃
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeIn(duration: 0.5)) {
                introOpacity = 0
                introScale = 1.3
            }

            // 3) 결과 컨텐츠 등장
            try? await Task.sleep(nanoseconds: 500_000_000)
            phase = .content
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                contentOpacity = 1.0
                contentOffset = 0
            }

            // 4) XP 카드 팝인
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                xpCardScale = 1.0
            }
            animateXPCount()

            // 5) 스트릭 카드 팝인
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                streakCardScale = 1.0
            }

            // 6) 점수 변동 카드 팝인
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scoreCardScale = 1.0
            }

            // 7) 버튼 페이드인
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.easeOut(duration: 0.4)) {
                buttonOpacity = 1.0
            }
        }
    }

    private func animateXPCount() {
        let target = result.xpEarned
        guard target > 0 else {
            xpCountDisplayed = 0
            return
        }
        let duration = 1.0
        let steps = min(target, 60)
        let stepInterval = duration / Double(steps)

        // ARCH FIX: Use Task instead of DispatchQueue.main.asyncAfter loop
        Task { @MainActor in
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
                let progress = Double(i) / Double(steps)
                let easedProgress = 1.0 - pow(1.0 - progress, 2)
                withAnimation(.linear(duration: stepInterval)) {
                    xpCountDisplayed = Int(Double(target) * easedProgress)
                }
            }
        }
    }

    private func animateParticles() {
        // ARCH FIX: Use Task instead of DispatchQueue.main.asyncAfter
        for i in particles.indices {
            let delay = UInt64(Double.random(in: 0...0.3) * 1_000_000_000)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: delay)
                withAnimation(
                    .easeOut(duration: Double.random(in: 1.2...2.0))
                ) {
                    particles[i].y += Double.random(in: 0.1...0.5)
                    particles[i].opacity = 0.0
                }
            }
        }
    }

    static func makeParticles() -> [ParticleData] {
        let colors: [Color] = [
            AppPalette.forest, AppPalette.leaf, AppPalette.mint, AppPalette.cream,
            AppPalette.gold, Color(hex: "#FF6B35"), Color.white.opacity(0.8)
        ]
        return (0..<40).map { _ in
            ParticleData(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...0.6),
                size: CGFloat.random(in: 4...12),
                color: colors.randomElement() ?? AppPalette.mint,
                opacity: Double.random(in: 0.6...1.0)
            )
        }
    }
}

// MARK: - ShareSheet (UIActivityViewController 래퍼)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.excludedActivityTypes = [.addToReadingList, .assignToContact]
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Particle Data

struct ParticleData: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: CGFloat
    var color: Color
    var opacity: Double
}

// MARK: - Preview

#Preview("학습 완료 — XP만") {
    LessonCompleteView(
        result: LessonResult(
            xpEarned: 45,
            isFirstStudyToday: false,
            streakDays: 0,
            sessionLabel: "단어 학습",
            scoreDelta: 0,
            updatedEstimatedScore: 0
        ),
        onDismiss: {}
    )
}

#Preview("학습 완료 — XP + 스트릭 + 점수 상승") {
    LessonCompleteView(
        result: LessonResult(
            xpEarned: 30,
            isFirstStudyToday: true,
            streakDays: 7,
            sessionLabel: "문법 퀴즈",
            scoreDelta: 15,
            updatedEstimatedScore: 215
        ),
        onDismiss: {}
    )
}

#Preview("학습 완료 — 점수 하락") {
    LessonCompleteView(
        result: LessonResult(
            xpEarned: 10,
            isFirstStudyToday: false,
            streakDays: 0,
            sessionLabel: "단어 학습",
            scoreDelta: -5,
            updatedEstimatedScore: 145
        ),
        onDismiss: {}
    )
}
