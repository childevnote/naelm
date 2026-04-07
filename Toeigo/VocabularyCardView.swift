//
//  VocabularyCardView.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  단어 카드 UI — 브랜드 컬러 적용, 다크모드 대응.
//

import SwiftUI

struct VocabularyCardView: View {

    let vocabulary: Vocabulary
    var isBookmarked: Bool = false
    var onBookmarkToggle: (() -> Void)? = nil
    /// 뒤집힘 상태 변경 시 호출 (true = 뒷면 보이는 중 → 타이머 정지)
    var onFlip: ((Bool) -> Void)? = nil
    @State private var isFlipped: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 32
    private let cardHeight: CGFloat = 480

    var body: some View {
        ZStack {
            // 뒷면
            cardBack
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(isFlipped)

            // 앞면
            cardFront
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(!isFlipped)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .drawingGroup()
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
            onFlip?(isFlipped)
            HapticManager.shared.playTap()
        }
    }

    // MARK: - Front

    private var cardFront: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text(vocabulary.english)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if !vocabulary.pronunciation.isEmpty {
                    Text(vocabulary.pronunciation)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if !vocabulary.partOfSpeech.isEmpty {
                    let parts = vocabulary.partOfSpeech
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    HStack(spacing: 6) {
                        ForEach(parts, id: \.self) { pos in
                            Text(pos)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(BrandTheme.accent)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(BrandTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                Text("탭하여 뜻 보기")
            }
            .font(.caption).foregroundStyle(.tertiary)
            .padding(.bottom, 24)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.quaternary, lineWidth: 1))
    }

    // MARK: - Back

    private var cardBack: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text(vocabulary.english)
                    .font(.title3).foregroundStyle(.secondary)

                // 품사 표시
                if !vocabulary.partOfSpeech.isEmpty {
                    let parts = vocabulary.partOfSpeech
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    HStack(spacing: 6) {
                        ForEach(parts, id: \.self) { pos in
                            Text(pos)
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(BrandTheme.accent)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(BrandTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                // 한국어 의미
                let meanings = vocabulary.korean
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                VStack(spacing: 4) {
                    ForEach(Array(meanings.enumerated()), id: \.offset) { idx, meaning in
                        Text("\(idx + 1). \(meaning)")
                            .font(.system(size: meanings.count > 1 ? 24 : 30, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .multilineTextAlignment(.center)

                Divider().padding(.horizontal, 40)

                if !vocabulary.exampleSentence.isEmpty {
                    VStack(spacing: 5) {
                        Text(vocabulary.exampleSentence)
                            .font(.subheadline).italic()
                            .multilineTextAlignment(.center)
                        if !vocabulary.exampleTranslation.isEmpty {
                            Text(vocabulary.exampleTranslation)
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !vocabulary.synonyms.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "equal.circle").font(.caption2)
                        Text(vocabulary.synonyms).font(.caption)
                    }
                    .foregroundStyle(.secondary).padding(.top, 2)
                }
            }

            Spacer()

            // 스와이프 안내
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                    Text("알고있어요")
                }
                .font(.caption).foregroundStyle(BrandTheme.knewIt)

                HStack(spacing: 4) {
                    Text("학습할게요")
                    Image(systemName: "arrow.right")
                }
                .font(.caption).foregroundStyle(BrandTheme.studyIt)
            }
            .padding(.bottom, 24)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.quaternary, lineWidth: 1))
    }

    // MARK: - Helpers

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(colorScheme == .dark ? BrandTheme.cardBackgroundDark : BrandTheme.cardBackground)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: 16, y: 8)
    }
}

// MARK: - Preview

#Preview {
    VocabularyCardView(
        vocabulary: {
            let v = Vocabulary(
                wordID: "preview_001",
                english: "revenue",
                korean: "수익, 매출",
                pronunciation: "/ˈrev.ən.uː/",
                partOfSpeech: "noun",
                frequencyLevel: 1,
                exampleSentence: "The company's annual revenue exceeded $10 million.",
                exampleTranslation: "그 회사의 연간 매출이 1천만 달러를 넘었다.",
                category: "Finance",
                synonyms: "income, earnings"
            )
            return v
        }()
    )
    .padding()
}
