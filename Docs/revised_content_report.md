# Naelm 개정 내용 보고서

> 작성일: 2026-04-19

---

## 1. 버그 수정 (Review Fixes)

### 1-1. `awardVocabReviewBonusXP()` / `awardReviewBonusXP()` — 저장 성공 후 플래그 설정

**파일:** `Naelm/DashboardView.swift`

**문제:**
`bonusXPAwarded = true`가 `modelContext.save()` **전에** 설정되었습니다.  
저장이 실패하더라도 플래그가 이미 `true`이므로, 뷰 생명주기 내에서 보너스 XP를 재시도할 수 없었습니다.  
또한 `try? modelContext.save()`로 오류를 무시하고 있어 문제 원인 파악이 불가능했습니다.

**수정:**
- `bonusXPAwarded = true`를 `try modelContext.save()` **성공 이후**로 이동
- 저장 실패 시 XP 증가분 롤백 (`activity.xpEarned -= …`) 및 `dailyGoalMet` 재조정
- `AppLogger.session.error(…)`를 통한 오류 로깅 추가
- `VocabReviewContent.awardVocabReviewBonusXP()` 및 `GrammarReviewContent.awardReviewBonusXP()` 모두 동일하게 수정

```swift
// 수정 전
bonusXPAwarded = true
// ...
try? modelContext.save()   // 오류 무시

// 수정 후
do {
    try modelContext.save()
    bonusXPAwarded = true   // 저장 성공 후에만 설정
} catch {
    activity.xpEarned -= LearningSessionManager.reviewCompletionBonusXP
    AppLogger.session.error("Failed to save bonus XP: \(error)")
}
```

---

### 1-2. `DashboardView` — 중복 ternary 제거 및 완료/미완료 색상 구분

**파일:** `Naelm/DashboardView.swift`

**문제:**
`todayTaskRow`의 `color:` 인수에서 ternary 연산자가 동일한 값을 반환하고 있었습니다.

```swift
// 수정 전 — 양 분기가 동일 (의미 없는 ternary)
color: vocabCompleted ? AppPalette.forest : AppPalette.forest
color: grammarCompleted ? AppPalette.grammarBrown : AppPalette.grammarBrown
```

**수정:**
완료 시 `AppPalette.mint`(초록 계열)로 시각적 피드백이 명확하도록 변경했습니다.

```swift
// 수정 후 — 완료 시 mint, 미완료 시 원래 색상
color: vocabCompleted ? AppPalette.mint : AppPalette.forest
color: grammarCompleted ? AppPalette.mint : AppPalette.grammarBrown
```

---

### 1-3. `OnboardingView` — 전역 중복 방지 및 문제 수 보장

**파일:** `Naelm/OnboardingView.swift`

#### (a) 전역 `usedEnglish` 공유

**문제:**
`makeVocabQuestions`가 호출될 때마다 `usedEnglish` 집합이 리셋되어, `level: 3`을 두 번 호출하는 경우(800점대, 900점대) 동일 단어가 중복 출제될 수 있었습니다.

**수정:**
`loadPlacementQuestions` 스코프에서 `var usedEnglish = Set<String>()`을 선언하고 `inout`으로 모든 `makeVocabQuestions` 호출에 전달합니다. 전역적으로 단어가 중복 사용되지 않습니다.

```swift
// loadPlacementQuestions 내부
var usedEnglish = Set<String>()
qs += makeVocabQuestions(…, usedEnglish: &usedEnglish)   // 모든 호출에 공유
```

#### (b) 문제 수 보장 (count 채움 보장)

**문제:**
`Array(filtered.prefix(count))`로 후보를 미리 잘라낸 후, `options.count >= 4` 조건을 만족하지 못하는 항목을 건너뛰었습니다.  
결과적으로 반환되는 문제 수가 `count`보다 적어져 테스트가 20문제보다 짧아질 수 있었습니다.

**수정:**
후보 전체를 순회하면서 `result.count < count`인 동안 계속 시도합니다. 유효한 문제를 `count`개 확보하거나 후보가 소진될 때까지 반복합니다.

```swift
// 수정 전: 미리 prefix로 잘라냄
let selected = Array(filtered.prefix(count))

// 수정 후: 전체를 순회하며 count개 채움
for v in filtered {
    guard result.count < count else { break }
    // … 유효성 검사 후 append
}
```

---

## 2. 신규 기능

### 2-1. 일일 학습 알림 (Local Notification)

**신규 파일:** `Naelm/NotificationService.swift`  
**수정 파일:** `Naelm/NaelmApp.swift`, `Naelm/DashboardView.swift`

#### NotificationService

| 메서드 | 역할 |
|--------|------|
| `requestPermissionIfNeeded()` | 권한 상태가 `.notDetermined`인 경우에만 시스템 권한 요청 다이얼로그 표시 |
| `scheduleDailyReminderIfNeeded(vocabCompleted:grammarCompleted:reminderHour:)` | 미완료 학습이 있으면 당일 오후 8시(기본값) 알림 예약. 두 가지 모두 완료이면 예약 취소 |
| `cancelDailyReminder()` | 보류 중인 일일 알림 취소 |

