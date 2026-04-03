//
//  VocabularyStudyView.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  단어 학습 탭 — 스와이프 카드 학습 화면.
//  왼쪽 = 알고있어요 (초록), 오른쪽 = 학습할게요 (주황)
//

import SwiftUI
import SwiftData

struct VocabularyStudyView: View {

    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: CardViewModel
    @State private var sessionManager: LearningSessionManager

    init() {
        let sm = LearningSessionManager()
        _sessionManager = State(initialValue: sm)
        _viewModel = State(initialValue: CardViewModel(sessionManager: sm))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                (colorScheme == .dark ? BrandTheme.backgroundGradientDark : BrandTheme.backgroundGradient)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("카드 준비 중...")
                } else if viewModel.isSessionComplete {
                    sessionCompleteView
                } else if viewModel.cardDeck.isEmpty {
                    emptyDeckView
                } else {
                    VStack(spacing: 12) {
                        // 난이도 선택 + 진행 상황
                        difficultyPicker
                        progressHeader

                        SwipeableCardStack(
                            items: viewModel.cardDeck,
                            onSwiped: { vocab, direction in
                                viewModel.handleSwipe(
                                    vocabulary: vocab,
                                    direction: direction,
                                    context: modelContext
                                )
                            },
                            onAllSwiped: {
                                viewModel.handleAllCardsSwiped(context: modelContext)
                            }
                        ) { vocab in
                            VocabularyCardView(vocabulary: vocab)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .navigationTitle("단어 학습")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { loadDeck() } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .tint(BrandTheme.accent)
                }
            }
            .onAppear {
                if viewModel.cardDeck.isEmpty && !viewModel.isSessionComplete {
                    loadDeck()
                }
            }
        }
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        Picker("난이도", selection: Binding(
            get: { viewModel.selectedDifficulty },
            set: { newValue in
                viewModel.selectedDifficulty = newValue
                loadDeck()
            }
        )) {
            Text("전체").tag(0)
            Text("초급 ●").tag(1)
            Text("중급 ●●").tag(2)
            Text("고급 ●●●").tag(3)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            Label("\(viewModel.sessionStats.wordsStudied)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(BrandTheme.knewIt)

            Spacer()

            if !viewModel.cardDeck.isEmpty {
                Text("남은 카드: \(max(0, viewModel.cardDeck.count - viewModel.sessionStats.wordsStudied))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

            Text("학습 완료! 🎉")
                .font(.title).fontWeight(.bold)

            VStack(spacing: 12) {
                statRow(icon: "character.book.closed", label: "학습한 단어", value: "\(viewModel.sessionStats.wordsStudied)개")
                statRow(icon: "checkmark.circle", label: "알고있어요", value: "\(viewModel.sessionStats.correctCount)개")
                statRow(icon: "bookmark", label: "학습할게요", value: "\(viewModel.sessionStats.incorrectCount)개")
                statRow(icon: "percent", label: "숙달률", value: "\(Int(viewModel.sessionStats.accuracy * 100))%")
                statRow(icon: "star.fill", label: "획득 XP", value: "+\(viewModel.sessionStats.xpEarned)")
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            .padding(.horizontal, 32)

            Spacer()

            Button { loadDeck() } label: {
                Label("한 번 더 학습하기", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
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

    private func loadDeck() {
        guard let userID = authManager.userID else { return }
        viewModel.loadDeck(userID: userID, context: modelContext)
    }
}
