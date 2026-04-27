//
//  FriendRequestListView.swift
//  Naelm
//
//  받은 친구 요청 목록 Sheet.
//

import SwiftUI
import SwiftData

// MARK: - FriendRequestListView

struct FriendRequestListView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var requests: [FriendRequestInfo] = []
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.background(scheme: colorScheme).ignoresSafeArea()

                Group {
                    if isLoading {
                        VStack {
                            Spacer()
                            ProgressView().tint(AppPalette.forest)
                            Spacer()
                        }
                    } else if requests.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("받은 친구 요청이 없어요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(requests) { request in
                                    requestRow(request)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("받은 친구 요청")
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

    // MARK: - 요청 행

    private func requestRow(_ request: FriendRequestInfo) -> some View {
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
                Text(String(request.fromNickname.prefix(1)))
                    .font(.pretendardBold(18))
                    .foregroundStyle(.white)
            }

            // 닉네임 + 날짜
            VStack(alignment: .leading, spacing: 3) {
                Text(request.fromNickname)
                    .font(.pretendardSemiBold(15))
                Text(relativeDate(from: request.createdAt))
                    .font(.pretendard(13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 수락/거절 버튼
            HStack(spacing: 8) {
                Button {
                    acceptRequest(request)
                } label: {
                    Text("수락")
                        .font(.pretendardSemiBold(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppPalette.forest))
                }

                Button {
                    declineRequest(request)
                } label: {
                    Text("거절")
                        .font(.pretendardMedium(13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
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

    // MARK: - 로드

    private func loadRequests() {
        guard let myID = authManager.userID else {
            isLoading = false
            return
        }
        isLoading = true
        Task {
            do {
                requests = try await FriendService.shared.fetchPendingRequests(toUserID: myID)
            } catch {
                requests = []
            }
            isLoading = false
        }
    }

    // MARK: - 수락

    private func acceptRequest(_ request: FriendRequestInfo) {
        guard let myID = authManager.userID else { return }

        Task {
            do {
                try await FriendService.shared.updateFriendRequestStatus(
                    recordName: request.recordName,
                    status: "accepted"
                )

                // 로컬 Friendship 레코드 조회 또는 생성
                let predicate = #Predicate<Friendship> {
                    $0.userID == myID && $0.friendID == request.fromUserID
                }
                let descriptor = FetchDescriptor<Friendship>(predicate: predicate)
                if let existing = try? modelContext.fetch(descriptor).first {
                    existing.isFriend = true
                    existing.isPending = false
                } else {
                    let friendship = Friendship(
                        userID: myID,
                        friendID: request.fromUserID,
                        isFriend: true,
                        isPending: false,
                        requestedByMe: false,
                        friendNickname: request.fromNickname,
                        cloudRequestRecordID: request.recordName
                    )
                    modelContext.insert(friendship)
                }
                try? modelContext.save()

                // 목록에서 제거
                requests.removeAll { $0.recordName == request.recordName }
            }
            // 에러 무시
        }
    }

    // MARK: - 거절

    private func declineRequest(_ request: FriendRequestInfo) {
        guard let myID = authManager.userID else { return }

        Task {
            do {
                try await FriendService.shared.updateFriendRequestStatus(
                    recordName: request.recordName,
                    status: "declined"
                )

                // 로컬 Friendship 레코드가 있으면 삭제
                let predicate = #Predicate<Friendship> {
                    $0.userID == myID && $0.friendID == request.fromUserID && $0.isPending == true
                }
                let descriptor = FetchDescriptor<Friendship>(predicate: predicate)
                if let existing = try? modelContext.fetch(descriptor).first {
                    modelContext.delete(existing)
                    try? modelContext.save()
                }

                // 목록에서 제거
                requests.removeAll { $0.recordName == request.recordName }
            }
            // 에러 무시
        }
    }

    // MARK: - 상대적 날짜 표시

    private func relativeDate(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            return "\(Int(interval / 60))분 전"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))시간 전"
        } else {
            return "\(Int(interval / 86400))일 전"
        }
    }
}

// MARK: - Preview

#Preview {
    @State var auth = AuthenticationManager()
    return FriendRequestListView()
        .environment(auth)
}
