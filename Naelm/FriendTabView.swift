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
    @State private var pendingRequestCount: Int = 0
    @State private var friendPublicInfos: [String: PublicUserInfo] = [:]  // friendID → 공개 정보

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
                                publicInfo: friendPublicInfos[friendship.friendID]
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
            loadFriendPublicInfos()
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
        .refreshable {
            loadPendingCount()
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

    private func loadFriendPublicInfos() {
        Task {
            await loadFriendPublicInfosAsync()
        }
    }

    @MainActor
    private func loadFriendPublicInfosAsync() async {
        let friendIDs = friends.map(\.friendID)
        guard !friendIDs.isEmpty else { return }
        do {
            let infos = try await FriendService.shared.fetchPublicProfiles(userIDs: friendIDs)
            for info in infos {
                friendPublicInfos[info.userID] = info
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
}

// MARK: - Preview

#Preview {
    @State var auth = AuthenticationManager()
    @State var showNickname = false
    return FriendTabView(showNicknameSetup: $showNickname)
        .environment(auth)
}
