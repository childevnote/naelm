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
import UserNotifications
import CloudKit
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
            cloudKitDatabase: .none
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
                // ARCH FIX: fatalError acceptable here — app is non-functional without any storage
            fatalError("❌ In-memory ModelContainer also failed: \(error.localizedDescription)\nUnderlying: \(error)")
            }
        }
    }()

    @Environment(\.scenePhase) private var scenePhase
    @State private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                guard let uid = authManager.userID else {
                    print("[AutoBackup] userID nil, 백업 스킵")
                    return
                }
                print("[AutoBackup] 앱 백그라운드 진입, 자동 백업 시도 (userID: \(uid))")
                Task {
                    do {
                        _ = try await ICloudProgressBackupService.shared.backupProgress(userID: uid, context: sharedModelContainer.mainContext)
                        print("[AutoBackup] 백업 성공")
                    } catch {
                        print("[AutoBackup] 백업 실패: \(error)")
                    }
                }
            }
        }
    }
}


// MARK: - 🔐 Authentication State (인증 상태 관리)

/// Sign in with Apple 인증 상태를 관리하는 Observable 클래스.
/// Keychain에 userIdentifier를 저장하여 앱 재실행 시 자동 복원합니다.
@MainActor
@Observable
final class AuthenticationManager {

    private static let guestIDDefaultsKey = "naelm.guest_id"

    /// 현재 인증된 사용자의 Apple userIdentifier.
    /// nil이면 미인증 상태.
    var userID: String? = nil

    /// 인증 여부 편의 프로퍼티
    var isAuthenticated: Bool { userID != nil }

    /// 온보딩 재진행 플래그 (마이페이지 초기화 시 true)
    var needsOnboarding: Bool = false

    /// 애플 로그인 최초 시 제공되는 실명 (최초 1회만 제공됨)
    var pendingAppleName: String? = nil

    /// 게스트 로그인 시 입력한 이름
    var pendingGuestName: String? = nil

    /// Sign in with Apple 성공 시 호출
    func handleSignInSuccess(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        let previousUserID = self.userID
        self.userID = credential.user

        if previousUserID?.hasPrefix("guest_") == true {
            UserDefaults.standard.removeObject(forKey: Self.guestIDDefaultsKey)
        }

        // 최초 로그인 시에만 fullName이 제공됨
        if let fullName = credential.fullName {
            let parts = [fullName.familyName, fullName.givenName]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !parts.isEmpty {
                pendingAppleName = parts.joined()
            } else {
                let formatted = PersonNameComponentsFormatter()
                    .string(from: fullName)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !formatted.isEmpty {
                    pendingAppleName = formatted
                }
            }
        }

        // Keychain에 userIdentifier 저장
        KeychainHelper.save(key: KeychainHelper.userIDKey, value: credential.user)

        // authorizationCode를 저장 — 향후 계정 삭제 시 Apple 토큰 취소(revoke)에 사용
        // 이 코드는 최초 Sign In 시에만 발급됩니다
        if let authCodeData = credential.authorizationCode,
           let authCode = String(data: authCodeData, encoding: .utf8) {
            KeychainHelper.save(key: KeychainHelper.authCodeKey, value: authCode)
            AppLogger.auth.info("Authorization code saved for future token revocation")

            Task {
                await AppleTokenServerClient.storeAuthorizationCode(authCode, userID: credential.user)
            }
        }

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
        UserDefaults.standard.set(guestID, forKey: Self.guestIDDefaultsKey)
        AppLogger.auth.info("Signed in as guest")
    }

    /// 이전 게스트 ID가 있으면 재사용하고 없으면 새로 생성합니다.
    func signInAsGuest() {
        if let savedGuestID = UserDefaults.standard.string(forKey: Self.guestIDDefaultsKey) {
            signInAsGuest(guestID: savedGuestID)
            return
        }

        let guestID = "guest_\(UUID().uuidString.prefix(8))"
        signInAsGuest(guestID: guestID)
    }