**권한 흐름:**
1. 앱 최초 실행 시 `RootView.task`에서 `requestPermissionIfNeeded()` 호출 → `UNAuthorizationStatus.notDetermined`일 때만 시스템 다이얼로그 표시
2. 이미 허용 또는 거부된 경우 OS가 재요청을 무시
3. 권한이 없으면 알림 예약 자체를 건너뜀

**알림 메시지 (상황별):**

| 상황 | 메시지 |
|------|--------|
| 단어 + 문법 모두 미완료 | "오늘 단어와 문법 학습이 아직 남아 있어요! 지금 시작해볼까요? 📚" |
| 단어만 미완료 | "문법 퀴즈는 완료했네요! 오늘의 단어 학습도 해볼까요? 📖" |
| 문법만 미완료 | "단어 학습은 완료했네요! 문법 퀴즈도 도전해보세요 ✏️" |
| 모두 완료 | 알림 예약 취소 |

**통합 방식:**
- `DashboardView.refreshStats()` 끝에서 `WidgetDataProvider.update(…)` 및 `NotificationService.shared.scheduleDailyReminderIfNeeded(…)` 호출
- 학습 완료/미완료 상태가 바뀔 때마다 자동으로 알림 갱신

---

### 2-2. 홈 화면 위젯

**신규 디렉토리:** `NaelmWidget/`

| 파일 | 역할 |
|------|------|
| `NaelmWidgetBundle.swift` | Widget Extension `@main` 진입점 |
| `NaelmWidget.swift` | 위젯 뷰, 타임라인 제공자, 설정 |
| `NaelmWidget.entitlements` | App Group 권한 (`group.naelm.shared`) |

**신규 파일:** `Naelm/WidgetDataProvider.swift`  
**수정 파일:** `Naelm/Naelm.entitlements`

#### 지원 크기

| 크기 | 표시 내용 |
|------|-----------|
| `.systemSmall` (2×2) | 🔥 연속 학습 일수 + 단어/문법 완료 아이콘 |
| `.systemMedium` (4×2) | 🔥 연속 학습 일수 + 단어/문법 완료 행 (라벨 포함) + 미완료 시 "지금 학습 시작!" CTA |

#### 데이터 공유 방식

앱 ↔ 위젯 간 데이터는 **App Group UserDefaults** (`group.naelm.shared`)를 통해 공유됩니다.

| 키 | 타입 | 내용 |
|----|------|------|
| `naelm.widget.streak` | Int | 연속 학습 일수 |
| `naelm.widget.vocabCompleted` | Bool | 오늘 단어 학습 완료 여부 |
| `naelm.widget.grammarCompleted` | Bool | 오늘 문법 학습 완료 여부 |
| `naelm.widget.lastUpdated` | Date | 마지막 업데이트 시각 |

`DashboardView.refreshStats()` 실행 시 `WidgetDataProvider.shared.update(…)`를 호출하며, 이 메서드 내부에서 `WidgetCenter.shared.reloadAllTimelines()`로 위젯 타임라인을 즉시 갱신합니다.  
앱이 실행 중이지 않을 때는 위젯이 15분 주기로 자동 갱신됩니다.

#### Xcode 프로젝트 설정 (수동 필요)

> ⚠️ 위젯은 별도 타겟(Widget Extension)이 필요합니다. 아래 단계를 Xcode에서 수행하세요.

1. **Xcode → File → New → Target → Widget Extension** 선택
2. Product Name: `NaelmWidget`, Bundle ID: `<앱 번들 ID>.NaelmWidget`
3. `NaelmWidget/` 폴더의 소스 파일을 새 타겟에 추가
4. **Apple Developer Console** → Identifiers → App Group `group.naelm.shared` 생성
5. 메인 앱 타겟과 위젯 타겟 모두에 App Group 활성화
6. 메인 앱 `Naelm.entitlements` 및 `NaelmWidget.entitlements`에 동일 App Group ID 기재 (이미 반영됨)
7. 메인 앱 타겟 → **Signing & Capabilities → Push Notifications** 활성화 (알림 기능)

---

## 3. 변경 파일 목록

| 파일 | 변경 유형 | 주요 내용 |
|------|-----------|-----------|
| `Naelm/DashboardView.swift` | 수정 | bonusXP 플래그 순서 수정, ternary 개선, 알림/위젯 통합 |
| `Naelm/OnboardingView.swift` | 수정 | usedEnglish 공유, 문제 수 보장 로직 |
| `Naelm/NotificationService.swift` | **신규** | 알림 권한 요청 및 일일 학습 알림 예약 |
| `Naelm/WidgetDataProvider.swift` | **신규** | App Group UserDefaults 기반 위젯 데이터 공유 |
| `Naelm/NaelmApp.swift` | 수정 | 앱 시작 시 알림 권한 요청 |
| `Naelm/Naelm.entitlements` | 수정 | App Group 추가 |
| `NaelmWidget/NaelmWidget.swift` | **신규** | 위젯 뷰 + 타임라인 제공자 |
| `NaelmWidget/NaelmWidgetBundle.swift` | **신규** | Widget Extension 진입점 |
| `NaelmWidget/NaelmWidget.entitlements` | **신규** | 위젯 App Group 권한 |
