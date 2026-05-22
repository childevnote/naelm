//
//  FriendTabView.swift
//  Naelm
//
//  MyPageView의 "친구" 탭 콘텐츠.
//  친구 목록 표시, 친구 검색, 친구 요청 관리를 제공합니다.
//

import SwiftUI
import SwiftData
import os

// MARK: - FriendTabView

struct FriendTabView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// 닉네임 미설정 시 Sheet 트리거
    @Binding var showNicknameSetup: Bool

    @State private var showFriendSearch: Bool = false
    @State private var showFriendRequests: Bool = false
    @State private var showChallengeRequests: Bool = false
    @State private var pendingRequestCount: Int = 0
    @State private var pendingChallengeCount: Int = 0
    @State private var friendPublicInfos: [String: PublicUserInfo] = [:]  // publicID → 공개 정보

    /// 현재 친구 목록 (isFriend && !isBlocked)
    @Query private var allFriendships: [Friendship]

    private var friends: [Friendship] {
        guard let myID = authManager.userID else { return [] }
        return allFriendships.filter {
            $0.userID == myID &&
            $0.isFriend == true &&
            $0.isBlocked == false
        }
    }

    var body: some View {
        // 게스트 유저 처리
        if authManager.userID?.hasPrefix("guest_") == true {
            guestBlockView
        } else {
            friendListContent
        }
    }

    // MARK: - 게스트 차단 뷰

    private var guestBlockView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("친구 기능은 Sign in with Apple 계정이 필요해요")
                .font(.pretendardMedium(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 친구 목록 콘텐츠

    private var friendListContent: some View {
        VStack(spacing: 12) {
            // 상단 액션 영역
            HStack(spacing: 12) {
                // 친구 추가 버튼
                Button {
                    // 닉네임 미설정 확인
                    if fetchMyNickname().isEmpty {
                        showNicknameSetup = true
                    } else {
                        showFriendSearch = true
                    }
                } label: {
                    Label("친구 추가", systemImage: "plus.circle.fill")
                        .font(.pretendardSemiBold(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [AppPalette.forest, AppPalette.leaf],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                }

                Spacer()

                Button {
                    showChallengeRequests = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "flame.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(AppPalette.forest)
                            .padding(10)

                        if pendingChallengeCount > 0 {
                            Text("\(pendingChallengeCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(Color.red))
                                .offset(x: 4, y: -4)
                        }
                    }
                }

                // 받은 친구 요청 배지 버튼
                Button {
                    showFriendRequests = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 22))
                            .foregroundStyle(AppPalette.forest)
                            .padding(10)

                        if pendingRequestCount > 0 {
                            Text("\(pendingRequestCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(Color.red))
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // 친구 목록
            if friends.isEmpty {
                emptyFriendState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(friends) { friendship in
                        NavigationLink(destination: FriendDetailView(friendship: friendship)) {
                            FriendRowView(
                                friendship: friendship,
                                publicInfo: friendPublicInfos[FriendService.publicID(from: friendship.friendID)]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            loadPendingCount()
            loadPendingChallengeCount()
            loadFriendPublicInfos()
            syncAcceptedOutgoingRequestsIfNeeded()
        }
        .sheet(isPresented: $showFriendSearch) {
            FriendSearchView()
                .environment(authManager)
        }
        .sheet(isPresented: $showFriendRequests, onDismiss: {
            loadPendingCount()
        }) {
            FriendRequestListView()
                .environment(authManager)
        }
        .sheet(isPresented: $showChallengeRequests, onDismiss: {
            loadPendingChallengeCount()
        }) {
            StreakChallengeInboxView()
                .environment(authManager)
        }
        .refreshable {
            loadPendingCount()
            loadPendingChallengeCount()
            syncAcceptedOutgoingRequestsIfNeeded()
            await loadFriendPublicInfosAsync()
        }
    }

    // MARK: - 빈 상태 뷰

    private var emptyFriendState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("아직 친구가 없어요")
                .font(.pretendardSemiBold(16))
            Text("친구를 추가하고 함께 공부해보세요!")
                .font(.pretendardMedium(14))
                .foregroundStyle(.secondary)
            Button {
                if fetchMyNickname().isEmpty {
                    showNicknameSetup = true
                } else {
                    showFriendSearch = true
                }
            } label: {
                Label("친구 추가하기", systemImage: "plus")
                    .font(.pretendardSemiBold(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AppPalette.forest))
            }
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 데이터 로딩

    private func loadPendingCount() {
        guard let myID = authManager.userID else { return }
        Task {
            do {
                let requests = try await FriendService.shared.fetchPendingRequests(toUserID: myID)
                pendingRequestCount = requests.count
            } catch {
                pendingRequestCount = 0
            }
        }
    }

    private func loadPendingChallengeCount() {
        guard let myID = authManager.userID else { return }
        Task {
            do {
                let requests = try await FriendService.shared.fetchPendingStreakChallenges(toUserID: myID)
                pendingChallengeCount = requests.count
            } catch {
                pendingChallengeCount = 0
            }
        }
    }

    private func loadFriendPublicInfos() {
        Task {
            await loadFriendPublicInfosAsync()
        }
    }

    @MainActor
    private func loadFriendPublicInfosAsync() async {
        let friendIDs = friends.map { FriendService.publicID(from: $0.friendID) }
        guard !friendIDs.isEmpty else { return }
        do {
            let infos = try await FriendService.shared.fetchPublicProfiles(userIDs: friendIDs)
            for info in infos {
                friendPublicInfos[info.publicID] = info
            }
        } catch {
            AppLogger.friend.warning("Failed to fetch friend public profiles: \(error.localizedDescription)")
        }
    }

    private func fetchMyNickname() -> String {
        guard let myID = authManager.userID else { return "" }
        let predicate = #Predicate<UserProfile> { $0.userID == myID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first?.nickname) ?? ""
    }

    private func syncAcceptedOutgoingRequestsIfNeeded() {
        guard let myID = authManager.userID else { return }
        FriendSyncService.shared.syncAcceptedOutgoingRequests(userID: myID, context: modelContext)
    }
}

private struct StreakChallengeInboxView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var requests: [StreakChallengeInfo] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.background(scheme: colorScheme).ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(AppPalette.forest)
                    } else if requests.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "flame")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("받은 대결 요청이 없어요")
                                .font(.pretendardMedium(14))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(requests) { request in
                                    challengeRow(request)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("대결 요청함")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(AppPalette.forest)
                }
            }
            .onAppear { loadRequests() }
        }
    }

    private func challengeRow(_ request: StreakChallengeInfo) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.challengerNickname)
                    .font(.pretendardSemiBold(15))
                Text("상대 streak: \(request.challengerStreak)일")
                    .font(.pretendard(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("수락") {
                update(request, status: "active")
            }
            .font(.pretendardSemiBold(12))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.forest)

            Button("거절") {
                update(request, status: "declined")
            }
            .font(.pretendardSemiBold(12))
            .buttonStyle(.bordered)
        }
        .padding(14)
        .glassCard(cornerRadius: 16, scheme: colorScheme)
    }

    private func loadRequests() {
        guard let myID = authManager.userID else {
            isLoading = false
            return
        }
        isLoading = true
        Task {
            requests = (try? await FriendService.shared.fetchPendingStreakChallenges(toUserID: myID)) ?? []
            isLoading = false
        }
    }

    private func update(_ request: StreakChallengeInfo, status: String) {
        Task {
            try? await FriendService.shared.updateStreakChallengeStatus(recordName: request.recordName, status: status)
            requests.removeAll { $0.recordName == request.recordName }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var auth = AuthenticationManager()
    @Previewable @State var showNickname = false
    FriendTabView(showNicknameSetup: $showNickname)
        .environment(auth)
}