    /// 이름을 함께 지정해서 게스트 로그인
    func signInAsGuest(name: String) {
        pendingGuestName = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name.trimmingCharacters(in: .whitespaces)
        signInAsGuest()
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
        if savedUserID.hasPrefix("guest_") {
            self.userID = savedUserID
            AppLogger.auth.info("Restored guest session")
            return
        }

        // DEBUG 전용: dev_user_ 접두사 ID는 프로덕션 빌드에서 허용하지 않음
        #if DEBUG
        if savedUserID.hasPrefix("dev_user_") {
            self.userID = savedUserID
            AppLogger.auth.info("Restored dev session (DEBUG only)")
            return
        }
        #endif

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

    @State private var isDataLoaded = false
    @State private var showSplash = true
    @State private var showDataLoadError = false

    private var colorSchemeOverride: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack {
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
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ui-test-force-signout") {
                    authManager.signOut()
                }
                #endif
                isDataLoaded = true
            }
            await NotificationService.shared.requestPermissionIfNeeded()
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
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
        .onChange(of: authManager.userID) { oldID, newID in
            if let oldID,
               let newID,
               oldID.hasPrefix("guest_"),
               !newID.hasPrefix("guest_") {
                GuestDataMigrationService.shared.migrateIfNeeded(from: oldID, to: newID, context: modelContext)
            }
            if let uid = newID {
                authManager.needsOnboarding = !isOnboardingComplete(userID: uid)
                applyPendingNameIfNeeded(userID: uid)
            }
        }
    }

    private func isOnboardingComplete(userID: String) -> Bool {
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        guard let profile = try? modelContext.fetch(descriptor).first else { return false }
        if profile.hasCompletedOnboarding { return true }
        return !profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyPendingNameIfNeeded(userID: String) {
        _ = userID
    }
}


// MARK: - 🍎 Sign In View (로그인 화면)

/// Sign in with Apple 버튼을 표시하는 로그인 화면.
struct SignInView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSigningIn = false
    @State private var signInError: String? = nil
    @State private var showGuestNameSheet = false

    private let userFacingSignInErrorMessage = "로그인 중 문제가 발생했어요. 잠시 후 다시 시도해주세요."

    var body: some View {
        ZStack {
            // 배경 그라디언트 — hero 버전 사용
            AppGradient.hero(scheme: colorScheme)
                .ignoresSafeArea()

            // 상단 장식 blob
            Circle()
                .fill(AppPalette.forest.opacity(colorScheme == .dark ? 0.15 : 0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -200)
                .allowsHitTesting(false)

            Circle()
                .fill(AppPalette.leaf.opacity(colorScheme == .dark ? 0.10 : 0.06))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: 120, y: 100)
                .allowsHitTesting(false)

            VStack(spacing: 32) {
                Spacer()

                // ── 앱 로고 / 타이틀 — 글래스 카드 ──
                VStack(spacing: 18) {
                    ZStack {
                        // 외곽 글로우 링
                        Circle()
                            .fill(AppPalette.mint.opacity(colorScheme == .dark ? 0.15 : 0.20))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)

                        // 앱 아이콘 스타일 (실제 앱 아이콘처럼 둥근 모서리)
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.white)
                            .frame(width: 108, height: 108)
                            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 8)
                            .overlay(
                                Image("AppCharacter")
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            )
                    }

                    Text("Naelm")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppPalette.forest, AppPalette.leaf],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )

                    Text("토익 영단어 · 문법 마스터")
                        .font(.pretendardMedium(16))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 32).padding(.horizontal, 40)
                .glassCard(cornerRadius: 28, scheme: colorScheme)

                Spacer()

                VStack(spacing: 14) {
                    // ── Sign in with Apple 버튼 ──
                    SignInWithAppleButton(.signIn) { request in
                        isSigningIn = true
                        signInError = nil
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        // Task { @MainActor in }으로 감싸서 @State 변경과
                        // @MainActor 인증 메서드 호출을 메인 스레드에서 보장합니다.
                        Task { @MainActor in
                            isSigningIn = false
                            switch result {
                            case .success(let authorization):
                                authManager.handleSignInSuccess(authorization: authorization)
                            case .failure(let error):
                                if shouldSuppressSignInError(for: error) {
                                    // 사용자가 취소했거나 비대화형 상황이면 에러 UI를 숨깁니다.
                                    signInError = nil
                                } else {
                                    // 실제 실패만 사용자 메시지 노출 + 로깅합니다.
                                    signInError = userFacingSignInErrorMessage
                                    authManager.handleSignInError(error)
                                }
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .frame(maxWidth: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .disabled(isSigningIn)

                    if isSigningIn {
                        ProgressView().tint(AppPalette.forest)
                    }

                    if let error = signInError {
                        Text(error)
                            .font(.caption).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // ── 게스트로 시작 버튼 ──
                    Button {
                        showGuestNameSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person")
                            Text("게스트로 시작")
                        }
                        .font(.pretendardMedium(15))
                        .foregroundStyle(AppPalette.forest)
                        .frame(maxWidth: 320)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppPalette.forest.opacity(0.45), lineWidth: 1.5)
                        )
                    }
                    .sheet(isPresented: $showGuestNameSheet) {
                        GuestNameInputView { name in
                            showGuestNameSheet = false
                            if let name {
                                authManager.signInAsGuest(name: name)
                            } else {
                                authManager.signInAsGuest()
                            }
                        }
                        .presentationDetents([.medium])
                    }
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
                    .font(.pretendardSemiBold(15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 320)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppGradient.primaryButton(scheme: colorScheme))
                    )
                    .shadow(color: AppPalette.forest.opacity(0.3), radius: 8, y: 3)
                }
                .padding(.top, 4)
                #endif

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            applyUITestSignInErrorIfNeeded()
        }
    }

    private func shouldSuppressSignInError(for error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain else {
            return false
        }

        return nsError.code == ASAuthorizationError.canceled.rawValue
            || nsError.code == ASAuthorizationError.notInteractive.rawValue
    }

    private func applyUITestSignInErrorIfNeeded() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-test-signin-error-generic") {
            signInError = userFacingSignInErrorMessage
            return
        }
        if arguments.contains("-ui-test-signin-error-canceled") {
            signInError = nil
        }
        #endif
    }
}


