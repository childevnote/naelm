//
//  SwipeableCardStack.swift
//  Toeigo
//
//  Created by 김동진 on 4/4/26.
//
//  Tinder 스타일 스와이프 카드 스택 컴포넌트 (v2).
//  ──────────────────────────────────────────────
//  왼쪽 스와이프 = 알고있어요 (초록) — 숙달 처리
//  오른쪽 스와이프 = 학습할게요 (주황) — 복습 저장
//  하단 버튼으로도 동일 기능 트리거 가능
//  ──────────────────────────────────────────────

import SwiftUI

// MARK: - Swipe Direction

/// 카드 스와이프 방향
enum SwipeDirection {
    case left   // 알고있어요 → 숙달
    case right  // 학습할게요 → 복습 저장
}

// MARK: - SwipeableCardStack

struct SwipeableCardStack<Item: Identifiable, CardContent: View>: View {

    let items: [Item]
    let onSwiped: (Item, SwipeDirection) -> Void
    let onAllSwiped: () -> Void
    @ViewBuilder let cardContent: (Item) -> CardContent

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var hapticTriggered: Bool = false

    private let swipeThreshold: CGFloat = 100
    private let flyAwayDistance: CGFloat = 600
    private let visibleCardCount: Int = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if items.isEmpty || currentIndex >= items.count {
                    emptyStateView
                } else {
                    ForEach(visibleCards.reversed(), id: \.offset) { index, item in
                        let relativeIndex = index - currentIndex
                        cardView(item: item, relativeIndex: relativeIndex, isTop: index == currentIndex)
                            .zIndex(Double(items.count - index))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !items.isEmpty && currentIndex < items.count {
                actionButtons
                    .padding(.bottom, 16)
            }
        }
    }

    private var visibleCards: [(offset: Int, element: Item)] {
        let start = currentIndex
        let end = min(currentIndex + visibleCardCount, items.count)
        guard start < end else { return [] }
        return Array(items[start..<end].enumerated().map { (start + $0.offset, $0.element) })
    }

    @ViewBuilder
    private func cardView(item: Item, relativeIndex: Int, isTop: Bool) -> some View {
        let scale = 1.0 - Double(relativeIndex) * 0.04
        let yOffset = CGFloat(relativeIndex) * 10
        let backScale = isTop ? 1.0 : min(scale + abs(Double(dragOffset.width)) * 0.0001, 1.0)

        // 드래그 중이면 뒤 카드 내용 숨기고 빈 카드만 표시
        Group {
            if isTop {
                cardContent(item)
            } else if isDragging {
                // 스와이프 중: 카드 틀만 보이고 내용은 숨김
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            } else {
                cardContent(item)
            }
        }
        .scaleEffect(isTop ? 1.0 : backScale)
        .offset(y: isTop ? 0 : yOffset)
        .offset(x: isTop ? dragOffset.width : 0,
                y: isTop ? dragOffset.height * 0.2 : 0)
        .rotationEffect(isTop ? .degrees(Double(dragOffset.width) / 15) : .zero)
        .opacity(relativeIndex < visibleCardCount ? 1.0 : 0)
        .overlay(isTop ? swipeOverlay : nil)
        .gesture(isTop ? dragGesture : nil)
        .animation(isDragging ? nil : .interpolatingSpring(stiffness: 350, damping: 28), value: dragOffset)
        .allowsHitTesting(isTop)
    }

    // MARK: - Swipe Overlay

    @ViewBuilder
    private var swipeOverlay: some View {
        ZStack {
            // 왼쪽 스와이프 → 알고있어요 (초록)
            RoundedRectangle(cornerRadius: 20)
                .fill(BrandTheme.knewIt.opacity(leftSwipeOpacity * 0.25))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52, weight: .bold))
                        Text("알고있어요!")
                            .font(.title3).fontWeight(.heavy)
                    }
                    .foregroundStyle(BrandTheme.knewIt)
                    .opacity(leftSwipeOpacity)
                )
                .allowsHitTesting(false)

            // 오른쪽 스와이프 → 학습할게요 (주황)
            RoundedRectangle(cornerRadius: 20)
                .fill(BrandTheme.studyIt.opacity(rightSwipeOpacity * 0.25))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 52, weight: .bold))
                        Text("학습할게요")
                            .font(.title3).fontWeight(.heavy)
                    }
                    .foregroundStyle(BrandTheme.studyIt)
                    .opacity(rightSwipeOpacity)
                )
                .allowsHitTesting(false)
        }
    }

    private var rightSwipeOpacity: Double {
        max(0, min(1, Double(dragOffset.width) / Double(swipeThreshold)))
    }
    private var leftSwipeOpacity: Double {
        max(0, min(1, Double(-dragOffset.width) / Double(swipeThreshold)))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 32) {
            Button { triggerSwipe(direction: .left) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 28))
                    Text("알고있어요").font(.caption).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(width: 100, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(BrandTheme.knewIt)
                        .shadow(color: BrandTheme.knewIt.opacity(0.4), radius: 8, y: 4)
                )
            }

            Button { triggerSwipe(direction: .right) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "bookmark.fill").font(.system(size: 28))
                    Text("학습할게요").font(.caption).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(width: 100, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(BrandTheme.studyIt)
                        .shadow(color: BrandTheme.studyIt.opacity(0.4), radius: 8, y: 4)
                )
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
                if abs(value.translation.width) > swipeThreshold * 0.7 && !hapticTriggered {
                    hapticTriggered = true
                    HapticManager.shared.playSwipe()
                }
                if abs(value.translation.width) < swipeThreshold * 0.5 {
                    hapticTriggered = false
                }
            }
            .onEnded { value in
                isDragging = false
                hapticTriggered = false
                if value.translation.width > swipeThreshold {
                    completeSwipe(direction: .right)
                } else if value.translation.width < -swipeThreshold {
                    completeSwipe(direction: .left)
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 350, damping: 28)) {
                        dragOffset = .zero
                    }
                    HapticManager.shared.playTap()
                }
            }
    }

    private func triggerSwipe(direction: SwipeDirection) {
        guard currentIndex < items.count else { return }
        HapticManager.shared.playSwipe()
        let moveX: CGFloat = direction == .right ? 60 : -60
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 30)) {
            dragOffset = CGSize(width: moveX, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completeSwipe(direction: direction)
        }
    }

    private func completeSwipe(direction: SwipeDirection) {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        let flyX: CGFloat = direction == .right ? flyAwayDistance : -flyAwayDistance
        withAnimation(.interpolatingSpring(stiffness: 250, damping: 22)) {
            dragOffset = CGSize(width: flyX, height: dragOffset.height * 0.5)
        }
        HapticManager.shared.playSwipeComplete()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onSwiped(item, direction)
            currentIndex += 1
            dragOffset = .zero
            if currentIndex >= items.count {
                onAllSwiped()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(BrandTheme.accent)
            Text("대단해요!")
                .font(.title2).fontWeight(.bold)
            Text("오늘의 단어를 모두 학습했습니다.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
