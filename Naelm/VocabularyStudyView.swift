//
//  VocabularyStudyView.swift
//  Naelm
//
//  단어 학습 탭 — 스와이프 카드 + 15초 타이머 + 오늘 학습 카운트
//

import SwiftUI
import SwiftData

struct VocabularyStudyView: View {

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CardViewModel
    @State private var sessionManager: LearningSessionManager
    @State private var cardStackID = UUID()
    @State private var speedFeedback: String? = nil
    @State private var autoSwipeTrigger = UUID()
    @State private var bookmarkedIDs: Set<String> = []
    @State private var showLeaveAlert = false
    @State private var lessonResult: LessonResult? = nil
    @State private var showLessonComplete = false
    var isSessionActive: Bool {
        !viewModel.cardDeck.isEmpty && !viewModel.isSessionComplete && !viewModel.isLoading
    }

    init() {
        let sm = LearningSessionManager()
        _sessionManager = State(initialValue: sm)
        _viewModel = State(initialValue: CardViewModel(sessionManager: sm))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? BrandTheme.backgroundGradientDark : BrandTheme.backgroundGradient)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("카드 준비 중...")
                } else if showLessonComplete, let result = lessonResult {
                    LessonCompleteView(result: result) {
                        showLessonComplete = false
                        // 복습 가능하면 복습, 없으면 홈으로
                        if viewModel.hasReviewWords(context: modelContext) {
                            viewModel.loadReviewDeck(context: modelContext)
                            cardStackID = UUID()
                        } else {
                            dismiss()
                        }
                    }
                } else if viewModel.isSessionComplete {
                    // 완료 직후 LessonCompleteView로 전환 전 빈 상태
                    Color.clear
                        .onAppear { buildAndShowResult() }
                } else if viewModel.cardDeck.isEmpty {
                    emptyDeckView
                } else {
                    VStack(spacing: 0) {
                        // 타이머 바 (활성화된 경우만 표시)
                        if viewModel.timerEnabled {
                            timerBar
                                .padding(.top, 4)
                        } else {
                            Spacer().frame(height: 10)
                        }

                        // n/m 진행 표시
                        if !viewModel.cardDeck.isEmpty {
                            Text("\(viewModel.sessionStats.wordsStudied + 1)/\(viewModel.cardDeck.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }

                        SwipeableCardStack(
                            items: viewModel.cardDeck,
                            externalSwipeTrigger: $autoSwipeTrigger,
                            onSwiped: { vocab, direction in
                                if direction == .left { showSpeedFeedback() }
                                viewModel.handleSwipe(
                                    vocabulary: vocab,
                                    direction: direction,
                                    context: modelContext
                                )
                            },
                            onAllSwiped: {
                                viewModel.handleAllCardsSwiped(context: modelContext)
                            },
                            bookmarkContent: { vocab in
                                AnyView(self.bookmarkBar(for: vocab))
                            },
                            cardContent: { vocab in
                                VocabularyCardView(
                                    vocabulary: vocab,
                                    onFlip: { isFlipped in
                                        if isFlipped { viewModel.pauseTimer() }
                                        else { viewModel.resumeTimer() }
                                    }
                                )
                            }
                        )
                        .id(cardStackID)
                    }
                }

                // 속도 피드백 토스트
                if let feedback = speedFeedback {
                    VStack {
                        Text(feedback)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(BrandTheme.accent.opacity(0.85)))
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("단어 학습")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isSessionActive)
            .toolbar {
                if isSessionActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showLeaveAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("나가기")
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .toolbar(isSessionActive ? .hidden : .visible, for: .tabBar)
            .onAppear {
                if viewModel.cardDeck.isEmpty && !viewModel.isSessionComplete {
                    loadDeck()
                }
                loadBookmarkIDs()
                viewModel.onTimerExpired = {
                    guard viewModel.timerEnabled else { return }
                    autoSwipeTrigger = UUID()
                }
            }
            .onDisappear {
                viewModel.stopTimer()
            }
            .alert("학습을 종료할까요?", isPresented: $showLeaveAlert) {
                Button("계속 학습", role: .cancel) {}
                Button("나가기", role: .destructive) { dismiss() }
            } message: {
                Text("지금까지 학습한 내용은 저장되지 않습니다.\n저장한 단어(★)는 그대로 유지됩니다.")
            }
        }
    }

    // MARK: - Bookmark Bar (카드·버튼 사이)

    // MARK: - Bookmark Bar

    private func bookmarkBar(for vocab: Vocabulary) -> some View {
        let isBookmarked = bookmarkedIDs.contains(vocab.wordID)
        return Button {
            toggleBookmark(vocab)
            HapticManager.shared.playTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isBookmarked ? "star.fill" : "star")
                    .font(.system(size: 16))
                Text(isBookmarked ? "저장됨" : "저장하기")
                    .font(.subheadline).fontWeight(.medium)
            }
            .foregroundStyle(isBookmarked ? AppPalette.forest : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isBookmarked ? AppPalette.forest.opacity(0.10) : Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }

    // MARK: - Timer Bar

    private var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(timerColor)
                    .frame(width: geo.size.width * max(0, viewModel.timerRemaining / viewModel.timerDuration), height: 6)
                    .animation(.linear(duration: 0.1), value: viewModel.timerRemaining)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 20)
    }

    private var timerColor: Color {
        let ratio = viewModel.timerRemaining / viewModel.timerDuration
        if ratio > 0.66 { return AppPalette.mint }
        if ratio > 0.33 { return AppPalette.warning }
        return AppPalette.error
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            Label("\(viewModel.sessionStats.wordsStudied)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppPalette.mint)

            Spacer()

            Label("+\(viewModel.sessionStats.xpEarned) XP", systemImage: "star.fill")
                .foregroundStyle(AppPalette.gold)
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .padding(.horizontal, 24)
    }

    // MARK: - Session Complete

    private func buildAndShowResult() {
        guard let userID = authManager.userID else { dismiss(); return }
        let xp = viewModel.sessionStats.xpEarned
        let streak = GamificationService.currentStreak(userID: userID, context: modelContext)
        // 오늘 처음 학습인지 판단: 학습 전후 wordsStudied가 처음인지 체크
        let activity = GamificationService.todayActivity(userID: userID, context: modelContext)
        let isFirst = (activity?.wordsStudied ?? 0) <= viewModel.sessionStats.wordsStudied
        lessonResult = LessonResult(
            xpEarned: xp,
            isFirstStudyToday: isFirst,
            streakDays: streak,
            sessionLabel: "단어 학습"
        )
        showLessonComplete = true
    }

    // (기존 sessionCompleteView 제거 — LessonCompleteView로 대체됨)

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Empty Deck

    private var emptyDeckView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("학습할 단어가 없어요")
                .font(.title3).fontWeight(.semibold)

            Text("모든 단어를 숙달했거나,\n아직 단어 데이터가 로드되지 않았습니다.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("새로고침") { loadDeck() }
                .buttonStyle(.bordered)
                .tint(AppPalette.forest)
                .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func loadDeck() {
        guard let userID = authManager.userID else { return }
        viewModel.loadDeck(userID: userID, context: modelContext)
        cardStackID = UUID()
    }

    private func showSpeedFeedback() {
        let elapsed = viewModel.timerDuration - viewModel.timerRemaining
        let ratio = elapsed / viewModel.timerDuration
        let msg: String
        if ratio <= 0.4 { msg = "빠르네요!" }
        else if ratio <= 0.7 { msg = "적절해요." }
        else { msg = "느리네요." }

        withAnimation(.easeInOut(duration: 0.25)) { speedFeedback = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { speedFeedback = nil }
        }
    }

    // MARK: - Bookmarks

    private func loadBookmarkIDs() {
        guard let userID = authManager.userID else { return }
        let predicate = #Predicate<BookmarkedWord> { $0.userID == userID }
        let bms = (try? modelContext.fetch(FetchDescriptor<BookmarkedWord>(predicate: predicate))) ?? []
        bookmarkedIDs = Set(bms.map(\.wordID))
    }

    private func toggleBookmark(_ vocab: Vocabulary) {
        guard let userID = authManager.userID else { return }
        let wordID = vocab.wordID
        if bookmarkedIDs.contains(wordID) {
            // 제거
            let predicate = #Predicate<BookmarkedWord> { $0.userID == userID && $0.wordID == wordID }
            if let bm = try? modelContext.fetch(FetchDescriptor<BookmarkedWord>(predicate: predicate)).first {
                modelContext.delete(bm)
            }
            bookmarkedIDs.remove(wordID)
        } else {
            // 추가
            let bm = BookmarkedWord(userID: userID, wordID: wordID, vocabulary: vocab)
            modelContext.insert(bm)
            bookmarkedIDs.insert(wordID)
        }
        try? modelContext.save()
    }
}
