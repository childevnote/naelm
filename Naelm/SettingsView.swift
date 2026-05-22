//
//  SettingsView.swift
//  Naelm
//
//  앱 설정 페이지
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @State private var showFeedback: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var showWithdrawAlert: Bool = false
    @State private var showWithdrawConfirmation: Bool = false
    @State private var showNicknameEdit: Bool = false
    @State private var isWithdrawing: Bool = false
    @State private var profile: UserProfile? = nil
    @State private var lastICloudBackupDate: Date? = nil
    @State private var isSavingToICloud: Bool = false
    @State private var isRestoringFromICloud: Bool = false
    @State private var showRestoreAlert: Bool = false
    @State private var backupMessage: String? = nil

    // 닉네임 변경 가능 여부 (한 달 1회)
    private var canChangeNickname: Bool {
        guard let changedAt = profile?.nicknameChangedAt else { return true }
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return changedAt < oneMonthAgo
    }

    private var nicknameChangeAvailableDate: Date? {
        guard let changedAt = profile?.nicknameChangedAt else { return nil }
        return Calendar.current.date(byAdding: .month, value: 1, to: changedAt)
    }

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

                    // 닉네임 변경
                    settingsCard {
                        Button {
                            if canChangeNickname {
                                showNicknameEdit = true
                            }
                        } label: {
                            HStack {
                                Label("닉네임 변경", systemImage: "person.crop.circle.badge.pencil")
                                    .font(.subheadline)
                                Spacer()
                                if canChangeNickname {
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                } else if let availDate = nicknameChangeAvailableDate {
                                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: availDate).day ?? 0
                                    Text("\(max(1, daysLeft))일 후 변경 가능")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .disabled(!canChangeNickname)
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

                    // iCloud 백업
                    settingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("iCloud 저장", systemImage: "icloud")
                                    .font(.subheadline)
                                Spacer()
                                Text(lastBackupText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    saveProgressToICloud()
                                } label: {
                                    if isSavingToICloud {
                                        ProgressView().tint(AppPalette.forest)
                                    } else {
                                        Text("지금 저장")
                                            .font(.pretendardSemiBold(13))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(AppPalette.forest))
                                    }
                                }
                                .disabled(isSavingToICloud || isRestoringFromICloud)

                                Button {
                                    showRestoreAlert = true
                                } label: {
                                    if isRestoringFromICloud {
                                        ProgressView().tint(.secondary)
                                    } else {
                                        Text("불러오기")
                                            .font(.pretendardMedium(13))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                                    }
                                }
                                .disabled(isSavingToICloud || isRestoringFromICloud)
                            }

                            if let backupMessage {
                                Text(backupMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // 계정
                    settingsCard {
                        VStack(spacing: 0) {
                            if authManager.userID?.hasPrefix("guest_") == true {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("게스트 데이터는 Apple 로그인 후에도 그대로 유지돼요")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    SignInWithAppleButton(.signIn) { request in
                                        request.requestedScopes = [.fullName, .email]
                                    } onCompletion: { result in
                                        Task { @MainActor in
                                            switch result {
                                            case .success(let authorization):
                                                authManager.handleSignInSuccess(authorization: authorization)
                                            case .failure(let error):
                                                authManager.handleSignInError(error)
                                            }
                                        }
                                    }
                                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                                    .frame(height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .padding(.vertical, 4)

                                Divider()
                            }

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

                            Button { showWithdrawAlert = true } label: {
                                HStack {
                                    Label("회원 탈퇴", systemImage: "person.crop.circle.badge.minus")
                                        .foregroundStyle(.red)
                                    Spacer()
                                    if isWithdrawing {
                                        ProgressView().tint(.red)
                                    } else {
                                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                    }
                                }.font(.subheadline)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .disabled(isWithdrawing)

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
            .task(id: authManager.userID) {
                loadProfile()
                await refreshICloudBackupDate()
            }
            .sheet(isPresented: $showNicknameEdit) {
                NicknameChangeView(
                    currentNickname: profile?.nickname ?? "",
                    userID: authManager.userID ?? ""
                ) { newNickname in
                    saveNickname(newNickname)
                    showNicknameEdit = false
                }
                .presentationDetents([.medium])
            }
            .alert("전체 초기화", isPresented: $showResetAlert) {
                Button("초기화", role: .destructive) { resetOnboarding() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 학습 데이터가 삭제되고 처음 상태로 돌아갑니다.")
            }
            .alert("회원 탈퇴", isPresented: $showWithdrawAlert) {
                Button("계속", role: .destructive) { showWithdrawConfirmation = true }
                Button("취소", role: .cancel) {}
            } message: {
                Text("회원 탈퇴 시 모든 학습 데이터와 저장된 단어가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("정말 탈퇴하시겠습니까?", isPresented: $showWithdrawConfirmation) {
                Button("영구 삭제", role: .destructive) { performWithdraw() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("마지막 확인입니다. 탈퇴 후에는 데이터를 복구할 수 없습니다.")
            }
            .alert("iCloud 백업 불러오기", isPresented: $showRestoreAlert) {
                Button("불러오기", role: .destructive) { restoreProgressFromICloud() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("현재 기기의 진행상황을 iCloud 백업으로 교체합니다.")
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
        guard authManager.userID != nil else { return }
        let vm = MyPageViewModel(modelContext: modelContext, authManager: authManager)
        vm.resetOnboarding()
    }

    private func performWithdraw() {
        isWithdrawing = true
        let vm = MyPageViewModel(modelContext: modelContext, authManager: authManager)
        Task {
            await vm.deleteAccount()
            await MainActor.run {
                isWithdrawing = false
                dismiss()
            }
        }
    }

    private func saveNickname(_ newNickname: String) {
        guard let uid = authManager.userID else { return }

        let targetProfile: UserProfile
        if let cachedProfile = profile, cachedProfile.userID == uid {
            targetProfile = cachedProfile
        } else {
            let predicate = #Predicate<UserProfile> { $0.userID == uid }
            let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
            guard let fetchedProfile = try? modelContext.fetch(descriptor).first else { return }
            targetProfile = fetchedProfile
        }

        targetProfile.nickname = newNickname
        targetProfile.nicknameChangedAt = Date()
        try? modelContext.save()
        profile = targetProfile

        // CloudKit 동기화
        guard !uid.hasPrefix("guest_") else { return }
        Task {
            try? await FriendService.shared.upsertPublicProfile(
                userID: uid,
                nickname: newNickname,
                monthlyXP: 0,
                totalXP: 0,
                streak: 0,
                estimatedLevel: targetProfile.estimatedLevel,
                targetScore: targetProfile.targetScore
            )
        }
    }

    private func loadProfile() {
        guard let uid = authManager.userID else {
            profile = nil
            return
        }
        let predicate = #Predicate<UserProfile> { $0.userID == uid }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        profile = try? modelContext.fetch(descriptor).first
    }

    private var lastBackupText: String {
        guard let lastICloudBackupDate else { return "저장 기록 없음" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return "마지막 저장: \(formatter.string(from: lastICloudBackupDate))"
    }

    private func refreshICloudBackupDate() async {
        guard let uid = authManager.userID else {
            await MainActor.run { lastICloudBackupDate = nil }
            return
        }
        let date = await ICloudProgressBackupService.shared.fetchLastBackupDate(userID: uid)
        await MainActor.run {
            lastICloudBackupDate = date
        }
    }

    private func saveProgressToICloud() {
        guard let uid = authManager.userID else { return }
        isSavingToICloud = true
        backupMessage = nil
        Task {
            do {
                let savedAt = try await ICloudProgressBackupService.shared.backupProgress(userID: uid, context: modelContext)
                await MainActor.run {
                    lastICloudBackupDate = savedAt
                    backupMessage = "iCloud에 진행상황을 저장했어요."
                    isSavingToICloud = false
                }
            } catch {
                await MainActor.run {
                    backupMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
                    isSavingToICloud = false
                }
            }
        }
    }

    private func restoreProgressFromICloud() {
        guard let uid = authManager.userID else { return }
        isRestoringFromICloud = true
        backupMessage = nil

        Task {
            do {
                let restoredAt = try await ICloudProgressBackupService.shared.restoreProgress(userID: uid, context: modelContext)
                await MainActor.run {
                    lastICloudBackupDate = restoredAt
                    loadProfile()
                    backupMessage = "iCloud 저장본을 불러왔어요."
                    isRestoringFromICloud = false
                }
            } catch let backupError as ICloudProgressBackupError {
                await MainActor.run {
                    backupMessage = backupError.localizedDescription
                    isRestoringFromICloud = false
                }
            } catch {
                await MainActor.run {
                    backupMessage = "불러오기에 실패했어요. 잠시 후 다시 시도해주세요."
                    isRestoringFromICloud = false
                }
            }
        }
    }
}

// MARK: - NicknameChangeView

private struct NicknameChangeView: View {
    let currentNickname: String
    let userID: String
    var onSave: (String) -> Void

    @State private var nickname: String = ""
    @State private var checkState: NicknameCheckState = .idle
    @State private var checkTask: Task<Void, Never>? = nil
    @Environment(\.dismiss) private var dismiss

    enum NicknameCheckState {
        case idle, checking, available, unavailable, error
    }

    private var isValid: Bool {
        let t = nickname.trimmingCharacters(in: .whitespaces)
        return t.count >= 2 && t.count <= 10 && !t.contains(" ")
    }

    private var isSameAsCurrent: Bool {
        nickname.trimmingCharacters(in: .whitespaces) == currentNickname
    }

    private var canSave: Bool {
        // 에러 상태에서도 저장 허용 (중복 확인 실패는 네트워크 문제일 수 있음)
        isValid && (checkState == .available || checkState == .error) && !isSameAsCurrent
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.pencil")
                    .font(.system(size: 52))
                    .foregroundStyle(AppPalette.forest)

                VStack(spacing: 8) {
                    Text("닉네임 변경")
                        .font(.pretendardBold(22))
                    Text("한 달에 한 번만 변경할 수 있어요")
                        .font(.pretendardMedium(14))
                        .foregroundStyle(.secondary)
                }

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
                                .stroke(strokeColor, lineWidth: 2)
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: nickname) { _, newValue in
                            // 공백 제거, 10자 제한
                            var cleaned = newValue.replacingOccurrences(of: " ", with: "")
                            if cleaned.count > 10 { cleaned = String(cleaned.prefix(10)) }
                            if cleaned != newValue { nickname = cleaned }
                            scheduleCheck()
                        }

                    HStack {
                        checkStatusView
                        Spacer()
                        Text("\(nickname.count)/10")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .onAppear { nickname = currentNickname }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(AppPalette.forest)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(nickname.trimmingCharacters(in: .whitespaces))
                    }
                    .font(.pretendardSemiBold(16))
                    .foregroundStyle(canSave ? AppPalette.forest : AppPalette.forest.opacity(0.3))
                    .disabled(!canSave)
                }
            }
        }
    }

    private var strokeColor: Color {
        switch checkState {
        case .available: return AppPalette.forest
        case .unavailable: return .red
        default: return .clear
        }
    }

    @ViewBuilder
    private var checkStatusView: some View {
        switch checkState {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7)
                Text("확인 중...").font(.caption).foregroundStyle(.secondary)
            }
        case .available:
            if isSameAsCurrent {
                Text("현재 닉네임과 동일해요").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppPalette.forest)
                    Text("사용 가능한 닉네임이에요").font(.caption).foregroundStyle(AppPalette.forest)
                }
            }
        case .unavailable:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text("이미 사용 중인 닉네임이에요").font(.caption).foregroundStyle(.red)
            }
        case .error:
            HStack(spacing: 4) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
                Text("중복 확인 불가 (저장은 가능해요)").font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // 0.6초 디바운스 후 중복 체크
    private func scheduleCheck() {
        checkTask?.cancel()
        guard isValid else {
            checkState = .idle
            return
        }
        checkState = .checking
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        let myPublicID = FriendService.publicID(from: userID)
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            // 게스트는 CloudKit 체크 없이 바로 통과
            if userID.hasPrefix("guest_") {
                checkState = .available
                return
            }

            do {
                let available = try await FriendService.shared.isNicknameAvailable(trimmed, excludingPublicID: myPublicID)
                checkState = available ? .available : .unavailable
            } catch {
                checkState = .error
            }
        }
    }
}

#Preview {
    SettingsView()
}
