//
//  FriendSearchView.swift
//  Naelm
//
//  고유코드로 친구를 추가하고, 연락처에서 코드가 저장된 회원을 추천받는 Sheet.
//

import SwiftUI
import SwiftData
import Contacts
import UIKit

// MARK: - FriendSearchView

struct FriendSearchView: View {
    private enum SearchMode: String, CaseIterable, Identifiable {
        case code
        case contacts

        var id: String { rawValue }
        var title: String {
            switch self {
            case .code: return "코드로 추가"
            case .contacts: return "연락처 추천"
            }
        }
    }

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var mode: SearchMode = .code
    @State private var friendCodeInput: String = ""
    @State private var lookupResult: PublicUserInfo?
    @State private var contactRecommendations: [PublicUserInfo] = []
    @State private var isSearching: Bool = false
    @State private var isLoadingContacts: Bool = false
    @State private var searchError: String?
    @State private var pendingRequestIDs: Set<String> = []
    @State private var existingFriendIDs: Set<String> = []
    @State private var showError: Bool = false

    private var myFriendCode: String {
        guard let myID = authManager.userID else { return "" }
        return FriendService.friendCode(from: myID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.background(scheme: colorScheme).ignoresSafeArea()

                VStack(spacing: 12) {
                    myCodeCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Picker("검색 방식", selection: $mode) {
                        ForEach(SearchMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    Group {
                        if mode == .code {
                            codeLookupContent
                        } else {
                            contactRecommendationContent
                        }
                    }
                }
            }
            .navigationTitle("친구 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(AppPalette.forest)
                }
            }
            .onAppear {
                loadExistingFriends()
            }
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(searchError ?? "알 수 없는 오류가 발생했어요")
            }
        }
    }

    private var myCodeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내 친구 코드")
                .font(.pretendardSemiBold(14))
                .foregroundStyle(.secondary)

            HStack {
                Text(myFriendCode)
                    .font(.pretendardBold(18))
                    .foregroundStyle(AppPalette.forest)
                Spacer()
                Button {
                    UIPasteboard.general.string = myFriendCode
                } label: {
                    Label("복사", systemImage: "doc.on.doc")
                        .font(.pretendardSemiBold(13))
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.forest)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16, scheme: colorScheme)
    }

    private var codeLookupContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)

                TextField("예: NAELM-12AB34CD", text: $friendCodeInput)
                    .font(.pretendardMedium(16))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .onSubmit {
                        lookupByCode()
                    }

                Button("조회") {
                    lookupByCode()
                }
                .font(.pretendardSemiBold(13))
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.forest)
                .disabled(friendCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 16)

            if isSearching {
                Spacer()
                ProgressView().tint(AppPalette.forest)
                Spacer()
            } else if let error = searchError {
                Spacer()
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            } else if let result = lookupResult {
                ScrollView {
                    SearchResultRowView(
                        isAlreadyFriend: existingFriendIDs.contains(result.publicID),
                        isPending: pendingRequestIDs.contains(result.publicID),
                        info: result,
                        onAddFriend: { addFriend(result) }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("친구 코드를 입력해서 정확히 찾을 수 있어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var contactRecommendationContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text("내 연락처에 있는 사람 중 NAELM을 사용 중인 친구를 찾아요")
                    .font(.pretendard(12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("새로고침") {
                    loadContactRecommendations()
                }
                .font(.pretendardSemiBold(12))
                .disabled(isLoadingContacts)
            }
            .padding(.horizontal, 16)

            if isLoadingContacts {
                Spacer()
                ProgressView().tint(AppPalette.forest)
                Spacer()
            } else if let error = searchError {
                Spacer()
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            } else if contactRecommendations.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.clock")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("주변에 NAELM을 사용하는 친구가 아직 없어요")
                        .font(.pretendardSemiBold(14))
                    Text("친구를 초대해서 같이 공부해보세요!")
                        .font(.pretendard(12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(contactRecommendations) { info in
                            SearchResultRowView(
                                isAlreadyFriend: existingFriendIDs.contains(info.publicID),
                                isPending: pendingRequestIDs.contains(info.publicID),
                                info: info,
                                onAddFriend: { addFriend(info) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            if contactRecommendations.isEmpty && !isLoadingContacts {
                loadContactRecommendations()
            }
        }
    }

    private func lookupByCode() {
        let code = FriendService.normalizedFriendCode(friendCodeInput)
        friendCodeInput = code
        guard code.count == 14 else {
            lookupResult = nil
            searchError = "친구 코드 형식이 올바르지 않아요"
            return
        }

        isSearching = true
        searchError = nil
        lookupResult = nil
        Task {
            do {
                let user = try await FriendService.shared.lookupUser(friendCode: code)
                
                await MainActor.run {
                    guard let user else {
                        searchError = "해당 코드의 사용자를 찾지 못했어요"
                        isSearching = false
                        return
                    }

                    let myPublicID = authManager.userID.map { FriendService.publicID(from: $0) }
                    if user.publicID == myPublicID {
                        searchError = "내 코드는 친구 추가 대상이 아니에요"
                        lookupResult = nil
                    } else {
                        lookupResult = user
                    }
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchError = "조회에 실패했어요. 잠시 후 다시 시도해주세요."
                    isSearching = false
                }
            }
        }
    }

    private func loadContactRecommendations() {
        guard let myID = authManager.userID else { return }
        isLoadingContacts = true
        searchError = nil

        Task {
            do {
                let hashes = try await ContactRecommendationService.fetchContactHashes()
                let users = try await FriendService.shared.findUsersByContactHashes(hashes: Array(hashes), excludingUserID: myID)
                await MainActor.run {
                    contactRecommendations = users
                }
            } catch ContactRecommendationService.ContactError.denied {
                await MainActor.run {
                    searchError = "연락처 권한이 꺼져 있어요. 설정에서 권한을 허용해주세요."
                }
            } catch {
                await MainActor.run {
                    searchError = "연락처 추천을 불러오지 못했어요"
                }
            }
            await MainActor.run {
                isLoadingContacts = false
            }
        }
    }

    private func loadExistingFriends() {
        guard let myID = authManager.userID else { return }
        let predicate = #Predicate<Friendship> { $0.userID == myID }
        let descriptor = FetchDescriptor<Friendship>(predicate: predicate)
        let friendships = (try? modelContext.fetch(descriptor)) ?? []

        existingFriendIDs = Set(friendships.filter { $0.isFriend }.map { FriendService.publicID(from: $0.friendID) })
        pendingRequestIDs = Set(friendships.filter { $0.isPending }.map { FriendService.publicID(from: $0.friendID) })
    }

    private func addFriend(_ info: PublicUserInfo) {
        guard let myID = authManager.userID else { return }
        let myNickname = fetchMyNickname()

        Task {
            do {
                let alreadySent = try await FriendService.shared.hasPendingRequest(
                    fromUserID: myID,
                    toUserID: info.publicID
                )
                guard !alreadySent else {
                    pendingRequestIDs.insert(info.publicID)
                    return
                }

                let recordName = try await FriendService.shared.sendFriendRequest(
                    fromUserID: myID,
                    fromNickname: myNickname,
                    toPublicID: info.publicID
                )

                let friendship = Friendship(
                    userID: myID,
                    friendID: info.publicID,
                    isPending: true,
                    requestedByMe: true,
                    friendNickname: info.nickname,
                    cloudRequestRecordID: recordName
                )
                modelContext.insert(friendship)
                try? modelContext.save()

                pendingRequestIDs.insert(info.publicID)
            } catch {
                searchError = "친구 요청에 실패했어요. 다시 시도해주세요."
                showError = true
            }
        }
    }

    private func fetchMyNickname() -> String {
        guard let myID = authManager.userID else { return "" }
        let predicate = #Predicate<UserProfile> { $0.userID == myID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first?.nickname) ?? ""
    }
}

// MARK: - SearchResultRowView

private struct SearchResultRowView: View {
    let isAlreadyFriend: Bool
    let isPending: Bool
    let info: PublicUserInfo
    let onAddFriend: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var avatarInitial: String {
        String(info.nickname.prefix(1))
    }

    private var level: Int {
        GamificationService.level(fromTotalXP: info.totalXP)
    }

    private var currentLevelLabel: String {
        TOEICScoreRange.fromEstimatedLevel(info.estimatedLevel).label
    }

    var body: some View {
        HStack(spacing: 12) {
            // 아바타
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest, AppPalette.leaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Text(avatarInitial)
                    .font(.pretendardBold(18))
                    .foregroundStyle(.white)
            }

            // 닉네임 + 레벨/코드
            VStack(alignment: .leading, spacing: 3) {
                Text(info.nickname)
                    .font(.pretendardSemiBold(15))
                Text("\(info.friendCode) · Lv.\(level)")
                    .font(.pretendard(13))
                    .foregroundStyle(.secondary)
                Text("현재 \(currentLevelLabel) / 목표 \(info.targetScore)점")
                    .font(.pretendard(12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 관계 상태 버튼
            if isAlreadyFriend {
                Label("친구", systemImage: "checkmark")
                    .font(.pretendardMedium(13))
                    .foregroundStyle(.secondary)
            } else if isPending {
                Text("요청됨")
                    .font(.pretendardMedium(13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(.tertiarySystemFill))
                    )
            } else {
                Button {
                    onAddFriend()
                } label: {
                    Text("친구 추가")
                        .font(.pretendardSemiBold(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(AppPalette.forest)
                        )
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest.opacity(0.06), AppPalette.leaf.opacity(0.03), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [AppPalette.leaf.opacity(0.4), AppPalette.forest.opacity(0.15), AppPalette.leaf.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

// MARK: - ContactRecommendationService

private enum ContactRecommendationService {
    enum ContactError: Error {
        case denied
    }

    static func fetchContactHashes() async throws -> Set<String> {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        if status == .notDetermined {
            let granted: Bool = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                store.requestAccess(for: .contacts) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
            if !granted { throw ContactError.denied }
        } else if status != .authorized {
            throw ContactError.denied
        }

        return try await Task.detached {
            let keys: [CNKeyDescriptor] = [
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)

            var hashes = Set<String>()
            try store.enumerateContacts(with: request) { contact, _ in
                // 1. 전화번호 추출 (숫자만 남기고, 국가코드 정규화 등 가능하나 여기선 단순 숫자만 사용)
                for phoneNumber in contact.phoneNumbers {
                    let digits = phoneNumber.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if !digits.isEmpty {
                        hashes.insert(FriendService.hashContactIdentifier(digits))
                        // 국가 코드 없이 저장된 경우 대비 010 형태도 추가 (한국 기준)
                        if digits.hasPrefix("010") {
                            let withCountryCode = "82" + digits.dropFirst()
                            hashes.insert(FriendService.hashContactIdentifier(withCountryCode))
                        }
                    }
                }
                
                // 2. 이메일 주소 추출
                for email in contact.emailAddresses {
                    let address = email.value as String
                    let normalizedEmail = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !normalizedEmail.isEmpty {
                        hashes.insert(FriendService.hashContactIdentifier(normalizedEmail))
                    }
                }
            }
            return hashes
        }.value
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var auth = AuthenticationManager()
    FriendSearchView()
        .environment(auth)
}
