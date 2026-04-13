//
//  NaelmApp.swift
//  Naelm
//
//  Created by 김동진 on 4/3/26.
//
//  앱의 @main 진입점.
//  ──────────────────────────────────────────────
//  역할:
//    1. SwiftData ModelContainer 설정 (모든 모델 등록)
//    2. 앱 실행 시 번들 JSON 시드 데이터 로딩
//    3. 인증 상태에 따른 루트 뷰 분기
//       - 미인증 → Sign in with Apple 화면
//       - 인증됨 → 메인 학습 대시보드
//  ──────────────────────────────────────────────

import SwiftUI
import SwiftData
import AuthenticationServices
import AppTrackingTransparency
import os

// MARK: - App Entry Point

@main
struct NaelmApp: App {

    // ── Pretendard 기본 폰트 적용 ────────────
    init() {
        applyPretendardFonts()
    }

    // ── SwiftData ModelContainer ────────────
    // 모든 @Model 클래스를 스키마에 등록합니다.
    // CloudKit 동기화를 위해 isStoredInMemoryOnly = false.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vocabulary.self,
            VocabularyMeaning.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
            UserProfile.self,
            MonthlyScore.self,
            Friendship.self,
            BookmarkedWord.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic   // CloudKit 자동 동기화
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // CloudKit/Persistent 실패 시 인메모리 폴백 (앱 크래시 방지)
            AppLogger.data.error("Could not create ModelContainer: \(error.localizedDescription). Falling back to in-memory store.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("❌ In-memory ModelContainer also failed: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}


// MARK: - 🔐 Authentication State (인증 상태 관리)

/// Sign in with Apple 인증 상태를 관리하는 Observable 클래스.
/// Keychain에 userIdentifier를 저장하여 앱 재실행 시 자동 복원합니다.
@MainActor
@Observable
final class AuthenticationManager {

    /// 현재 인증된 사용자의 Apple userIdentifier.
    /// nil이면 미인증 상태.
    var userID: String? = nil

    /// 인증 여부 편의 프로퍼티
    var isAuthenticated: Bool { userID != nil }

    /// 온보딩 재진행 플래그 (마이페이지 초기화 시 true)
    var needsOnboarding: Bool = false

    /// Sign in with Apple 성공 시 호출
    func handleSignInSuccess(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        self.userID = credential.user

        // Keychain에 userIdentifier 저장
        KeychainHelper.save(key: KeychainHelper.userIDKey, value: credential.user)
        AppLogger.auth.info("Signed in successfully")
    }

    /// Sign in 실패 시 호출
    func handleSignInError(_ error: Error) {
        AppLogger.auth.error("Sign in failed: \(error.localizedDescription)")
    }

    /// 로그아웃
    func signOut() {
        self.userID = nil

        // Keychain에서 userIdentifier 삭제
        KeychainHelper.delete(key: KeychainHelper.userIDKey)
        AppLogger.auth.info("Signed out")
    }

    /// 게스트 로그인 — ID를 Keychain에 저장하여 재실행 시 복원
    func signInAsGuest(guestID: String) {
        self.userID = guestID
        KeychainHelper.save(key: KeychainHelper.userIDKey, value: guestID)
        AppLogger.auth.info("Signed in as guest")
    }

    /// 앱 재실행 시 기존 인증 상태 복원.
    /// 1) Keychain에서 저장된 userIdentifier를 읽음
    /// 2) Apple 서버에 credential 유효성 확인
    /// 3) 유효하면 자동 로그인, 취소/무효면 로그아웃
    func restoreAuthState() {
        guard let savedUserID = KeychainHelper.read(key: KeychainHelper.userIDKey) else {
            AppLogger.auth.info("No saved credentials in Keychain")
            return
        }

        // 게스트 ID는 Apple 서버 체크 없이 바로 복원
        if savedUserID.hasPrefix("guest_") || savedUserID.hasPrefix("dev_user_") {
            self.userID = savedUserID
            AppLogger.auth.info("Restored guest session")
            return
        }

        // Apple 서버에 credential 상태 확인
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: savedUserID) { state, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .authorized:
                    // 유효한 credential → 자동 로그인
                    self.userID = savedUserID
                    AppLogger.auth.info("Restored session")

                case .revoked, .notFound:
                    // 사용자가 Apple ID 설정에서 앱 권한을 취소했거나 찾을 수 없음
                    self.userID = nil
                    KeychainHelper.delete(key: KeychainHelper.userIDKey)
                    AppLogger.auth.warning("Credential revoked or not found. Signed out.")

                case .transferred:
                    // 팀 이전 시나리오 (일반적으로 발생하지 않음)
                    AppLogger.auth.info("Credential transferred")

                @unknown default:
                    break
                }
            }
        }
    }
}


// MARK: - 🏠 Root View (루트 뷰 — 인증 분기)

