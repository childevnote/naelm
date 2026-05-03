//
//  NicknameSetupView.swift
//  Naelm
//
//  공통 닉네임 설정 컴포넌트.
//  온보딩 및 마이페이지에서 재사용됩니다.
//

import SwiftUI
import SwiftData

// MARK: - NicknameSetupView

/// 닉네임 설정 UI 컴포넌트.
/// 온보딩 마지막 단계 및 마이페이지 친구 탭 진입 시 사용됩니다.
struct NicknameSetupView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// 닉네임 저장 완료 콜백 (nil이면 나중에 설정 선택)
    var onComplete: (String?) -> Void

    @State private var nickname: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    /// 유효성 검사: 2~10자, 공백 불포함
    private var isValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 10 && !trimmed.contains(" ")
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 아이콘
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(BrandTheme.accent)

            // 타이틀
            VStack(spacing: 8) {
                Text("닉네임을 설정해주세요")
                    .font(.pretendardBold(22))
                    .multilineTextAlignment(.center)

                Text("친구들에게 보여질 이름이에요")
                    .font(.pretendardMedium(15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 입력 필드
            VStack(alignment: .leading, spacing: 8) {
                TextField("2~10자 한글/영문/숫자", text: $nickname)
                    .font(.pretendardMedium(17))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isValid ? BrandTheme.accent : Color.clear, lineWidth: 2)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: nickname) { _, newValue in
                        // 공백 실시간 제거
                        if newValue.contains(" ") {
                            nickname = newValue.replacingOccurrences(of: " ", with: "")
                        }
                        // 10자 초과 방지
                        if nickname.count > 10 {
                            nickname = String(nickname.prefix(10))
                        }
                        errorMessage = nil
                    }

                // 글자 수 표시
                HStack {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Text("\(nickname.count)/10")
                        .font(.caption)
                        .foregroundStyle(nickname.count > 10 ? .red : .secondary)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // 버튼 영역
            VStack(spacing: 12) {
                // 완료 버튼
                Button {
                    saveNickname()
                } label: {
                    ZStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("완료")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent)
                .disabled(!isValid || isSaving)

                // 나중에 설정 버튼
                Button {
                    onComplete(nil)
                } label: {
                    Text("나중에 설정")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 닉네임 저장

    @MainActor
    private func saveNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            errorMessage = "2자 이상 입력해주세요"
            return
        }

        isSaving = true
        errorMessage = nil

        guard let userID = authManager.userID else {
            isSaving = false
            return
        }

        // UserProfile에 닉네임 저장 (없으면 생성)
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        let existingProfile = try? modelContext.fetch(descriptor).first
        let profile: UserProfile
        if let existingProfile {
            profile = existingProfile
        } else {
            let newProfile = UserProfile(userID: userID)
            modelContext.insert(newProfile)
            profile = newProfile
        }
        profile.nickname = trimmed
        profile.isPublicProfileRegistered = true
        try? modelContext.save()

        // 저장 완료 UI는 즉시 닫고, CloudKit 동기화는 백그라운드에서 처리
        isSaving = false
        onComplete(trimmed)

        guard !userID.hasPrefix("guest_") else { return }
        Task {
            try? await FriendService.shared.upsertPublicProfile(
                userID: userID,
                nickname: trimmed,
                monthlyXP: 0,
                totalXP: 0,
                streak: 0
            )
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var auth = AuthenticationManager()
    NicknameSetupView { _ in }
        .environment(auth)
        .preferredColorScheme(.light)
}
