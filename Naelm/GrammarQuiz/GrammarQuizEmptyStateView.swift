//
//  GrammarQuizEmptyStateView.swift
//  Naelm
//

import SwiftUI

struct GrammarQuizEmptyStateView: View {
    let onReload: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("풀 수 있는 문제가 없어요")
                .font(.title3)
                .fontWeight(.semibold)

            Text("문법 데이터를 로드 중이거나\n모든 문법을 숙달했습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("새로고침") {
                onReload()
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.forest)
            .padding(.top, 8)
        }
    }
}