/// 인증 상태에 따라 로그인 화면 또는 메인 대시보드를 표시합니다.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authManager = AuthenticationManager()
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    /// 시드 데이터 로딩 완료 여부
    @State private var isDataLoaded = false
    /// 스플래시 화면 표시 여부 (처음 실행 시만)
    @State private var showSplash = true
    /// 데이터 로드 실패 알림
    @State private var showDataLoadError = false

    private var colorSchemeOverride: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil  // 시스템 설정 따름
        }
    }

    var body: some View {
        ZStack {
            // 메인 앱 컨텐츠
            Group {
                if authManager.isAuthenticated {
                    if authManager.needsOnboarding {
                        OnboardingView(onComplete: {
                            authManager.needsOnboarding = false
                        })
                        .environment(authManager)
                    } else {
                        MainDashboardView()
                            .environment(authManager)
                    }
                } else {
                    SignInView()
                        .environment(authManager)
                }
            }
            .opacity(showSplash ? 0 : 1)

            // 스플래시 오버레이
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .preferredColorScheme(colorSchemeOverride)
        .task {
            if !isDataLoaded {
                let success = DataLoader.seedAllIfNeeded(context: modelContext)
                if !success {
                    showDataLoadError = true
                }
                authManager.restoreAuthState()
                isDataLoaded = true
                // ATT 권한 요청 (스플래시 종료 후 약간의 딜레이)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    ATTrackingManager.requestTrackingAuthorization { _ in }
                }
            }
        }
        .alert("데이터 로드 오류", isPresented: $showDataLoadError) {
            Button("재시도") {
                let retrySuccess = DataLoader.seedAllIfNeeded(context: modelContext)
                if !retrySuccess {
                    showDataLoadError = true
                }
            }
            Button("계속하기", role: .cancel) {}
        } message: {
            Text("학습 데이터를 불러오는 데 실패했습니다. 일부 기능이 정상적으로 작동하지 않을 수 있습니다.")
        }
        .onChange(of: authManager.userID) { _, newID in
            if let uid = newID {
                authManager.needsOnboarding = !isOnboardingComplete(userID: uid)
            }
        }
    }

    private func isOnboardingComplete(userID: String) -> Bool {
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first?.hasCompletedOnboarding) ?? false
    }
}


// MARK: - 🍎 Sign In View (로그인 화면)

/// Sign in with Apple 버튼을 표시하는 로그인 화면.
struct SignInView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSigningIn = false
    @State private var signInError: String? = nil

    var body: some View {
        ZStack {
            // 배경 그라디언트
            AppGradient.background(scheme: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // ── 앱 로고 / 타이틀 ──
                VStack(spacing: 16) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(AppPalette.forest)
                        .shadow(color: AppPalette.forest.opacity(0.3), radius: 10, y: 4)

                    Text("Naelm")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.forest)

                    Text("TOEIC 영단어 · 문법 마스터")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    // ── Sign in with Apple 버튼 ──
                    SignInWithAppleButton(.signIn) { request in
                        isSigningIn = true
                        signInError = nil
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        isSigningIn = false
                        switch result {
                        case .success(let authorization):
                            authManager.handleSignInSuccess(authorization: authorization)
                        case .failure(let error):
                            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                                signInError = nil
                            } else {
                                signInError = error.localizedDescription
                            }
                            authManager.handleSignInError(error)
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .frame(maxWidth: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                    if isSigningIn {
                        ProgressView()
                            .tint(AppPalette.forest)
                    }

                    if let error = signInError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // ── 게스트로 시작 버튼 ──
                    Button {
                        let guestID = "guest_\(UUID().uuidString.prefix(8))"
                        authManager.signInAsGuest(guestID: guestID)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person")
                            Text("게스트로 시작")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(BrandTheme.accent)
                        .frame(maxWidth: 320)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BrandTheme.accent.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                    .padding(.top, 4)
                }

                // ── 개발/시뮬레이터용: 인증 건너뛰기 ──
                #if DEBUG
                Button {
                    authManager.signInAsGuest(guestID: "dev_user_debug")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("테스트 모드로 시작")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 320)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppGradient.primaryButton(scheme: colorScheme))
                    )
                }
                .padding(.top, 4)
                #endif

                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 32)
        }
    }
}


// MARK: - 📊 Main Dashboard View (메인 대시보드 — Placeholder)

/// 인증 후 표시되는 메인 학습 대시보드.
/// Week 1에서는 기본 탭 구조와 데이터 확인용 placeholder를 구성합니다.
struct MainDashboardView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: 학습 홈 ──
            DashboardView()
                .environment(authManager)
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }
            .tag(0)

            // ── Tab 2: 순위 ──
            RankingView()
                .environment(authManager)
            .tabItem {
                Label("순위", systemImage: "chart.bar.fill")
            }
            .tag(1)

            // ── Tab 3: 저장 ──
            BookmarkListView()
                .environment(authManager)
            .tabItem {
                Label("저장", systemImage: "star.fill")
            }
            .tag(2)

            // ── Tab 4: 마이페이지 ──
            MyPageView()
                .environment(authManager)
            .tabItem {
                Label("마이", systemImage: "person.fill")
            }
            .tag(3)
        }
        .tint(AppPalette.forest)
    }
}


// MARK: - Previews

#Preview("Root View") {
    RootView()
        .modelContainer(for: [
            Vocabulary.self,
            VocabularyMeaning.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
            UserProfile.self,
            MonthlyScore.self,
            Friendship.self,
            BookmarkedWord.self,
        ], inMemory: true)
}

#Preview("Sign In") {
    SignInView()
        .environment(AuthenticationManager())
}

#Preview("Dashboard") {
    MainDashboardView()
        .environment(AuthenticationManager())
        .modelContainer(for: [
            Vocabulary.self,
            VocabularyMeaning.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
            UserProfile.self,
            MonthlyScore.self,
            Friendship.self,
            BookmarkedWord.self,
        ], inMemory: true)
}

