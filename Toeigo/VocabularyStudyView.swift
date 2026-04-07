//
//  VocabularyStudyView.swift
//  Toeigo
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
                } else if viewModel.isSessionComplete {
                    sessionCompleteView
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
                    guard viewModel.timerEnabled else { return }
                    guard viewModel.timerEnabled else { return }
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
                Text("지금까지 학습한 내용이 저장되지 않습니다.")
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
            .foregroundStyle(isBookmarked ? BrandTheme.accent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isBookmarked ? BrandTheme.accent.opacity(0.1) : Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)   currentCardIndex = new
        }
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
        if ratio > 0.66 { return BrandTheme.knewIt }
        if ratio > 0.33 { return .orange }
        return .red
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            Label("\(viewModel.sessionStats.wordsStudied)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(BrandTheme.knewIt)

            Spacer()

            Label("+\(viewModel.sessionStats.xpEarned) XP", systemImage: "star.fill")
                .foregroundStyle(BrandTheme.studyIt)
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .padding(.horizontal, 24)
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 72))
                .foregroundStyle(BrandTheme.studyIt)

            Text("학습 완료!")
                .font(.title).fontWeight(.bold)

            // 오늘 진행률
            let progress = min(1.0, Double(viewModel.todayWordCount) / Double(viewModel.dailyGoal))
            VStack(spacing: 8) {
                Text("오늘 \(viewModel.todayWordCount)/\(viewModel.dailyGoal)개 학습")
                    .font(.headline)
                ProgressView(value: progress)
                    .tint(BrandTheme.accent)
                    .frame(maxWidth: 200)
            }

            VStack(spacing: 12) {
                statRow(icon: "character.book.closed", label: "학습한 단어", value: "\(viewModel.sessionStats.wordsStudied)개")
                statRow(icon: "checkmark.circle", label: "알고있어요", value: "\(viewModel.sessionStats.correctCount)개")
                statRow(icon: "bookmark", label: "학습할게요", value: "\(viewModel.sessionStats.incorrectCount)개")
                statRow(icon: "star.fill", label: "획득 XP", value: "+\(viewModel.sessionStats.xpEarned)")
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            .padding(.horizontal, 32)

            Spacer()

            // 복습할 단어가 있으면 → 복습 진행, 없으면 → 새 단어 학습
            if viewModel.hasReviewWords(context: modelContext) {
                Button {
                    viewModel.loadReviewDeck(context: modelContext)
                    cardStackID = UUID()
                } label: {
                    Label("복습 진행하기", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button {
                    loadDeck()
                } label: {
                    Label("다른 단어 학습하기", systemImage: "arrow.right.circle")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent)
            }

            Button {
                dismiss()
            } label: {
                Label("홈으로", systemImage: "house.fill")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(BrandTheme.accent)

            Spacer().frame(height: 40)
        }
    }

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
                .tint(BrandTheme.accent)
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
