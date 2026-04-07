//
//  SwipeableCardStack.swift
//  Toeigo
//
//  단일 카드 스와이프 컴포넌트 v3.
//  ──────────────────────────────────────────────
//  설계 원칙:
//    · 화면에는 항상 카드 1장만 보임 (뒤에 희미한 다음 카드 힌트)
//    · 스와이프/버튼 처리 완료 전까지 모든 입력 잠금
//    · 오버레이(알고있어요/학습할게요) 표시 → 카드 날아감 → 다음 카드 페이드인
//    · items 변경 시 currentIndex 자동 리셋 (복습 무한루프 지원)
//  ──────────────────────────────────────────────

import SwiftUI

enum SwipeDirection {
    case left   // 알고있어요
    case right  // 학습할게요
}

struct SwipeableCardStack<Item: Identifiable, CardContent: View>: View {

    let items: [Item]
    let onSwiped: (Item, SwipeDirection) -> Void
    let onAllSwiped: () -> Void
    @ViewBuilder let cardContent: (Item) -> CardContent

    @Binding var externalSwipeTrigger: UUID

    /// 카드와 버튼 사이에 표시할 추가 뷰 (현재 아이템 전달)
    var bookmarkContent: ((Item) -> AnyView)? = nil

    // MARK: - State

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1.0
    @State private var isLocked: Bool = false       // 입력 완전 잠금
    @State private var showOverlay: Bool = false
    @State private var overlayDirection: SwipeDirection = .left
    @State private var hapticFired: Bool = false
    @State private var itemsID: String = ""          // items 변경 감지용

    private let swipeThreshold: CGFloat = 90
    private let flyDistance: CGFloat = 700

