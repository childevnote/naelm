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
    @State private var isFlipped: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = 340
    private let cardHeight: CGFloat = 460

    var body: some View {
        ZStack {
            // 뒷면: isFlipped일 때만 보임, 앞면 위에 렌더링
            cardBack
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(isFlipped)

            // 앞면: 뒤집히면 숨김
            cardFront
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(!isFlipped)

            // 북마크 버튼 (카드 하단 중앙)
            if let toggle = onBookmarkToggle {
                VStack {
                    Spacer()
                    Button {
                        toggle()
                        HapticManager.shared.playTap()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: isBookmarked ? "star.fill" : "star")
                                .font(.system(size: 20))
                            Text("저장")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(isBookmarked ? BrandTheme.accent : .gray.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.bottom, 44)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .drawingGroup()
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
            HapticManager.shared.playTap()
        }
    }

    // MARK: - Front

    private var cardFront: some View {
        VStack(spacing: 0) {
            HStack {
                categoryBadge
                Spacer()
                difficultyBadge
            }
            .padding(.horizontal, 20).padding(.top, 20)

            Spacer()

            VStack(spacing: 12) {
                Text(vocabulary.english)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if !vocabulary.pronunciation.isEmpty {
                    Text(vocabulary.pronunciation)
                        .font(.system(size: 17, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if !vocabulary.partOfSpeech.isEmpty {
                    Text(vocabulary.partOfSpeech)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(BrandTheme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(BrandTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                Text("탭하여 뜻 보기")
            }
            .font(.caption).foregroundStyle(.tertiary)
            .padding(.bottom, 20)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
    }

    // MARK: - Back

    private var cardBack: some View {
        VStack(spacing: 0) {
            HStack { categoryBadge; Spacer() }
                .padding(.horizontal, 20).padding(.top, 20)

            Spacer()

            VStack(spacing: 14) {
                Text(vocabulary.english)
                    .font(.title3).foregroundStyle(.secondary)

                Text(vocabulary.korean)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
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
            .padding(.bottom, 20)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
    }

    // MARK: - Helpers

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(colorScheme == .dark ? BrandTheme.cardBackgroundDark : BrandTheme.cardBackground)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: 16, y: 8)
    }

    private var categoryBadge: some View {
        Text(vocabulary.category.isEmpty ? "General" : vocabulary.category)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(categoryColor)
            .clipShape(Capsule())
    }

    private var difficultyBadge: some View {
        let range = TOEICScoreRange.from(frequencyLevel: vocabulary.frequencyLevel)
        return Text(range.shortLabel + "점")
            .font(.caption2).fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(range.rawValue >= 4 ? Color.purple : BrandTheme.accent)
            .clipShape(Capsule())
    }

    private var categoryColor: Color {
        switch vocabulary.category.lowercased() {
        case "finance": return BrandTheme.accent
        case "hr": return .purple
        case "marketing": return .pink
        case "legal": return .red
        case "travel": return .cyan
        case "facilities": return .brown
        case "industry": return .indigo
        default: return BrandTheme.accentLight
        }
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
