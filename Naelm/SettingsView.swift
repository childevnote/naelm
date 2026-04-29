//
//  SettingsView.swift
//  Naelm
//
//  앱 설정 페이지
//

import SwiftUI
import SwiftData
import AuthenticationServices
import os

struct SettingsView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @State private var showFeedback: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showDeleteAccountConfirmation: Bool = false
    @State private var showAppleRevokeGuide: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 화면 모드
                    settingsCard {
                        HStack {
                            Label("화면 모드", systemImage: "circle.lefthalf.filled")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $appearanceMode) {
                                Text("시스템").tag(0)
                                Text("라이트").tag(1)
                                Text("다크").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                    }

                    // 도움/피드백
                    settingsCard {
                        VStack(spacing: 0) {
                            Button { showFeedback = true } label: {
                                HStack {
                                    Label("개선사항 보내기", systemImage: "envelope")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }.font(.subheadline)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }

                    // 계정
                    settingsCard {
                        VStack(spacing: 0) {
                            Button { showResetAlert = true } label: {
                                HStack {
                                    Label("전체 초기화", systemImage: "arrow.counterclockwise")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }.font(.subheadline)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)

                            Divider()

                            Button { showDeleteAccountAlert = true } label: {
                                HStack {
                                    Label("계정 삭제", systemImage: "person.crop.circle.badge.minus")
                                        .foregroundStyle(.red)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }.font(.subheadline)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)

                            Divider()

                            Button("로그아웃", role: .destructive) {
                                authManager.signOut()
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }

                    // 법적 / 버전
                    settingsCard {
                        VStack(spacing: 0) {
                            if let policyURL = URL(string: "https://lively-mayonnaise-192.notion.site/naelm") {
                                Link(destination: policyURL) {
                                    HStack {
                                        Label("개인정보 처리방침 및 이용약관", systemImage: "doc.text")
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square").foregroundStyle(.tertiary)
                                    }.font(.subheadline)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)

                                Divider()
                            }

                            Text("버전 1.0.0")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .alert("전체 초기화", isPresented: $showResetAlert) {
                Button("초기화", role: .destructive) { resetOnboarding() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 학습 데이터가 삭제되고 처음 상태로 돌아갑니다.")
            }
            .alert("계정 삭제", isPresented: $showDeleteAccountAlert) {
                Button("삭제하기", role: .destructive) { showDeleteAccountConfirmation = true }
                Button("취소", role: .cancel) {}
            } message: {
                Text("계정을 삭제하면 모든 학습 데이터와 저장된 단어가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("정말 삭제하시겠습니까?", isPresented: $showDeleteAccountConfirmation) {
                Button("영구 삭제", role: .destructive) {
                    let isAppleUser = !(authManager.userID?.hasPrefix("guest_") ?? true)
                    deleteAccount()
                    if isAppleUser {
                        showAppleRevokeGuide = true
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("마지막 확인입니다. 계정 삭제 후에는 데이터를 복구할 수 없습니다.")
            }
            .alert("Apple ID 연동 해제 안내", isPresented: $showAppleRevokeGuide) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("나중에", role: .cancel) {}
            } message: {
                Text("앱 계정이 삭제되었습니다.\n\nApple ID 연동을 완전히 해제하려면 iPhone 설정 > [내 이름] > 암호 및 보안 > Apple로 로그인한 앱 에서 'Naelm'을 선택하고 'Apple ID 사용 중단'을 탭하세요.")
            }
        }
    }

    // MARK: - Card Helper

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 24).fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.06), AppPalette.leaf.opacity(0.03), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    RoundedRectangle(cornerRadius: 24).stroke(
                        LinearGradient(
                            colors: [AppPalette.leaf.opacity(0.4), AppPalette.forest.opacity(0.15), AppPalette.leaf.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
            )
    }

    // MARK: - Actions

    private func resetOnboarding() {
        guard let userID = authManager.userID else { return }
        let vm = MyPageViewModel(modelContext: modelContext, authManager: authManager)
        vm.resetOnboarding()
    }

    private func deleteAccount() {
        let vm = MyPageViewModel(modelContext: modelContext, authManager: authManager)
        vm.deleteAccount()
    }
}

#Preview {
    SettingsView()
}
