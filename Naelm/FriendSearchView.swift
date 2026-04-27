//
//  FriendSearchView.swift
//  Naelm
//
//  닉네임으로 친구를 검색하고 친구 요청을 보내는 Sheet.
//

import SwiftUI
import SwiftData

// MARK: - FriendSearchView

struct FriendSearchView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var searchResults: [PublicUserInfo] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var pendingRequestIDs: Set<String> = []  // 이미 요청한 friendID 집합

    /// 기존 친구 ID 집합 (친구 여부 판단)
    @State private var existingFriendIDs: Set<String> = []

    /// 검색 debounce용 Task
    @State private var searchTask: Task<Void, Never>? = nil

    /// 에러 알림
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.background(scheme: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    // 검색 바
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    // 검색 결과
                    if isSearching {
                        Spacer()
                        ProgressView()
                            .tint(AppPalette.forest)
                        Spacer()
                    } else if let error = searchError {
                        Spacer()
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("검색 결과가 없어요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(searchResults.filter { $0.userID != authManager.userID }) { info in
                                    SearchResultRowView(
                                        isAlreadyFriend: existingFriendIDs.contains(info.userID),
                                        isPending: pendingRequestIDs.contains(info.userID),
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
            }
            .navigationTitle("친구 찾기")
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

    // MARK: - 검색 바

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("닉네임으로 검색", text: $searchText)
                .font(.pretendardMedium(16))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, newValue in
                    scheduleSearch(query: newValue)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    searchError = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - 0.5초 debounce 검색

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            searchError = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5초
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        searchError = nil
        do {
            searchResults = try await FriendService.shared.searchUsers(nickname: query)
        } catch {
            searchError = "검색에 실패했어요. 다시 시도해주세요."
        }
        isSearching = false
    }

    // MARK: - 기존 친구 로드

    private func loadExistingFriends() {
        guard let myID = authManager.userID else { return }
        let predicate = #Predicate<Friendship> { $0.userID == myID }
        let descriptor = FetchDescriptor<Friendship>(predicate: predicate)
        let friendships = (try? modelContext.fetch(descriptor)) ?? []

        existingFriendIDs = Set(friendships.filter { $0.isFriend }.map(\.friendID))
        pendingRequestIDs = Set(friendships.filter { $0.isPending }.map(\.friendID))
    }

    // MARK: - 친구 추가

    private func addFriend(_ info: PublicUserInfo) {
        guard let myID = authManager.userID else { return }
        let myNickname = fetchMyNickname()

        Task {
            do {
                // 앱 재설치/기기 변경 상황에서 CloudKit 중복 요청 방지
                let alreadySent = try await FriendService.shared.hasPendingRequest(
                    fromUserID: myID,
                    toUserID: info.userID
                )
                guard !alreadySent else {
                    // CloudKit에 이미 요청이 있으면 로컬 상태만 업데이트
                    pendingRequestIDs.insert(info.userID)
                    return
                }

                let recordName = try await FriendService.shared.sendFriendRequest(
                    fromUserID: myID,
                    fromNickname: myNickname,
                    toUserID: info.userID
                )

                // 로컬 Friendship 레코드 생성
                let friendship = Friendship(
                    userID: myID,
                    friendID: info.userID,
                    isPending: true,
                    requestedByMe: true,
                    friendNickname: info.nickname,
                    cloudRequestRecordID: recordName
                )
                modelContext.insert(friendship)
                try? modelContext.save()

                pendingRequestIDs.insert(info.userID)
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

            // 닉네임 + 레벨
            VStack(alignment: .leading, spacing: 3) {
                Text(info.nickname)
                    .font(.pretendardSemiBold(15))
                Text("Lv.\(level)")
                    .font(.pretendard(13))
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

// MARK: - Preview

#Preview {
    @State var auth = AuthenticationManager()
    return FriendSearchView()
        .environment(auth)
}
