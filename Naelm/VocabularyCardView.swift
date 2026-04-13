//
//  VocabularyCardView.swift
//  Naelm
//
//  단어 카드 UI — 3D 플립, meanings 배열 우선 표시, 다크모드 대응.
//

import SwiftUI

struct VocabularyCardView: View {

    let vocabulary: Vocabulary
    var onFlip: ((Bool) -> Void)? = nil

    @State private var isFlipped: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private let cardHeight: CGFloat = 460

    // meanings 배열 정렬 (order 순서대로)
    private var sortedMeanings: [VocabularyMeaning] {
        vocabulary.meanings.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            cardBack()
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.3
                )
                .allowsHitTesting(isFlipped)

            cardFront()
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.3
                )
                .allowsHitTesting(!isFlipped)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isFlipped.toggle()
            }
            onFlip?(isFlipped)
            HapticManager.shared.playTap()
        }
    }

    // MARK: - Front

    private func cardFront() -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text(vocabulary.english)
                    .font(.cardWordTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                if !vocabulary.pronunciation.isEmpty {
                    Text(vocabulary.pronunciation)
                        .font(.pronunciation)
                        .foregroundStyle(.secondary)
                }
                let posList = posBadges
                if !posList.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(posList, id: \.self) { pos in
                            Text(pos)
                                .font(.badge)
                                .foregroundStyle(BrandTheme.accent)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(BrandTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                Text("탭하여 뜻 보기")
            }
            .font(.caption).foregroundStyle(.tertiary)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.quaternary, lineWidth: 1))
    }

    // MARK: - Back

    private func cardBack() -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            ScrollView {
                VStack(spacing: 16) {
                    Text(vocabulary.english)
                        .font(.pretendardMedium(17)).foregroundStyle(.secondary)
                    if sortedMeanings.isEmpty {
                        singleMeaningContent
                    } else {
                        multiMeaningContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            Spacer(minLength: 8)
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
            .font(.pretendard(12))
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(cardBg)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.quaternary, lineWidth: 1))
    }

    // MARK: - Single Meaning

    @ViewBuilder
    private var singleMeaningContent: some View {
        if !vocabulary.partOfSpeech.isEmpty {
            let parts = vocabulary.partOfSpeech
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            HStack(spacing: 6) {
                ForEach(parts, id: \.self) { pos in
                    Text(pos)
                        .font(.badge)
                        .foregroundStyle(BrandTheme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(BrandTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        let koreanParts = vocabulary.korean
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        VStack(spacing: 4) {
            ForEach(Array(koreanParts.enumerated()), id: \.offset) { idx, meaning in
                Text(koreanParts.count > 1 ? "\(idx + 1). \(meaning)" : meaning)
                    .font(koreanParts.count > 1 ? .cardMeaningMedium : .cardMeaningLarge)
                    .foregroundStyle(.primary)
            }
        }
        .multilineTextAlignment(.center)
        if !vocabulary.exampleSentence.isEmpty {
            Divider().padding(.horizontal, 20)
            exampleBlock(sentence: vocabulary.exampleSentence, translation: vocabulary.exampleTranslation)
        }
        if !vocabulary.synonyms.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "equal.circle").font(.caption2)
                Text(vocabulary.synonyms).font(.caption)
            }
            .font(.pretendard(12))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Multi Meaning

    @ViewBuilder
    private var multiMeaningContent: some View {
        ForEach(Array(sortedMeanings.enumerated()), id: \.element.meaningID) { idx, meaning in
            VStack(alignment: .leading, spacing: 6) {
                if !meaning.pos.isEmpty {
                    Text(meaning.pos)
                        .font(.badge)
                        .foregroundStyle(BrandTheme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(BrandTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(meaning.korean)
                    .font(.cardMeaningSmall)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !meaning.exampleSentence.isEmpty {
                    exampleBlock(sentence: meaning.exampleSentence, translation: meaning.exampleTranslation)
                }
                if !meaning.synonyms.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "equal.circle").font(.caption2)
                        Text(meaning.synonyms).font(.pretendard(12))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if idx < sortedMeanings.count - 1 {
                Divider().padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Example Block

    @ViewBuilder
    private func exampleBlock(sentence: String, translation: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(sentence)
                .font(.exampleSentence).italic()
                .foregroundStyle(.primary.opacity(0.8))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !translation.isEmpty {
                Text(translation)
                    .font(.exampleTranslation).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    private var posBadges: [String] {
        if !sortedMeanings.isEmpty {
            return Array(Set(sortedMeanings.map(\.pos).filter { !$0.isEmpty })).sorted()
        }
        return vocabulary.partOfSpeech
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

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
}
