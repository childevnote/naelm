//
//  BookmarkListView.swift
//  Naelm
//
//  저장한 단어 리스트 — 카테고리·품사·난이도 필터 지원
//

import SwiftUI
import SwiftData

struct BookmarkListView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarks: [BookmarkedWord] = []
    @State private var showMeaning: Bool = true
    @State private var isPro: Bool = false

    // MARK: - 필터 상태
    @State private var selectedCategory: String = "전체"
    @State private var selectedPartOfSpeech: String = "전체"
    @State private var selectedLevel: Int = 0   // 0 = 전체

    // 가능한 필터 값들 (데이터 기반으로 동적 생성)
    private var availableCategories: [String] {
        let cats = bookmarks.compactMap { $0.vocabulary?.category }.filter { !$0.isEmpty }
        return ["전체"] + Array(Set(cats)).sorted()
    }
    private var availablePartsOfSpeech: [String] {
        let parts = bookmarks.compactMap { $0.vocabulary?.partOfSpeech }
            .flatMap { $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { !$0.isEmpty }
        return ["전체"] + Array(Set(parts)).sorted()
    }
    private var availableLevels: [Int] {
        let levels = bookmarks.compactMap { $0.vocabulary?.frequencyLevel }
        return Array(Set(levels)).sorted()
    }

    private var levelLabel: [Int: String] { [1: "Level 1", 2: "Level 2", 3: "Level 3", 4: "Level 4", 5: "Level 5"] }

    // MARK: - 필터 적용 결과
    private var filteredBookmarks: [BookmarkedWord] {
        bookmarks.filter { bm in
            guard let vocab = bm.vocabulary else { return false }
            let catOK = selectedCategory == "전체" || vocab.category == selectedCategory
            let posOK = selectedPartOfSpeech == "전체" || vocab.partOfSpeech
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .contains(selectedPartOfSpeech)
            let lvlOK = selectedLevel == 0 || vocab.frequencyLevel == selectedLevel
            return catOK && posOK && lvlOK
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !isPro {
                    SubscriptionGateView(onSubscriptionDismiss: { loadProStatus() })
                        .environment(authManager)
                } else {
                    bookmarkContent
                }
            }
            .navigationTitle("저장한 단어")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadBookmarks(); loadProStatus() }
        }
    }

    private var bookmarkContent: some View {
        VStack(spacing: 0) {
            // 뜻 보기 토글 + 카운트
            HStack {
                Text("저장한 단어 \(filteredBookmarks.count)개")
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

            // 필터 스크롤 바
            filterBar

            if filteredBookmarks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(bookmarks.isEmpty ? "저장한 단어가 없어요" : "조건에 맞는 단어가 없어요")
                        .font(.title3).fontWeight(.semibold)
                    if bookmarks.isEmpty {
                        Text("단어 학습 중 저장하기 버튼을 눌러\n단어를 저장해보세요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredBookmarks, id: \.wordID) { bm in
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
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 카테고리
                Menu {
                    ForEach(availableCategories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            if selectedCategory == cat {
                                Label(cat, systemImage: "checkmark")
                            } else {
                                Text(cat)
                            }
                        }
                    }
                } label: {
                    filterChip(
                        label: selectedCategory == "전체" ? "카테고리" : selectedCategory,
                        isActive: selectedCategory != "전체"
                    )
                }

                // 품사
                Menu {
                    ForEach(availablePartsOfSpeech, id: \.self) { pos in
                        Button {
                            selectedPartOfSpeech = pos
                        } label: {
                            if selectedPartOfSpeech == pos {
                                Label(pos, systemImage: "checkmark")
                            } else {
                                Text(pos)
                            }
                        }
                    }
                } label: {
                    filterChip(
                        label: selectedPartOfSpeech == "전체" ? "품사" : selectedPartOfSpeech,
                        isActive: selectedPartOfSpeech != "전체"
                    )
                }

                // 난이도
                Menu {
                    Button {
                        selectedLevel = 0
                    } label: {
                        if selectedLevel == 0 {
                            Label("전체", systemImage: "checkmark")
                        } else {
                            Text("전체")
                        }
                    }
                    ForEach(availableLevels, id: \.self) { lv in
                        Button {
                            selectedLevel = lv
                        } label: {
                            if selectedLevel == lv {
                                Label(levelLabel[lv] ?? "Lv.\(lv)", systemImage: "checkmark")
                            } else {
                                Text(levelLabel[lv] ?? "Lv.\(lv)")
                            }
                        }
                    }
                } label: {
                    filterChip(
                        label: selectedLevel == 0 ? "난이도" : (levelLabel[selectedLevel] ?? "Lv.\(selectedLevel)"),
                        isActive: selectedLevel != 0
                    )
                }

                // 필터 초기화
                if selectedCategory != "전체" || selectedPartOfSpeech != "전체" || selectedLevel != 0 {
                    Button {
                        selectedCategory = "전체"
                        selectedPartOfSpeech = "전체"
                        selectedLevel = 0
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("초기화")
                        }
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.red.opacity(0.1)))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption).fontWeight(.medium)
            Image(systemName: "chevron.down")
                .font(.system(size: 9))
        }
        .foregroundStyle(isActive ? .white : .primary)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(
            Capsule().fill(isActive ? BrandTheme.accent : Color(.secondarySystemBackground))
        )
    }

    // MARK: - Row

    private func bookmarkRow(vocab: Vocabulary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(vocab.english)
                    .font(.headline).fontWeight(.bold)

                // 품사 (여러 개일 때 모두 표시)
                let parts = vocab.partOfSpeech
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                ForEach(parts, id: \.self) { pos in
                    Text(pos)
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
                // 여러 의미를 줄바꿈으로 구분
                let meanings = vocab.korean
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if meanings.count > 1 {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(meanings.enumerated()), id: \.offset) { idx, meaning in
                            Text("\(idx + 1). \(meaning)")
                                .font(.subheadline).foregroundStyle(BrandTheme.accent)
                        }
                    }
                } else {
                    Text(vocab.korean)
                        .font(.subheadline).foregroundStyle(BrandTheme.accent)
                }

                if !vocab.exampleSentence.isEmpty {
                    highlightedExampleText(sentence: vocab.exampleSentence, keyword: vocab.english)
                        .font(.caption).italic()
                        .lineLimit(2)
                }
            } else {
                Text("???")
                    .font(.subheadline).foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Highlighted Example Text

    private func highlightedExampleText(sentence: String, keyword: String) -> Text {
        guard !keyword.isEmpty,
              let range = sentence.range(of: keyword, options: .caseInsensitive) else {
            return Text(sentence).foregroundStyle(.secondary)
        }

        var attributed = AttributedString(sentence)
        if let attrRange = attributed.range(of: keyword, options: .caseInsensitive) {
            attributed[attrRange].foregroundColor = UIColor(BrandTheme.accent)
            attributed[attrRange].font = .subheadline.bold()
        }

        attributed.foregroundColor = .secondaryLabel
        if let attrRange = attributed.range(of: keyword, options: .caseInsensitive) {
            attributed[attrRange].foregroundColor = UIColor(BrandTheme.accent)
            attributed[attrRange].font = .subheadline.bold()
        }
        return Text(attributed)
    }

    // MARK: - Data

    private func loadProStatus() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<UserProfile> { $0.userID == userID }
        isPro = (try? modelContext.fetch(FetchDescriptor<UserProfile>(predicate: predicate)).first?.isProActive) ?? false
    }

    private func loadBookmarks() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<BookmarkedWord> { $0.userID == userID }
        let descriptor = FetchDescriptor<BookmarkedWord>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        bookmarks = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        // filteredBookmarks 기준 인덱스를 원본 bookmarks 인덱스로 변환
        let itemsToDelete = offsets.map { filteredBookmarks[$0] }
        for item in itemsToDelete {
            if let idx = bookmarks.firstIndex(where: { $0.wordID == item.wordID }) {
                modelContext.delete(bookmarks[idx])
                bookmarks.remove(at: idx)
            }
        }
        try? modelContext.save()
    }
}
