//
//  BookmarkListView.swift
//  Toeigo
//
//  저장한 단어 리스트 — 심플한 리스트 + 뜻 보기 토글
//

import SwiftUI
import SwiftData

struct BookmarkListView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarks: [BookmarkedWord] = []
    @State private var showMeaning: Bool = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 뜻 보기 토글
                HStack {
                    Text("저장한 단어 \(bookmarks.count)개")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("뜻 보기", isOn: $showMeaning)
                        .font(.subheadline)
                        .labelsHidden()
                    Text("뜻 보기")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                if bookmarks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "star")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("저장한 단어가 없어요")
                            .font(.title3).fontWeight(.semibold)
                        Text("단어 학습 중 별 아이콘을 눌러\n단어를 저장해보세요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(bookmarks, id: \.wordID) { bm in
                            if let vocab = bm.vocabulary {
                                bookmarkRow(vocab: vocab)
                            }
                        }
                        .onDelete { indexSet in
                            deleteBookmarks(at: indexSet)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("저장한 단어")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadBookmarks() }
        }
    }

    private func bookmarkRow(vocab: Vocabulary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(vocab.english)
                    .font(.headline).fontWeight(.bold)

                if vocab.hasMultipleMeanings {
                    // 다중 의미: 모든 품사 뱃지 표시
                    ForEach(vocab.sortedMeanings, id: \.meaningID) { meaning in
                        if !meaning.pos.isEmpty {
                            Text(meaning.pos)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(BrandTheme.accent))
                        }
                    }
                } else {
                    Text(vocab.partOfSpeech)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(BrandTheme.accent))
                }

                Spacer()

                if !vocab.pronunciation.isEmpty {
                    Text(vocab.pronunciation)
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            if showMeaning {
                if vocab.hasMultipleMeanings {
                    // 다중 의미: 각 의미별로 표시
                    ForEach(vocab.sortedMeanings, id: \.meaningID) { meaning in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(meaning.pos)
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundStyle(BrandTheme.accent)
                                Text(meaning.korean)
                                    .font(.subheadline).foregroundStyle(BrandTheme.accent)
                            }

                            if !meaning.exampleSentence.isEmpty {
                                Text(meaning.exampleSentence)
                                    .font(.caption).foregroundStyle(.secondary).italic()
                                    .lineLimit(2)
                            }

                            if !meaning.synonyms.isEmpty {
                                HStack(spacing: 4) {
                                    Text("유사어:")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                    Text(meaning.synonyms)
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    // 단일 의미: 기존 표시
                    Text(vocab.korean)
                        .font(.subheadline).foregroundStyle(BrandTheme.accent)

                    if !vocab.exampleSentence.isEmpty {
                        Text(vocab.exampleSentence)
                            .font(.caption).foregroundStyle(.secondary).italic()
                            .lineLimit(2)
                    }

                    if !vocab.synonyms.isEmpty {
                        HStack(spacing: 4) {
                            Text("유사어:")
                                .font(.caption2).foregroundStyle(.tertiary)
                            Text(vocab.synonyms)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("???")
                    .font(.subheadline).foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadBookmarks() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<BookmarkedWord> { $0.userID == userID }
        let descriptor = FetchDescriptor<BookmarkedWord>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        bookmarks = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            let bm = bookmarks[index]
            modelContext.delete(bm)
        }
        bookmarks.remove(atOffsets: offsets)
        try? modelContext.save()
    }
}
