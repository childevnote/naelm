//
//  ContentView.swift
//  Toeigo
//
//  Created by 김동진 on 4/3/26.
//
//  NOTE: 기존 Item 모델 기반 코드는 제거되었습니다.
//  메인 UI는 ToeigoApp.swift의 RootView에서 관리됩니다.
//  이 파일은 향후 공용 뷰 컴포넌트를 배치하는 용도로 유지합니다.
//

import SwiftUI
import SwiftData

/// 앱의 기본 ContentView.
/// 현재는 RootView로 위임하며, 향후 공용 뷰 로직을 여기에 추가할 수 있습니다.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Vocabulary.self,
            Grammar.self,
            LearningProgress.self,
            UserActivity.self,
        ], inMemory: true)
}