    init(
        items: [Item],
        externalSwipeTrigger: Binding<UUID> = .constant(UUID()),
        onSwiped: @escaping (Item, SwipeDirection) -> Void,
        onAllSwiped: @escaping () -> Void,
        bookmarkContent: ((Item) -> AnyView)? = nil,
        @ViewBuilder cardContent: @escaping (Item) -> CardContent
    ) {
        self.items = items
        self._externalSwipeTrigger = externalSwipeTrigger
        self.onSwiped = onSwiped
        self.onAllSwiped = onAllSwiped
        self.bookmarkContent = bookmarkContent
        self.cardContent = cardContent
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // ── 다음 카드 (뒤에 희미하게) ──────────────────
                if currentIndex + 1 < items.count {
                    cardContent(items[currentIndex + 1])
                        .scaleEffect(0.94)
                        .opacity(0.35)
                        .offset(y: 14)
                        .allowsHitTesting(false)
                        // 드래그 중에만 약간 앞으로 나오는 효과
                        .scaleEffect(dragProgress > 0 ? 0.94 + dragProgress * 0.06 : 0.94)
                        .animation(.easeOut(duration: 0.15), value: dragProgress)
                }

                // ── 현재 카드 ───────────────────────────────────
                if currentIndex < items.count {
                    cardContent(items[currentIndex])
                        .overlay(swipeOverlayView)
                        .offset(x: dragOffset.width, y: dragOffset.height * 0.12)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 18))
                        .opacity(cardOpacity)
                        .scaleEffect(isLocked && showOverlay ? 0.97 : 1.0)
                        .animation(isLocked ? nil : .interpolatingSpring(stiffness: 320, damping: 26), value: dragOffset)
                        .gesture(isLocked ? nil : dragGesture)
                        .allowsHitTesting(!isLocked)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: externalSwipeTrigger) { _, _ in
                guard !isLocked else { return }
                performSwipe(direction: .right)
            }
            // items 배열이 교체되면 (복습 라운드 변경) currentIndex 리셋
            .onChange(of: itemsID) { _, _ in
                currentIndex = 0
                dragOffset = .zero
                cardOpacity = 1.0
                isLocked = false
            }
            .onAppear {
                itemsID = items.map { "\($0.id)" }.joined()
            }
            .onChange(of: items.count) { _, _ in
                let newID = items.map { "\($0.id)" }.joined()
                if newID != itemsID { itemsID = newID }
            }

            // ── 저장 버튼 슬롯 ──────────────────────────────
            if currentIndex < items.count, let bm = bookmarkContent {
                bm(items[currentIndex])
                    .opacity(isLocked ? 0.4 : 1.0)
                    .allowsHitTesting(!isLocked)
            }

            // ── 버튼 영역 ────────────────────────────────────
            if currentIndex < items.count {
                actionButtons
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Swipe Overlay

    @ViewBuilder
    private var swipeOverlayView: some View {
        if isDragging || (isLocked && showOverlay) {
            let dir: SwipeDirection = isLocked ? overlayDirection : (dragOffset.width > 0 ? .right : .left)
            let opacity: Double = isLocked ? 1.0 : min(1, abs(Double(dragOffset.width)) / Double(swipeThreshold))

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        dir == .left ? BrandTheme.knewIt.opacity(opacity * 0.3) : BrandTheme.studyIt.opacity(opacity * 0.3)
                    )

                VStack(spacing: 10) {
                    Image(systemName: dir == .left ? "checkmark.seal.fill" : "bookmark.fill")
                        .font(.system(size: 56, weight: .bold))
                    Text(dir == .left ? "알고있어요!" : "학습할게요")
                        .font(.title2).fontWeight(.heavy)
                }
                .foregroundStyle(dir == .left ? BrandTheme.knewIt : BrandTheme.studyIt)
                .opacity(opacity)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: - Drag helpers

    private var isDragging: Bool { dragOffset != .zero && !isLocked }

    private var dragProgress: Double {
        min(1.0, abs(Double(dragOffset.width)) / Double(swipeThreshold))
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = value.translation
                let ratio = abs(value.translation.width) / swipeThreshold
                if ratio > 0.7 && !hapticFired {
                    hapticFired = true
                    HapticManager.shared.playSwipe()
                }
                if ratio < 0.4 { hapticFired = false }
            }
            .onEnded { value in
                hapticFired = false
                if value.translation.width > swipeThreshold {
                    performSwipe(direction: .right)
                } else if value.translation.width < -swipeThreshold {
                    performSwipe(direction: .left)
                } else {
                    // 취소 — 제자리로
                    withAnimation(.interpolatingSpring(stiffness: 350, damping: 28)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Swipe 실행 (버튼 + 드래그 + 외부 트리거 공통)

    private func performSwipe(direction: SwipeDirection) {
        guard currentIndex < items.count, !isLocked else { return }
        isLocked = true
        overlayDirection = direction
        HapticManager.shared.playSwipeComplete()

        // 1) 드래그 오프셋 즉시 해제 (이미 손가락 뗀 상태)
        withAnimation(.easeOut(duration: 0.05)) {
            dragOffset = .zero
        }

        // 2) 오버레이 표시 (0.35초)
        withAnimation(.easeIn(duration: 0.1)) {
            showOverlay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // 3) 카드 날아가기
            let flyX: CGFloat = direction == .right ? flyDistance : -flyDistance
            withAnimation(.easeIn(duration: 0.22)) {
                dragOffset = CGSize(width: flyX, height: 0)
                cardOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                // 4) 콜백 호출 + 인덱스 증가
                let item = items[currentIndex]
                onSwiped(item, direction)
                currentIndex += 1
                dragOffset = .zero
                cardOpacity = 0
                showOverlay = false

                if currentIndex >= items.count {
                    // 완료
                    isLocked = false
                    onAllSwiped()
                } else {
                    // 5) 다음 카드 페이드인
                    withAnimation(.easeOut(duration: 0.25)) {
                        cardOpacity = 1.0
                    }
                    isLocked = false
                }
            }
        }
    }

    // MARK: - Trigger (버튼용)

    private func triggerSwipe(direction: SwipeDirection) {
        performSwipe(direction: direction)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { triggerSwipe(direction: .left) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 20))
                    Text("알고있어요").font(.subheadline).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isLocked ? BrandTheme.knewIt.opacity(0.4) : BrandTheme.knewIt)
                        .shadow(color: BrandTheme.knewIt.opacity(0.3), radius: 6, y: 3)
                )
            }
            .disabled(isLocked)

            Button { triggerSwipe(direction: .right) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill").font(.system(size: 20))
                    Text("학습할게요").font(.subheadline).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isLocked ? BrandTheme.studyIt.opacity(0.4) : BrandTheme.studyIt)
                        .shadow(color: BrandTheme.studyIt.opacity(0.3), radius: 6, y: 3)
                )
            }
            .disabled(isLocked)
        }
        .padding(.horizontal, 20)
        // 잠금 중 블러 처리
        .blur(radius: isLocked ? 1.5 : 0)
        .animation(.easeInOut(duration: 0.15), value: isLocked)
    }
}
