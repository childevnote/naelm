//
//  FriendDetailView.swift
//  Naelm
//
//  친구 상세 프로필 뷰.
//  FriendTabView 또는 RankingView에서 NavigationLink로 진입합니다.
//

import SwiftUI
import SwiftData

// MARK: - FriendDetailView

struct FriendDetailView: View {
    let friendship: Friendship

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var publicInfo: PublicUserInfo? = nil
    @State private var isLoading: Bool = true
    @State private var levelGaugeProgress: Double = 0.0
    @State private var showDeleteConfirm: Bool = false
    @State private var isSendingChallenge: Bool = false
    @State private var challengeMessage: String?
    @State private var activeChallenge: StreakChallengeInfo?

    private var displayNickname: String {
        if let info = publicInfo { return info.nickname }
        return friendship.friendNickname.isEmpty ? "알 수 없음" : friendship.friendNickname
    }

    private var totalXP: Int { publicInfo?.totalXP ?? 0 }
    private var streak: Int { publicInfo?.streak ?? 0 }
    private var monthlyXP: Int { publicInfo?.monthlyXP ?? 0 }
    private var weeklyXP: Int { publicInfo?.weeklyXP ?? 0 }
    private var level: Int { GamificationService.level(fromTotalXP: totalXP) }
    private var levelProgress: Double { GamificationService.levelProgress(fromTotalXP: totalXP) }
    private var xpToNext: Int { GamificationService.xpToNextLevel(fromTotalXP: totalXP) }
    private var currentLevelLabel: String { TOEICScoreRange.fromEstimatedLevel(publicInfo?.estimatedLevel ?? 0).label }
    private var targetScore: Int { publicInfo?.targetScore ?? 700 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. 상단 프로필 헤더 카드
                profileHeaderCard

                // 2. 핵심 통계 그리드
                if !isLoading {
                    statsGrid

                    // 3. 레벨 프로그레스 바
                    levelProgressCard

                    // 4. 스트릭 대결 카드
                    challengeCard
                }

                // 5. 하단 액션 버튼
                deleteButton

                Spacer(minLength: 32)
            }
            .padding(16)
        }
        .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
        .navigationTitle(displayNickname)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPublicInfo()
            loadActiveChallenge()
        }
        .confirmationDialog(
            "'\(displayNickname)'님을 친구 목록에서 삭제하시겠어요?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("친구 삭제", role: .destructive) {
                deleteFriend()
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - 프로필 헤더 카드

    private var profileHeaderCard: some View {
        VStack(spacing: 16) {
            // 대형 아바타
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.forest, AppPalette.leaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: AppPalette.forest.opacity(0.25), radius: 12, y: 4)

                Text(String(displayNickname.prefix(1)))
                    .font(.pretendardBold(34))
                    .foregroundStyle(.white)
            }

            // 닉네임
            Text(displayNickname)
                .font(.pretendardBold(26))

            // 레벨 뱃지
            if isLoading {
                ProgressView().tint(AppPalette.forest)
            } else {
                Text("Lv.\(level)")
                    .font(.pretendardSemiBold(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .glassCard(cornerRadius: 24, scheme: colorScheme)
    }

    // MARK: - 통계 그리드

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statItem(icon: "flame.fill", label: "연속 학습일", value: "\(streak)일", color: .orange)
            statItem(icon: "star.fill", label: "총 획득 XP", value: "\(totalXP) XP", color: AppPalette.gold)
            statItem(icon: "calendar.badge.plus", label: "이번 주 XP", value: "\(weeklyXP) XP", color: AppPalette.forest)
            statItem(icon: "chart.bar.fill", label: "레벨", value: "Lv.\(level)", color: AppPalette.leaf)
            statItem(icon: "graduationcap.fill", label: "현재 수준", value: currentLevelLabel, color: .blue)
            statItem(icon: "target", label: "목표 점수", value: "\(targetScore)점", color: .purple)
        }
    }

    private func statItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.pretendardBold(18))
            Text(label)
                .font(.pretendard(12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
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

    // MARK: - 레벨 프로그레스 바

    private var levelProgressCard: some View {
        VStack(spacing: 12) {
            Text("레벨 진행도")
                .font(.pretendardSemiBold(15))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Text("Lv.\(level)")
                    .font(.pretendardBold(14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppPalette.forest.opacity(0.12))
                            .frame(height: 18)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppPalette.forest.opacity(0.75), AppPalette.leaf],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * levelGaugeProgress, height: 18)
                            .animation(.easeOut(duration: 1.0), value: levelGaugeProgress)

                        HStack {
                            Spacer()
                            Text("다음 레벨까지 \(xpToNext) XP")
                                .font(.pretendardMedium(10))
                                .foregroundStyle(.secondary.opacity(0.75))
                            Spacer()
                        }
                    }
                    .frame(height: 18)
                    .clipShape(Capsule())
                }
                .frame(height: 18)
            }
            .padding(.horizontal, 4)
            .onAppear {
                levelGaugeProgress = 0
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 1.0)) {
                        levelGaugeProgress = levelProgress
                    }
                }
            }
            .onChange(of: publicInfo?.totalXP) { _, _ in
                withAnimation(.easeOut(duration: 0.8)) {
                    levelGaugeProgress = levelProgress
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24, scheme: colorScheme)
    }

    // MARK: - 친구 삭제 버튼

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.fill.xmark")
                Text("친구 삭제")
                    .font(.pretendardSemiBold(15))
            }
            .foregroundStyle(AppPalette.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppPalette.error.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var challengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("연속학습일 대결")
                .font(.pretendardSemiBold(15))

            if let activeChallenge {
                Text("진행 중: \(activeChallenge.challengerNickname) vs \(activeChallenge.opponentNickname)")
                    .font(.pretendard(13))
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    sendChallenge()
                } label: {
                    HStack {
                        if isSendingChallenge {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("1:1 대결 요청 보내기")
                            .font(.pretendardSemiBold(14))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppPalette.forest))
                }
                .disabled(isSendingChallenge)
            }

            if let challengeMessage {
                Text(challengeMessage)
                    .font(.pretendard(12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24, scheme: colorScheme)
    }

    // MARK: - 데이터 로딩

    private func loadPublicInfo() {
        isLoading = true
        Task {
            let publicID = FriendService.publicID(from: friendship.friendID)
            publicInfo = try? await FriendService.shared.fetchPublicProfile(userID: publicID)
            isLoading = false
        }
    }

    private func loadActiveChallenge() {
        guard let myID = authManager.userID else { return }
        Task {
            let friendPublicID = FriendService.publicID(from: friendship.friendID)
            activeChallenge = try? await FriendService.shared.fetchActiveChallenge(myUserID: myID, withFriendPublicID: friendPublicID)
        }
    }

    private func sendChallenge() {
        guard let myID = authManager.userID else { return }
        let friendPublicID = FriendService.publicID(from: friendship.friendID)
        let myNickname = fetchMyNickname(userID: myID)
        let myStreak = GamificationService.currentStreak(userID: myID, context: modelContext)

        isSendingChallenge = true
        challengeMessage = nil
        Task {
            do {
                let pendingExists = try await FriendService.shared.hasPendingStreakChallenge(fromUserID: myID, toUserID: friendPublicID)
                guard !pendingExists else {
                    challengeMessage = "이미 보낸 대결 요청이 있어요"
                    isSendingChallenge = false
                    return
                }

                _ = try await FriendService.shared.sendStreakChallenge(
                    fromUserID: myID,
                    fromNickname: myNickname,
                    challengerStreak: myStreak,
                    toPublicID: friendPublicID,
                    toNickname: displayNickname
                )
                challengeMessage = "대결 요청을 보냈어요. 상대가 수락하면 시작됩니다."
            } catch {
                challengeMessage = "대결 요청 전송에 실패했어요"
            }
            isSendingChallenge = false
        }
    }

    private func fetchMyNickname(userID: String) -> String {
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first?.nickname) ?? "익명"
    }

    // MARK: - 친구 삭제

    private func deleteFriend() {
        let recordID = friendship.cloudRequestRecordID
        friendship.isFriend = false
        friendship.isPending = false
        try? modelContext.save()

        // CloudKit FriendRequest 레코드도 "removed"로 표시하여 상대방에게 변경 사항 전달
        if !recordID.isEmpty {
            Task {
                try? await FriendService.shared.updateFriendRequestStatus(
                    recordName: recordID,
                    status: "removed"
                )
            }
        }

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let friendship = Friendship(
        userID: "me",
        friendID: "friend1",
        isFriend: true,
        friendNickname: "토익왕"
    )
    return NavigationStack {
        FriendDetailView(friendship: friendship)
    }
}
