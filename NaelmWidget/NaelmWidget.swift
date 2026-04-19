//
//  NaelmWidget.swift
//  NaelmWidget
//
//  홈 화면 위젯 — 오늘의 학습 현황과 연속 학습 스트릭을 표시합니다.
//  ──────────────────────────────────────────────
//  지원 크기:  .systemSmall, .systemMedium
//  데이터:     App Group UserDefaults (group.naelm.shared)
//  업데이트:   앱이 WidgetCenter.shared.reloadAllTimelines()를 호출할 때
//             + 15분마다 자동 갱신
//  ──────────────────────────────────────────────

import WidgetKit
import SwiftUI

// MARK: - App Group 식별자 (앱과 동일하게 유지)

private let appGroupID = "group.naelm.shared"

// MARK: - 위젯 데이터 모델

struct NaelmWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let vocabCompleted: Bool
    let grammarCompleted: Bool
}

// MARK: - Timeline Provider

struct NaelmWidgetProvider: TimelineProvider {

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    func placeholder(in context: Context) -> NaelmWidgetEntry {
        NaelmWidgetEntry(date: Date(), streak: 5, vocabCompleted: true, grammarCompleted: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (NaelmWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NaelmWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // 30분 후 다시 갱신 (앱이 reloadAllTimelines를 호출하면 더 빨리 갱신됨)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> NaelmWidgetEntry {
        let defaults = sharedDefaults
        return NaelmWidgetEntry(
            date: Date(),
            streak: defaults?.integer(forKey: "naelm.widget.streak") ?? 0,
            vocabCompleted: defaults?.bool(forKey: "naelm.widget.vocabCompleted") ?? false,
            grammarCompleted: defaults?.bool(forKey: "naelm.widget.grammarCompleted") ?? false
        )
    }
}

// MARK: - Widget View

struct NaelmWidgetEntryView: View {
    var entry: NaelmWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    // MARK: Small Widget (2×2)

    private var smallView: some View {
        ZStack {
            Color(red: 0.13, green: 0.40, blue: 0.22) // AppPalette.forest approximation
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // 스트릭
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 18, weight: .bold))
                    Text("\(entry.streak)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("연속 학습")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                Divider().overlay(.white.opacity(0.3))

                // 학습 완료 상태
                HStack(spacing: 10) {
                    learningDot(symbol: "character.book.closed", completed: entry.vocabCompleted)
                    learningDot(symbol: "text.book.closed", completed: entry.grammarCompleted)
                }
            }
            .padding(12)
        }
    }

    // MARK: Medium Widget (4×2)

    private var mediumView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.40, blue: 0.22),
                    Color(red: 0.16, green: 0.52, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                // 왼쪽: 스트릭
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 28, weight: .bold))
                    Text("\(entry.streak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("연속 학습일")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // 오른쪽: 오늘의 학습
                VStack(alignment: .leading, spacing: 10) {
                    Text("오늘의 학습")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    learningRow(
                        symbol: "character.book.closed",
                        label: "단어",
                        completed: entry.vocabCompleted
                    )
                    learningRow(
                        symbol: "text.book.closed",
                        label: "문법",
                        completed: entry.grammarCompleted
                    )

                    if !entry.vocabCompleted || !entry.grammarCompleted {
                        Text("지금 학습 시작! →")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.60))
                    } else {
                        Text("오늘 학습 완료 🎉")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.yellow.opacity(0.90))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            .padding(14)
        }
    }

    // MARK: - Subviews

    private func learningDot(symbol: String, completed: Bool) -> some View {
        ZStack {
            Circle()
                .fill(completed ? Color.white.opacity(0.25) : Color.white.opacity(0.10))
                .frame(width: 32, height: 32)
            Image(systemName: completed ? "checkmark" : symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(completed ? .yellow : .white.opacity(0.70))
        }
    }

    private func learningRow(symbol: String, label: String, completed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: completed ? "checkmark.circle.fill" : symbol)
                .font(.system(size: 14))
                .foregroundStyle(completed ? .yellow : .white.opacity(0.65))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(completed ? .white : .white.opacity(0.75))
            Spacer()
            if completed {
                Text("완료")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow)
            } else {
                Text("미완료")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
    }
}

// MARK: - Widget Configuration

struct NaelmWidget: Widget {
    let kind: String = "NaelmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NaelmWidgetProvider()) { entry in
            NaelmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Naelm 학습")
        .description("오늘의 학습 현황과 연속 학습 스트릭을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NaelmWidget()
} timeline: {
    NaelmWidgetEntry(date: Date(), streak: 7, vocabCompleted: false, grammarCompleted: false)
    NaelmWidgetEntry(date: Date(), streak: 7, vocabCompleted: true, grammarCompleted: true)
}

#Preview(as: .systemMedium) {
    NaelmWidget()
} timeline: {
    NaelmWidgetEntry(date: Date(), streak: 12, vocabCompleted: true, grammarCompleted: false)
}
