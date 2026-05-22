//
//  FriendRowView.swift
//  Naelm
//
//  친구 목록의 단일 행 컴포넌트.
//

import SwiftUI

// MARK: - FriendRowView

struct FriendRowView: View {
    let friendship: Friendship
    let publicInfo: PublicUserInfo?  // CloudKit에서 조회한 정보, nil이면 로컬 데이터만 표시

    @Environment(\.colorScheme) private var colorScheme

    private var displayNickname: String {
        friendship.friendNickname.isEmpty ? "알 수 없음" : friendship.friendNickname
    }

    private var avatarInitial: String {
        String(displayNickname.prefix(1))
    }

    var body: some View {
        HStack(spacing: 12) {
            // 아바타: 닉네임 첫 글자 원형
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

            // 닉네임 + 서브텍스트
            VStack(alignment: .leading, spacing: 3) {
                Text(displayNickname)
                    .font(.pretendardSemiBold(15))

                if let info = publicInfo {
                    let level = GamificationService.level(fromTotalXP: info.totalXP)
                    let currentLevel = TOEICScoreRange.fromEstimatedLevel(info.estimatedLevel).shortLabel
                    Text("Lv.\(level) · 🔥\(info.streak)일 · \(currentLevel)→\(info.targetScore)")
                        .font(.pretendard(13))
                        .foregroundStyle(.secondary)
                } else {
                    Text("정보 로딩 중...")
                        .font(.pretendard(13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 총 XP 표시
            if let info = publicInfo {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(info.totalXP)")
                        .font(.pretendardSemiBold(14))
                        .foregroundStyle(AppPalette.forest)
                    Text("XP")
                        .font(.pretendard(11))
                        .foregroundStyle(.secondary)
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
    let friendship = Friendship(
        userID: "me",
        friendID: "friend1",
        isFriend: true,
        friendNickname: "토익왕"
    )
    let publicInfo = PublicUserInfo(
        publicID: "friend1",
        nickname: "토익왕",
        friendCode: "NAELM-1234ABCD",
        estimatedLevel: 3,
        targetScore: 900,
        monthlyXP: 800,
        totalXP: 3200,
        streak: 12,
        weeklyXP: 350,
        recordName: "profile_friend1",
        contactHashes: []
    )

    FriendRowView(friendship: friendship, publicInfo: publicInfo)
        .padding()
}