// MARK: - 📊 Main Dashboard View (메인 대시보드)

struct MainDashboardView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .environment(authManager)
                    .tabItem { Label("홈", systemImage: "house.fill") }
                    .tag(0)

                RankingView()
                    .environment(authManager)
                    .tabItem { Label("순위", systemImage: "chart.bar.fill") }
                    .tag(1)

                BookmarkListView()
                    .environment(authManager)
                    .tabItem { Label("저장", systemImage: "star.fill") }
                    .tag(2)

                MyPageView()
                    .environment(authManager)
                    .tabItem { Label("마이", systemImage: "person.fill") }
                    .tag(3)
            }
            .tint(AppPalette.forest)
        }
        .task {
            // 앱 실행 시 Public Profile/친구요청 상태 동기화
            guard let userID = authManager.userID,
                  !userID.hasPrefix("guest_") else { return }
            let predicate = #Predicate<UserProfile> { $0.userID == userID }
            let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
            guard let profile = try? modelContext.fetch(descriptor).first,
                  !profile.nickname.isEmpty else {
                AppLogger.friend.warning("[Dashboard.task] 로컬 UserProfile 없음 또는 닉네임 비어있음")
                return
            }
            profile.isPublicProfileRegistered = true
            try? modelContext.save()
            FriendSyncService.shared.syncPublicProfileIfNeeded(userID: userID, context: modelContext)
        }
    }
}

// MARK: - Previews

#Preview("Sign In") {
    @Previewable @State var auth = AuthenticationManager()
    SignInView().environment(auth)
}


// MARK: - Guest Name Input View

/// 게스트 로그인 시 이름을 입력받는 간단한 시트.
struct GuestNameInputView: View {
    /// 완료 콜백. nil이면 이름 없이 게스트 시작.
    var onComplete: (String?) -> Void

    @State private var name: String = ""

    private var isValid: Bool {
        let t = name.trimmingCharacters(in: .whitespaces)
        return t.count >= 2 && t.count <= 10
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "person.crop.circle")
                .font(.system(size: 56))
                .foregroundStyle(AppPalette.forest)

            VStack(spacing: 8) {
                Text("이름을 입력해주세요")
                    .font(.pretendardBold(22))
                Text("앱 내에서 사용할 이름이에요")
                    .font(.pretendardMedium(14))
                    .foregroundStyle(.secondary)
            }

            TextField("2~10자", text: $name)
                .font(.pretendardMedium(17))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isValid ? AppPalette.forest : Color.clear, lineWidth: 2)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: name) { _, newValue in
                    if newValue.count > 10 { name = String(newValue.prefix(10)) }
                }
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onComplete(name.trimmingCharacters(in: .whitespaces))
                } label: {
                    Text("시작하기")
                        .font(.pretendardSemiBold(16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isValid ? AppPalette.forest : AppPalette.forest.opacity(0.4))
                        )
                }
                .disabled(!isValid)

                Button {
                    onComplete(nil)
                } label: {
                    Text("이름 없이 시작")
                        .font(.pretendardMedium(14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }
}
