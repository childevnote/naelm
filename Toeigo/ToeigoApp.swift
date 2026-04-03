//
//  ToeigoApp.swift
//  Toeigo
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

// MARK: - App Entry Point

@main
struct ToeigoApp: App {

    // ── SwiftData ModelContainer ────────────
    // 모든 @Model 클래스를 스키마에 등록합니다.
    // CloudKit 동기화를 위해 isStoredInMemoryOnly = false.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vocabulary.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic   // CloudKit 자동 동기화
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("❌ Could not create ModelContainer: \(error)")
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

    /// Sign in with Apple 성공 시 호출
    func handleSignInSuccess(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        self.userID = credential.user

        // Keychain에 userIdentifier 저장
        KeychainHelper.save(key: KeychainHelper.userIDKey, value: credential.user)

        print("✅ [Auth] Signed in: \(credential.user)")
    }

    /// Sign in 실패 시 호출
    func handleSignInError(_ error: Error) {
        print("❌ [Auth] Sign in failed: \(error.localizedDescription)")
    }

    /// 로그아웃
    func signOut() {
        self.userID = nil

        // Keychain에서 userIdentifier 삭제
        KeychainHelper.delete(key: KeychainHelper.userIDKey)

        print("ℹ️ [Auth] Signed out.")
    }

    /// 앱 재실행 시 기존 인증 상태 복원.
    /// 1) Keychain에서 저장된 userIdentifier를 읽음
    /// 2) Apple 서버에 credential 유효성 확인
    /// 3) 유효하면 자동 로그인, 취소/무효면 로그아웃
    func restoreAuthState() {
        guard let savedUserID = KeychainHelper.read(key: KeychainHelper.userIDKey) else {
            print("ℹ️ [Auth] No saved credentials in Keychain.")
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
                    print("✅ [Auth] Restored session for: \(savedUserID)")

                case .revoked, .notFound:
                    // 사용자가 Apple ID 설정에서 앱 권한을 취소했거나 찾을 수 없음
                    self.userID = nil
                    KeychainHelper.delete(key: KeychainHelper.userIDKey)
                    print("⚠️ [Auth] Credential revoked or not found. Signed out.")

                case .transferred:
                    // 팀 이전 시나리오 (일반적으로 발생하지 않음)
                    print("ℹ️ [Auth] Credential transferred.")

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

    /// 시드 데이터 로딩 완료 여부
    @State private var isDataLoaded = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // ── 인증됨 → 메인 대시보드 ──
                MainDashboardView()
                    .environment(authManager)
            } else {
                // ── 미인증 → 로그인 화면 ──
                SignInView()
                    .environment(authManager)
            }
        }
        .task {
            // 앱 시작 시 한 번만 실행
            if !isDataLoaded {
                // 1) 번들 JSON 시드 데이터 로딩
                DataLoader.seedAllIfNeeded(context: modelContext)
                // 2) 기존 인증 상태 복원 시도
                authManager.restoreAuthState()
                isDataLoaded = true
            }
        }
    }
}


// MARK: - 🍎 Sign In View (로그인 화면)

/// Sign in with Apple 버튼을 표시하는 로그인 화면.
struct SignInView: View {
    @Environment(AuthenticationManager.self) var authManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // ── 앱 로고 / 타이틀 ──
            VStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("Toeigo")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("TOEIC 영단어 · 문법 마스터")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // ── Sign in with Apple 버튼 ──
            SignInWithAppleButton(.signIn) { request in
                // 요청할 정보 범위 설정
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    authManager.handleSignInSuccess(authorization: authorization)
                case .failure(let error):
                    authManager.handleSignInError(error)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .frame(maxWidth: 320)
            .cornerRadius(12)

            // ── 개발 중: 인증 건너뛰기 버튼 ──
            #if DEBUG
            Button("Skip Sign-In (Dev Only)") {
                authManager.userID = "dev_user_debug"
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            #endif

            Spacer()
                .frame(height: 60)
        }
        .padding(.horizontal, 32)
    }
}


// MARK: - 📊 Main Dashboard View (메인 대시보드 — Placeholder)

/// 인증 후 표시되는 메인 학습 대시보드.
/// Week 1에서는 기본 탭 구조와 데이터 확인용 placeholder를 구성합니다.
struct MainDashboardView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            // ── Tab 1: 학습 홈 (대시보드) ──
            DashboardView()
                .environment(authManager)
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }

            // ── Tab 2: 단어 학습 (스와이프 카드) ──
            VocabularyStudyView()
                .environment(authManager)
            .tabItem {
                Label("단어", systemImage: "character.book.closed")
            }

            // ── Tab 3: 문법 퀴즈 ──
            GrammarQuizView()
                .environment(authManager)
            .tabItem {
                Label("문법", systemImage: "text.book.closed")
            }

            // ── Tab 4: 설정 (Placeholder) ──
            NavigationStack {
                List {
                    Section("계정") {
                        if let uid = authManager.userID {
                            Text("User ID: \(uid)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("로그아웃", role: .destructive) {
                            authManager.signOut()
                        }
                    }
                    Section("정보") {
                        Label("버전 1.0.0 (Week 1)", systemImage: "info.circle")
                    }
                }
                .navigationTitle("설정")
            }
            .tabItem {
                Label("설정", systemImage: "gearshape.fill")
            }
        }
    }
}


// MARK: - Previews

#Preview("Root View") {
    RootView()
        .modelContainer(for: [
            Vocabulary.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
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
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
        ], inMemory: true)
}
