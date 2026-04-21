//
//  NaelmWidget.swift
//  NaelmWidget
//
//  홈 화면 위젯 — 연속 학습 스트릭을 표시하고 앱 학습 화면으로 바로 진입합니다.
//  ──────────────────────────────────────────────
//  지원 크기:  .systemSmall
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

    private var footerMessage: String {
        (!entry.vocabCompleted || !entry.grammarCompleted) ? "탭해서 오늘 학습 이어가기" : "탭해서 복습 이어가기"
    }

    private var destinationURL: URL? {
        if !entry.vocabCompleted {
            return URL(string: "naelm://study/vocabulary")
        }
        if !entry.grammarCompleted {
            return URL(string: "naelm://study/grammar")
        }
        return URL(string: "naelm://study/review")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.40, blue: 0.22),
                    Color(red: 0.08, green: 0.24, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("바로 학습")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 20, weight: .bold))
                        Text("\(entry.streak)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("연속 학습일")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer()

                Text(footerMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .widgetURL(destinationURL)
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
        .description("연속 학습일을 확인하고 바로 오늘 학습을 시작하세요.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NaelmWidget()
} timeline: {
    NaelmWidgetEntry(date: Date(), streak: 12, vocabCompleted: true, grammarCompleted: false)
}
