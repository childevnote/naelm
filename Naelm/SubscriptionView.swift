//
//  SubscriptionView.swift
//  Naelm
//
//  Pro 구독 결제 화면 — 월간 5,900원 / 연간 2,900원×12
//

import SwiftUI
import SwiftData
import os

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
    // 배경 원 이동 애니메이션
    @State private var circle1Offset: CGSize = .zero
    @State private var circle2Offset: CGSize = .zero
    @State private var circle3Scale: CGFloat = 1.0
    @State private var circle3Opacity: Double = 0.03

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

            // 큰 원 — 천천히 부유 + 회전
            Circle()
                .fill(BrandTheme.accent.opacity(0.07))
                .frame(width: 320, height: 320)
                .offset(x: -120 + circle1Offset.width, y: -200 + circle1Offset.height)
                .rotationEffect(.degrees(rotationAngle))
                .blur(radius: 2)

            // 중간 원 — 반대 방향 부유 + 반대 회전
            Circle()
                .fill(BrandTheme.accentLight.opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: 140 + circle2Offset.width, y: 100 + circle2Offset.height)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
                .blur(radius: 1)

            // 작은 장식 원 — 크기 박동 + 느린 부유
            Circle()
                .fill(BrandTheme.knewIt.opacity(circle3Opacity))
                .frame(width: 160, height: 160)
                .scaleEffect(circle3Scale)
                .offset(x: 60 + circle2Offset.width * 0.5, y: -80 + circle1Offset.height * 0.6)
                .blur(radius: 4)

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

    // MARK: - Benefits (Free vs Pro 비교 표)

    private struct BenefitItem {
        let icon: String
        let iconColor: Color
        let title: String
        let freeAvailable: Bool
        let proAvailable: Bool
    }

    private var benefitItems: [BenefitItem] {
        [
            BenefitItem(icon: "book.fill",         iconColor: BrandTheme.accent,   title: "단어 학습",        freeAvailable: true,  proAvailable: true),
            BenefitItem(icon: "text.book.closed",  iconColor: BrandTheme.accent,   title: "문법 퀴즈",        freeAvailable: true,  proAvailable: true),
            BenefitItem(icon: "infinity",          iconColor: .cyan,               title: "무제한 학습",      freeAvailable: false, proAvailable: true),
            BenefitItem(icon: "star.fill",         iconColor: BrandTheme.studyIt,  title: "단어 저장",        freeAvailable: false, proAvailable: true),
            BenefitItem(icon: "timer",             iconColor: .orange,             title: "타이머 설정",      freeAvailable: false, proAvailable: true),
            BenefitItem(icon: "chart.bar.fill",    iconColor: .purple,             title: "유형별 성취도 분석", freeAvailable: false, proAvailable: true),
        ]
    }

    private var benefitsSection: some View {
        VStack(spacing: 12) {
            Text("플랜 비교")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            // 표 컨테이너
            VStack(spacing: 0) {
                // 헤더 행
                HStack(spacing: 0) {
                    Text("기능")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)

                    Text("Free")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .center)

                    Text("Pro")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(BrandTheme.accent)
                        .frame(width: 56, alignment: .center)
                        .padding(.trailing, 8)
                }
                .frame(height: 36)
                .background(Color(.secondarySystemBackground).opacity(0.6))

                Divider()

                // 데이터 행
                ForEach(Array(benefitItems.enumerated()), id: \.offset) { idx, item in
                    VStack(spacing: 0) {
                        benefitTableRow(item: item, isOdd: idx % 2 == 1)
                        if idx < benefitItems.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private func benefitTableRow(item: BenefitItem, isOdd: Bool) -> some View {
        HStack(spacing: 0) {
            // 아이콘 + 기능명
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.iconColor.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: item.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(item.iconColor)
                }
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            // Free 열
            availabilityMark(available: item.freeAvailable, isPro: false)
                .frame(width: 56, alignment: .center)

            // Pro 열
            availabilityMark(available: item.proAvailable, isPro: true)
                .frame(width: 56, alignment: .center)
                .padding(.trailing, 8)
        }
        .frame(height: 52)
        .background(isOdd ? Color(.secondarySystemBackground).opacity(0.35) : Color.clear)
    }

    @ViewBuilder
    private func availabilityMark(available: Bool, isPro: Bool) -> some View {
        if available {
            ZStack {
                Circle()
                    .fill((isPro ? BrandTheme.accent : BrandTheme.knewIt).opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isPro ? BrandTheme.accent : BrandTheme.knewIt)
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.red.opacity(0.5))
            }
        }
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

            if let error = activationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }
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
                Button("이용약관") { showTermsAlert = true }
                Text("·").foregroundStyle(.tertiary)
                Button("개인정보 처리방침") { showPrivacyAlert = true }
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .alert("이용약관", isPresented: $showTermsAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("이용약관은 현재 준비 중입니다.\n정식 출시 시 제공될 예정입니다.")
            }
            .alert("개인정보 처리방침", isPresented: $showPrivacyAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("개인정보 처리방침은 현재 준비 중입니다.\n정식 출시 시 제공될 예정입니다.")
            }
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

    @State private var activationError: String? = nil
    @State private var showTermsAlert = false
    @State private var showPrivacyAlert = false

    private func purchasePlan() {
        guard let userID = authManager.userID else { return }
        isProcessing = true
        activationError = nil

        // 실제 앱: StoreKit 결제 처리
        // 데모/시뮬레이터: 즉시 Pro 활성화
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let success = activatePro(userID: userID)
            isProcessing = false
            if success {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSuccess = true
                }
            } else {
                activationError = "구독 활성화에 실패했습니다. 다시 시도해주세요."
            }
        }
    }

    /// Pro 활성화 — 성공 여부를 반환합니다.
    @discardableResult
    private func activatePro(userID: String) -> Bool {
        // NOTE: 실제 앱에서는 StoreKit 2의 Transaction.currentEntitlements로
        // 영수증을 검증한 후에만 isPro를 true로 설정해야 합니다.
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first else {
            AppLogger.auth.error("Pro activation failed: UserProfile not found for \(userID)")
            return false
        }
        profile.isPro = true
        profile.subscriptionPlan = selectedPlan.rawValue
        let cal = Calendar.current
        profile.proExpiresAt = selectedPlan == .monthly
            ? cal.date(byAdding: .month, value: 1, to: Date())
            : cal.date(byAdding: .year, value: 1, to: Date())
        do {
            try modelContext.save()
            return true
        } catch {
            AppLogger.auth.error("Pro activation save failed: \(error.localizedDescription)")
            profile.isPro = false
            return false
        }
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
        // 큰 원 부유 — 느리게 대각선 이동
        withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
            circle1Offset = CGSize(width: 40, height: 30)
        }
        // 중간 원 부유 — 반대 방향, 다른 속도
        withAnimation(.easeInOut(duration: 9.0).repeatForever(autoreverses: true)) {
            circle2Offset = CGSize(width: -35, height: -25)
        }
        // 작은 원 크기 박동
        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
            circle3Scale = 1.25
        }
        // 작은 원 투명도 변화
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            circle3Opacity = 0.07
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
    /// sheet dismiss 시 호출 — 부모 뷰에서 isPro 재로드용
    var onSubscriptionDismiss: (() -> Void)? = nil

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
        .sheet(isPresented: $showSubscription, onDismiss: {
                onSubscriptionDismiss?()
            }) {
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
