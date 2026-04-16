//
//  ContentView.swift
//  Naelm
//
//  NOTE: 메인 UI는 NaelmApp.swift의 RootView에서 관리됩니다.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View { RootView() }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Vocabulary.self,
            VocabularyMeaning.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
        ], inMemory: true)
}
