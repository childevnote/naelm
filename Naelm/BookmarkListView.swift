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
            bookmarkContent
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("저장한 단어")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadBookmarks() }
        }
    }

    private var bookmarkContent: some View {
        VStack(spacing: 0) {
            // 뜻 보기 토글 + 카운트
            HStack {
                Text("저장한 단어 \(filteredBookmarks.count)개")
                    .font(.pretendardMedium(14)).foregroundStyle(.secondary)
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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredBookmarks, id: \.wordID) { bm in
                            if let vocab = bm.vocabulary {
                                bookmarkRow(vocab: vocab)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteBookmark(bm)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
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
        VStack(alignment: .leading, spacing: 10) {
            // 상단: 영어 단어 + 품사 뱃지 + 발음기호
            HStack(alignment: .center, spacing: 6) {
                Text(vocab.english)
                    .font(.pretendardBold(18))
                    .foregroundStyle(.primary)

                let parts = vocab.partOfSpeech
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                ForEach(parts, id: \.self) { pos in
                    Text(pos)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BrandTheme.accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(
                            Capsule().fill(BrandTheme.accent.opacity(0.12))
                        )
                }

                Spacer()

                if !vocab.pronunciation.isEmpty {
                    Text(vocab.pronunciation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if showMeaning {
                // 뜻 영역
                let meanings = vocab.korean
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if meanings.count > 1 {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(meanings.enumerated()), id: \.offset) { idx, meaning in
                            HStack(spacing: 6) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(BrandTheme.accent.opacity(0.7)))
                                Text(meaning)
                                    .font(.pretendardSemiBold(14))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } else {
                    Text(vocab.korean)
                        .font(.pretendardSemiBold(15))
                        .foregroundStyle(BrandTheme.accent)
                }

                // 예문
                if !vocab.exampleSentence.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        highlightedExampleText(sentence: vocab.exampleSentence, keyword: vocab.english)
                            .font(.caption).italic()
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
            } else {
                // 뜻 숨김 상태
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), BrandTheme.accent.opacity(0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), BrandTheme.accent.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
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

    private func loadBookmarks() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<BookmarkedWord> { $0.userID == userID }
        let descriptor = FetchDescriptor<BookmarkedWord>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        bookmarks = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func deleteBookmark(_ item: BookmarkedWord) {
        if let idx = bookmarks.firstIndex(where: { $0.wordID == item.wordID }) {
            modelContext.delete(bookmarks[idx])
            bookmarks.remove(at: idx)
        }
        try? modelContext.save()
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
