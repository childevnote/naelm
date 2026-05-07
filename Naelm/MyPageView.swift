//
//  MyPageView.swift
//  Naelm
//
//  마이페이지 — 수준, 목표점수, 연속학습일, 문제유형 그래프
//

import SwiftUI
import SwiftData

// MARK: - MyPageTab

enum MyPageTab: String, CaseIterable {
    case profile = "내 정보"
    case friends = "친구"
}

struct MyPageView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // ViewModel — 데이터/로직 전담
    @State private var viewModel: MyPageViewModel?

    // 탭 선택
    @State private var selectedMyPageTab: MyPageTab = .profile

    // UI 전용 상태
    @State private var showTargetScorePicker: Bool = false
    @State private var selectedTargetScore: Int = 700

    /// 닉네임 미설정 유저 → 닉네임 설정 Sheet 표시
    @State private var showNicknameSetup: Bool = false

    // ViewModel에서 읽는 편의 프로퍼티
    private var profile: UserProfile? { viewModel?.profile }
    private var streak: Int { viewModel?.streak ?? 0 }
    private var totalXP: Int { viewModel?.totalXP ?? 0 }
    private var categoryCorrect: [String: Int] { viewModel?.categoryCorrect ?? [:] }
    private var categoryIncorrect: [String: Int] { viewModel?.categoryIncorrect ?? [:] }

    // 응원 배너 (30개 - 매일 하나씩)
    private static let encouragements: [String] = [
        "오늘도 좋은 하루 되세요! ☀️",
        "꾸준한 학습이 실력을 만들어요 💪",
        "한 걸음씩, 목표에 가까워지고 있어요 🎯",
        "오늘의 노력이 내일의 점수가 돼요 📈",
        "당신의 도전을 응원합니다! 🌟",
        "작은 습관이 큰 변화를 만들어요 🌱",
        "포기하지 않는 당신이 최고예요 🏆",
        "매일 조금씩, 반드시 성장해요 🚀",
        "오늘의 학습이 내일의 자신감이 돼요 ✨",
        "토익 목표 달성, 충분히 가능해요! 💡",
        "지금 이 순간도 성장 중이에요 🌿",
        "단어 하나하나가 점수로 쌓여요 📚",
        "어제보다 오늘 더 나은 당신 👍",
        "꾸준함이 재능을 이겨요! 🔥",
        "오늘도 멋진 하루 만들어봐요 🌈",
        "실수해도 괜찮아요, 그게 학습이에요 😊",
        "당신의 노력은 반드시 결실을 맺어요 🌸",
        "영어 실력, 매일 조금씩 올라가고 있어요 📊",
        "목표를 향해 꾸준히! 응원해요 🎉",
        "오늘도 한 걸음 더 나아가는 당신! 👣",
        "스스로를 믿으세요, 할 수 있어요 💎",
        "새벽을 달리는 당신의 열정이 빛나요 🌙",
        "지금 당장 결과가 안 보여도, 쌓이고 있어요 ⏳",
        "학습의 즐거움을 느끼는 하루 되세요 🎵",
        "최고의 투자는 자기 자신에게! 💰",
        "원하는 점수, 반드시 나올 거예요 🎊",
        "매일 학습하는 당신은 이미 승리자예요 🏅",
        "오늘의 복습이 장기 기억의 열쇠예요 🔑",
        "끝까지 해내는 당신을 믿어요! 💫",
        "작은 도전들이 모여 큰 성취를 만들어요 🌊",
    ]
    private var dailyEncouragementIndex: Int {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return (dayOfYear - 1) % Self.encouragements.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── 탭 선택 Picker ────────────────────────────────
                    Picker("", selection: $selectedMyPageTab) {
                        ForEach(MyPageTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    if selectedMyPageTab == .profile {
                        // ── 내 정보 탭 콘텐츠 ──────────────────────────
                        MyPageHeaderView(
                            nickname: profile?.nickname ?? "",
                            encouragement: Self.encouragements[dailyEncouragementIndex]
                        )
                        ProfileCardView(profile: profile, streak: streak, totalXP: totalXP)
                        GoalSectionView(profile: profile) {
                            if let p = profile {
                                selectedTargetScore = p.targetScore
                            }
                            showTargetScorePicker = true
                        }
                        QuizCategoryChartView(
                            categoryCorrect: categoryCorrect,
                            categoryIncorrect: categoryIncorrect
                        )
                        timerSettings
                    } else {
                        // ── 친구 탭 콘텐츠 ────────────────────────────
                        FriendTabView(showNicknameSetup: $showNicknameSetup)
                            .environment(authManager)
                            .onAppear {
                                // 친구 탭 진입 시 닉네임 미설정 확인
                                checkNicknameSetup()
                            }
                    }
                }
                .padding(.horizontal, selectedMyPageTab == .profile ? 16 : 0)
                .padding(.bottom, 16)
            }
            .background(AppGradient.background(scheme: colorScheme).ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 첫 렌더링 완료 후 무거운 데이터 로드 → 진입 딜레이 제거
                DispatchQueue.main.async { loadData() }
            }
            .sheet(isPresented: $showTargetScorePicker) {
                TargetScorePickerSheetView(
                    selectedTargetScore: $selectedTargetScore,
                    onCancel: { showTargetScorePicker = false },
                    onConfirm: {
                        updateTargetScore(selectedTargetScore)
                        showTargetScorePicker = false
                    }
                )
            }
            .sheet(isPresented: $showNicknameSetup) {
                NicknameSetupView { _ in
                    showNicknameSetup = false
                }
                .environment(authManager)
                .presentationDetents([.medium, .large])
            }
        }
    }

    /// 친구 탭 진입 시 닉네임 설정 여부 확인
    private func checkNicknameSetup() {
        guard let myID = authManager.userID,
              !myID.hasPrefix("guest_") else { return }
        let predicate = #Predicate<UserProfile> { $0.userID == myID }
        let descriptor = FetchDescriptor<UserProfile>(predicate: predicate)
        if let profile = try? modelContext.fetch(descriptor).first,
           profile.nickname.isEmpty {
            showNicknameSetup = true
        }
    }

    // MARK: - Timer Settings
    private var timerSettings: some View {
        EmptyView()
    }

    // MARK: - Data

    private func loadData() {
        // ViewModel이 없으면 생성 (onAppear 최초 1회)
        if viewModel == nil {
            viewModel = MyPageViewModel(modelContext: modelContext, authManager: authManager)
        }
        viewModel?.loadData()
    }

    private func updateTargetScore(_ newScore: Int) {
        viewModel?.updateTargetScore(newScore)
    }
}
