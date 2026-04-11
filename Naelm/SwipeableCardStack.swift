//
//  SwipeableCardStack.swift
//  Naelm
//
//  단일 카드 스와이프 컴포넌트 v4.
//  ──────────────────────────────────────────────
//  수정 포인트:
//    · 드래그 후 손 뗄 때 이미 이동한 위치에서 그대로 날아감 (되돌아오지 않음)
//    · 오버레이 → 날아감 → opacity 0 → 인덱스 증가 → 앞면으로 페이드인 순서 보장
//    · 다음 카드는 항상 앞면으로 등장 (id 기반 VocabularyCardView 재생성)
//    · 복습 세션 items 교체 시 currentIndex 리셋 (이중 트리거 방지)
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
    let cardContent: (Item) -> CardContent
    @Binding var externalSwipeTrigger: UUID
    var bookmarkContent: ((Item) -> AnyView)? = nil

    // MARK: - State

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1.0
    @State private var isLocked: Bool = false
    /// 오버레이 표시 여부 및 방향 (드래그 중 / 버튼 확정 후)
    @State private var overlayOpacity: Double = 0
    @State private var overlayDirection: SwipeDirection = .left
    @State private var hapticFired: Bool = false
    /// items 교체 감지용 (복습 무한루프)
    @State private var lastItemsID: String = ""

    private let swipeThreshold: CGFloat = 90
    private let flyDistance: CGFloat = 600

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
            GeometryReader { geo in
                ZStack {
                    // ── 다음 카드: 항상 뒤에 고정, 내용만 표시 (hitTest 없음) ──
                    nextCardView

                    // ── 현재 카드 (오버레이 포함) ───────────────────────────────
                    currentCardView
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                lastItemsID = makeItemsID()
            }
            .onChange(of: makeItemsID()) { _, newID in
                guard newID != lastItemsID else { return }
                lastItemsID = newID
                // 복습 라운드 교체: 부드럽게 리셋
                withAnimation(.easeOut(duration: 0.2)) {
                    currentIndex = 0
                    dragOffset = .zero
                    cardOpacity = 1.0
                    overlayOpacity = 0
                    isLocked = false
                }
            }
            .onChange(of: externalSwipeTrigger) { _, _ in
                guard !isLocked else { return }
                performSwipe(direction: .right, fromDrag: false, dragEndX: 0)
            }

            // ── 저장 버튼 슬롯 ──────────────────────────────────────────
            if currentIndex < items.count, let bm = bookmarkContent {
                bm(items[currentIndex])
                    .opacity(isLocked ? 0.35 : 1.0)
                    .allowsHitTesting(!isLocked)
                    .animation(.easeInOut(duration: 0.15), value: isLocked)
            }

            // ── 액션 버튼 ───────────────────────────────────────────────
            if currentIndex < items.count {
                actionButtons
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Next Card View

    @ViewBuilder
    private var nextCardView: some View {
        if currentIndex + 1 < items.count {
            cardContent(items[currentIndex + 1])
                .id("next-\(items[currentIndex + 1].id)")   // 항상 앞면으로 재생성
                .scaleEffect(0.94)
                .opacity(isLocked ? 0 : 0.30)               // 잠금 중엔 완전히 숨김
                .offset(y: 14)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.2), value: isLocked)
        }
    }

    // MARK: - Current Card View

    @ViewBuilder
    private var currentCardView: some View {
        if currentIndex < items.count {
            cardContent(items[currentIndex])
                .id("card-\(items[currentIndex].id)")       // 카드 교체 시 앞면으로 재생성
                .overlay(overlayView)                        // 오버레이를 카드 내부에 클리핑
                .offset(x: dragOffset.width, y: dragOffset.height * 0.05)
                .rotationEffect(.degrees(Double(dragOffset.width) / 28))
                .opacity(cardOpacity)
                .gesture(isLocked ? nil : dragGesture)
                .allowsHitTesting(!isLocked)
                // 드래그 중엔 즉시 반응, 아닐 땐 spring 복귀
                .animation(isDragging ? nil : .interpolatingSpring(stiffness: 300, damping: 28),
                           value: dragOffset)
        }
    }

    // MARK: - Overlay (드래그 중 + 버튼 확정 공통)

    @ViewBuilder
    private var overlayView: some View {
        if overlayOpacity > 0 {
            ZStack {
                // 카드 모서리와 동일한 cornerRadius(24)로 색상을 채워 경계 밖으로 삐져나오지 않게 함
                RoundedRectangle(cornerRadius: 24)
                    .fill(overlayDirection == .left
                          ? BrandTheme.knewIt.opacity(overlayOpacity * 0.28)
                          : BrandTheme.studyIt.opacity(overlayOpacity * 0.28))

                VStack(spacing: 10) {
                    Image(systemName: overlayDirection == .left ? "checkmark.seal.fill" : "bookmark.fill")
                        .font(.system(size: 60, weight: .bold))
                    Text(overlayDirection == .left ? "알고있어요!" : "학습할게요")
                        .font(.title2).fontWeight(.heavy)
                }
                .foregroundStyle(overlayDirection == .left ? BrandTheme.knewIt : BrandTheme.studyIt)
                .opacity(overlayOpacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))  // 카드 경계에 맞게 클리핑
            .allowsHitTesting(false)
        }
    }

    // MARK: - Drag helpers

    private var isDragging: Bool { dragOffset != .zero && !isLocked }

    private func makeItemsID() -> String {
        items.prefix(8).map { "\($0.id)" }.joined()
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragOffset = value.translation
                let ratio = abs(value.translation.width) / swipeThreshold
                // 드래그 중 실시간 오버레이
                overlayDirection = value.translation.width > 0 ? .right : .left
                overlayOpacity = min(1.0, ratio)
                if ratio > 0.75 && !hapticFired {
                    hapticFired = true
                    HapticManager.shared.playSwipe()
                }
                if ratio < 0.4 { hapticFired = false }
            }
            .onEnded { value in
                hapticFired = false
                let dx = value.translation.width
                if abs(dx) > swipeThreshold {
                    let dir: SwipeDirection = dx > 0 ? .right : .left
                    // 손 뗀 위치 그대로 넘김 (되돌리지 않음)
                    performSwipe(direction: dir, fromDrag: true, dragEndX: dx)
                } else {
                    // 미달 → 오버레이 + 카드 제자리로
                    withAnimation(.interpolatingSpring(stiffness: 350, damping: 26)) {
                        dragOffset = .zero
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        overlayOpacity = 0
                    }
                }
            }
    }

    // MARK: - Swipe 실행

    private func performSwipe(direction: SwipeDirection, fromDrag: Bool, dragEndX: CGFloat) {
        guard currentIndex < items.count, !isLocked else { return }
        isLocked = true
        overlayDirection = direction
        HapticManager.shared.playSwipeComplete()

        // 버튼 tap이면 오버레이 즉시 최대로
        if !fromDrag {
            withAnimation(.easeIn(duration: 0.12)) {
                overlayOpacity = 1.0
            }
        }

        // 오버레이 표시 유지 후 카드 날아가기
        let delay: Double = fromDrag ? 0.05 : 0.18
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let flyX: CGFloat = direction == .right ? flyDistance : -flyDistance
            withAnimation(.easeIn(duration: 0.20)) {
                dragOffset = CGSize(width: flyX, height: 0)
                cardOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                // 콜백 + 인덱스 증가
                let item = items[currentIndex]
                onSwiped(item, direction)
                currentIndex += 1

                // 오버레이·오프셋 초기화 (페이드인 전)
                dragOffset = .zero
                overlayOpacity = 0
                cardOpacity = 0

                if currentIndex >= items.count {
                    isLocked = false
                    onAllSwiped()
                } else {
                    // 다음 카드 페이드인
                    withAnimation(.easeOut(duration: 0.22)) {
                        cardOpacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        isLocked = false
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { performSwipe(direction: .left, fromDrag: false, dragEndX: 0) } label: {
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

            Button { performSwipe(direction: .right, fromDrag: false, dragEndX: 0) } label: {
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
        .opacity(isLocked ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isLocked)
    }
}
