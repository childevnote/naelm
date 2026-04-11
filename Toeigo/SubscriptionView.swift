//
//  SubscriptionView.swift
//  Toeigo
//
//  Pro 구독 결제 화면 — 월간 5,900원 / 연간 2,900원×12
//

import SwiftUI
import SwiftData

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var isProcessing = false
    @State private var showSuccess = false

    // 애니메이션 상태
    @State private var shimmerOffset: CGFloat = -300
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var floatOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.4

    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "monthly"
        case annual  = "annual"

        var title: String {
            switch self {
            case .monthly: return "월간 구독"
            case .annual:  return "연간 구독"
            }
        }

        var pricePerMonth: Int {
            switch self {
            case .monthly: return 5900
            case .annual:  return 2900
            }
        }

        var totalPrice: Int {
            switch self {
            case .monthly: return 5900
            case .annual:  return 34800   // 2,900원 × 12
            }
        }

        var badge: String? {
            switch self {
            case .monthly: return nil
            case .annual:  return "51% 절약"
            }
        }
    }

    var body: some View {
        ZStack {
            // ── 배경 ──
            backgroundLayer

            if showSuccess {
                successView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                        benefitsSection
                        planPickerSection
                        ctaSection
                        footnote
                    }
                }
            }
        }
        .navigationTitle("Pro 구독")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("닫기") { dismiss() }
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            // 기본 그라디언트
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.04, green: 0.08, blue: 0.06), Color(red: 0.02, green: 0.04, blue: 0.03)]
                    : [Color(red: 0.93, green: 0.97, blue: 0.95), Color(red: 0.87, green: 0.96, blue: 0.91)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 회전하는 장식 원들
            Circle()
                .fill(BrandTheme.accent.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: -120, y: -200)
                .rotationEffect(.degrees(rotationAngle))

            Circle()
                .fill(BrandTheme.accentLight.opacity(0.04))
                .frame(width: 200, height: 200)
                .offset(x: 140, y: 100)
                .rotationEffect(.degrees(-rotationAngle * 0.7))

            // 빛나는 선들
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(BrandTheme.knewIt.opacity(0.03 + Double(i) * 0.01))
                    .frame(width: 400, height: 1)
                    .offset(y: CGFloat(i) * 80 - 200)
                    .rotationEffect(.degrees(30))
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)

            // 왕관 아이콘 + 빛 효과
            ZStack {
                // 빛나는 후광
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [BrandTheme.studyIt.opacity(glowOpacity), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                // 배경 원
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BrandTheme.accent, BrandTheme.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: BrandTheme.accent.opacity(0.4), radius: 20, y: 8)
                    .scaleEffect(pulseScale)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .offset(y: floatOffset)
                    .shadow(color: .white.opacity(0.5), radius: 4)
            }
            .frame(height: 180)

            // PRO 뱃지
            HStack(spacing: 6) {
                Text("TOEIGO")
                    .fontWeight(.heavy)
                    .foregroundStyle(BrandTheme.accent)
                Text("PRO")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [BrandTheme.studyIt, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .font(.title2)

            // 슬로건
            VStack(spacing: 8) {
                Text("지금 바로 한계를 돌파하세요")
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("하루 단 10분, 목표 점수 달성의 지름길")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // 스크롤 유도 스파크
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(BrandTheme.studyIt)
                        .opacity(Double(i) * 0.15 + 0.25)
                }
            }
        }
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pro 혜택")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            VStack(spacing: 10) {
                benefitRow(
                    icon: "infinity",
                    color: BrandTheme.accent,
                    title: "무제한 학습",
                    detail: "단어·문법 일일 제한 없이 원하는 만큼"
                )
                benefitRow(
                    icon: "timer",
                    color: .orange,
                    title: "시간 제한 제어",
                    detail: "나만의 학습 속도에 맞게 타이머 설정"
                )
                benefitRow(
                    icon: "star.fill",
                    color: BrandTheme.studyIt,
                    title: "단어 저장",
                    detail: "중요한 단어를 저장하고 언제든 복습"
                )
                benefitRow(
                    icon: "chart.bar.fill",
                    color: .purple,
                    title: "상세 분석",
                    detail: "유형별 성취도와 학습 패턴 분석"
                )
                benefitRow(
                    icon: "bolt.fill",
                    color: .yellow,
                    title: "빠른 업데이트",
                    detail: "신규 단어·문법 콘텐츠 최우선 제공"
                )
            }
            .padding(.horizontal, 24)
        }
    }

    private func benefitRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(BrandTheme.knewIt)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Plan Picker

    private var planPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("플랜 선택")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            VStack(spacing: 10) {
                ForEach(SubscriptionPlan.allCases, id: \.rawValue) { plan in
                    planCard(plan: plan)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func planCard(plan: SubscriptionPlan) -> some View {
        let isSelected = selectedPlan == plan

        return Button { selectedPlan = plan } label: {
            HStack(spacing: 14) {
                // 선택 라디오
                ZStack {
                    Circle()
                        .stroke(isSelected ? BrandTheme.accent : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(BrandTheme.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                // 플랜 정보
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(.subheadline).fontWeight(.semibold)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                    }
                    if plan == .annual {
                        Text("3만 4,800원/년 청구")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 가격
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(plan == .monthly ? "5,900" : "2,900")원")
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(isSelected ? BrandTheme.accent : .primary)
                    Text("/월")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? BrandTheme.accent.opacity(0.06) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? BrandTheme.accent : .clear, lineWidth: 2)
                    )
            )
            .overlay(
                // 시머 효과 (선택된 카드)
                isSelected ? shimmerOverlay : nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.12), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 80)
        .offset(x: shimmerOffset)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 14) {
            // 구독 버튼
            Button {
                purchasePlan()
            } label: {
                ZStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                            Text("\(selectedPlan.title) 시작하기")
                                .fontWeight(.bold)
                        }
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [BrandTheme.accent, BrandTheme.accentLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: BrandTheme.accent.opacity(0.35), radius: 12, y: 6)
                .scaleEffect(isProcessing ? 0.97 : 1.0)
            }
            .disabled(isProcessing)
            .animation(.spring(response: 0.3), value: isProcessing)
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // 복원 버튼 (실제 앱: StoreKit Transaction.currentEntitlements 검증)
            Button("구매 내역 복원") {
                // TODO: StoreKit 2 기반 구매 복원 구현 필요
            }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        VStack(spacing: 6) {
            Text("구독은 iTunes 계정으로 청구됩니다. 구독은 현재 기간이 종료되기 최소 24시간 전에 취소하지 않으면 자동으로 갱신됩니다.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                // TODO: 실제 URL로 교체 필요 (App Store 심사 요구사항)
                Button("이용약관") {}
                Text("·").foregroundStyle(.tertiary)
                Button("개인정보 처리방침") {}
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(BrandTheme.knewIt.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(BrandTheme.knewIt)
                    .symbolEffect(.bounce)
            }

            VStack(spacing: 10) {
                Text("구독 완료! 🎉")
                    .font(.title).fontWeight(.bold)
                Text("이제 \(selectedPlan.title) Pro 멤버입니다.\n제한 없이 학습을 시작해보세요!")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("학습 시작하기")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [BrandTheme.accent, BrandTheme.accentLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func purchasePlan() {
        guard let userID = authManager.userID else { return }
        isProcessing = true

        // 실제 앱: StoreKit 결제 처리
        // 데모/시뮬레이터: 즉시 Pro 활성화
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            activatePro(userID: userID)
            isProcessing = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showSuccess = true
            }
        }
    }

    private func activatePro(userID: String) {
        // NOTE: 실제 앱에서는 StoreKit 2의 Transaction.currentEntitlements로
        // 영수증을 검증한 후에만 isPro를 true로 설정해야 합니다.
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first else { return }
        profile.isPro = true
        profile.subscriptionPlan = selectedPlan.rawValue
        let cal = Calendar.current
        profile.proExpiresAt = selectedPlan == .monthly
            ? cal.date(byAdding: .month, value: 1, to: Date())
            : cal.date(byAdding: .year, value: 1, to: Date())
        try? modelContext.save()
    }

    // MARK: - Animations

    private func startAnimations() {
        // 시머 루프
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            shimmerOffset = 400
        }
        // 맥박 루프
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }
        // 왕관 떠다니기
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            floatOffset = -8
        }
        // 빛 깜박임
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            glowOpacity = 0.75
        }
        // 배경 회전
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}


// MARK: - Pro Badge View (단어 학습 화면용 미니 뱃지)

struct ProBadgeView: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [BrandTheme.studyIt, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }
}


// MARK: - Subscription Gate View (저장 탭 접근 제한)

struct SubscriptionGateView: View {
    @State private var showSubscription = false
    @State private var pulseScale: CGFloat = 1.0
    @Environment(AuthenticationManager.self) var authManager

    var body: some View {
        ZStack {
            // 블러 배경 힌트
            VStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 60)
                }
            }
            .padding(.horizontal, 24)
            .blur(radius: 8)

            // 게이트 카드
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(BrandTheme.studyIt.opacity(0.15))
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseScale)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(BrandTheme.studyIt)
                }

                VStack(spacing: 8) {
                    Text("Pro 전용 기능")
                        .font(.title3).fontWeight(.bold)
                    Text("단어 저장 기능은 Pro 구독이\n필요합니다.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showSubscription = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("Pro 구독하기")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [BrandTheme.accent, BrandTheme.accentLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: BrandTheme.accent.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
            )
            .padding(.horizontal, 32)
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView()
                    .environment(authManager)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}
