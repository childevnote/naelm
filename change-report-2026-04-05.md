# 📋 Toeigo 변경 보고서 — 2026년 4월 5일

---

## 작업 요약

총 **7개 이슈** (버그 2건 + 기능 5건)를 처리하고, 앱 아키텍처를 대폭 개편했다.
최종 빌드: **BUILD SUCCEEDED** — 0 errors, 0 warnings.

---

## 1. Bug 1: Sign in with Apple 미동작 수정

### 문제
`SignInWithAppleButton`의 `onCompletion` 핸들러에서 `ASAuthorizationError.canceled` (사용자 취소)를 구분하지 않아, 취소 시에도 에러로 표시되거나 무반응 상태가 되었다.

### 수정 내용
- `ASAuthorizationError.canceled` 에러 코드를 별도로 판별하여 사용자 취소 시 에러 메시지를 표시하지 않도록 처리했다.
- `isSigningIn` 로딩 상태와 `signInError` 에러 메시지 상태를 추가하여 UX를 개선했다.
- 다크모드에서는 `.white` 스타일, 라이트모드에서는 `.black` 스타일 버튼을 자동 전환하도록 했다.
- 배경에 브랜드 그라디언트를 적용하고, 로고 색상을 `BrandTheme.accent`로 통일했다.

### 수정 파일
- `ToeigoApp.swift` → `SignInView`

---

## 2. Bug 2: 카드 flip 시 투명 배경으로 뒤 카드가 비치는 문제

### 문제
`VocabularyCardView`의 카드 배경이 `.ultraThickMaterial`(반투명)이어서, flip 애니메이션 도중 뒤에 쌓인 카드가 투과되어 보였다.

### 수정 내용
- 카드 배경을 `.ultraThickMaterial` → `BrandTheme.cardBackground` (불투명 컬러)로 교체했다.
- 다크모드: `BrandTheme.cardBackgroundDark` 사용.
- `.drawingGroup()` 모디파이어를 추가하여 Metal 레이어 합성으로 z-fighting을 방지했다.
- 앞면/뒷면에 `.allowsHitTesting(isFlipped)` / `.allowsHitTesting(!isFlipped)`을 추가하여 터치 영역도 정확히 분리했다.

### 수정 파일
- `VocabularyCardView.swift`

---

## 3. Feature 3: 순위 시스템

### 설계
- **점수 공식**: `attempts × 0.3 + correctAnswers × 0.7` → 문제를 많이 풀면서 정답률이 높을수록 유리하다.
- **매월 초기화**: `MonthlyScore` 모델의 `month` 필드("2026-04")로 월별 관리. 매월 1일부터 새로운 기록이 시작된다.
- **친구 순위**: `Friendship` 모델로 친구 관계를 관리하고, 친구 탭에서 친구 간 순위만 필터링한다.
- **전체 순위**: CloudKit 동기화된 모든 `MonthlyScore`에서 상위 100명을 표시한다.

### 생성 파일
- `RankingView.swift` — 순위 화면 (친구/전체 탭, 내 순위 카드, 1/2/3위 메달)

### 수정 파일
- `Models.swift` — `MonthlyScore`, `Friendship` 모델 추가
- `ToeigoApp.swift` — ModelContainer에 등록, Tab 4로 추가

---

## 4. Feature 4: 문법 퀴즈 보기 개선

### 문제
기존 오답 보기가 예문에서 랜덤 추출한 단어라서 "however", "employees" 같은 터무니없는 보기가 나왔다.

### 설계 원칙
1. **형태 변환 문제 (form)**: 같은 단어의 다른 형태로 보기 구성 (예: reach → reaching, to reach, being reached)
2. **의미 파악 문제 (meaning)**: 같은 품사/카테고리의 다른 단어로 보기 구성 (예: Although → Because, Despite, However)
3. **문법 구조 문제 (grammar)**: 같은 역할의 다른 문법 요소로 구성 (예: who → which, whom, whose)

### 수정 내용
- `Grammar` 모델에 `blankTarget`, `distractors`, `quizType` 필드를 추가했다.
- `Grammar.json` 100개 항목 모두에 `blankTarget`을 지정하고, 64개에 수작업 수준의 오답 보기를 배정했다.
- `QuizViewModel`의 `generateQuestion()`을 완전 재작성:
  - `blankTarget`이 있으면 해당 단어를 빈칸으로 만들고, `distractors`에서 오답을 가져온다.
  - `distractors`가 부족하면 `quizType`에 따라 자동 생성 (`generateFormDistractors`, `generateSmartDistractors`).
  - `blankTarget`이 없으면 기존 fallback 로직 사용.

### 수정 파일
- `Models.swift` — Grammar에 3개 필드 추가
- `DataLoader.swift` — GrammarDTO에 3개 필드 추가
- `QuizViewModel.swift` — 전면 재작성
- `Grammar.json` — 100개 항목에 blankTarget/distractors/quizType 추가

---

## 5. Feature 5: 단어 15초 타이머 + 일일 학습 카운트

### 설계
- 카드가 표시되면 **15초 타이머**가 시작된다.
- 타이머 바가 상단에 표시되며, 10초 이상 = 초록, 5~10초 = 주황, 5초 미만 = 빨강으로 색이 변한다.
- 15초 내에 스와이프하지 않으면 자동으로 **"학습할게요"**가 선택되고 다음 카드로 넘어간다.
- 오늘 학습한 단어 수가 `N/목표` 형태로 표시된다.

### 수정 파일
- `CardViewModel.swift` — `timerRemaining`, `isTimerRunning`, `onTimerExpired` 콜백, `startTimer()`/`resetTimer()`/`stopTimer()` 추가
- `VocabularyStudyView.swift` — 타이머 바 UI, 오늘 진행률 헤더, `triggerAutoStudy()` 추가

---

## 6. Feature 6: 목표 점수 기반 시스템 (난이도 3단계 → 점수 구간)

### 설계
기존 "초급/중급/고급" 3단계를 완전히 폐지하고, **TOEIC 점수 구간**(600/700/800/900)에 기반한 시스템으로 전환했다.

- `TOEICScoreRange` 열거형: `frequencyLevel 1→600, 2→700, 3→800, 4→900` 매핑
- `UserProfile` 모델: `targetScore` (목표점수), `estimatedLevel` (추정수준), `dailyVocabGoal`, `dailyGrammarGoal`
- **온보딩 플로우**: 로그인 후 최초 1회
  1. **목표 점수 선택** (600/700/800/900)
  2. **수준 파악 테스트** (단어 10문제 + 문법 10문제 = 총 20문제)
  3. 정답 수에 따라 추정 수준 자동 결정
  4. 목표와 수준 차이에 따라 일일 학습량 자동 계산

### AI 일일학습량 추천
현재 기기에서 Apple Intelligence API를 직접 호출하는 것은 iOS 18.4+ Foundation Models 프레임워크가 필요하다. 현재는 **목표 점수와 추정 수준의 gap**을 수학적으로 계산하여 일일 학습량을 자동 설정하는 로컬 알고리즘을 구현했다:
```
dailyVocabGoal = min(40, max(10, 15 + (targetScore - estimatedLevel×100 - 400) / 50))
dailyGrammarGoal = min(20, max(5, 8 + gap / 80))
```

### 900점대 단어 표시
`VocabularyCardView`의 난이도 배지를 도트(●●●) → **점수 구간 배지**("900점")로 교체했다. 900점대 단어는 보라색 배경으로 강조 표시된다.

### 생성 파일
- `OnboardingView.swift` — 4단계 온보딩 플로우

### 수정 파일
- `Models.swift` — `TOEICScoreRange` 열거형, `UserProfile` 모델 추가
- `CardViewModel.swift` — 난이도 필터 → 점수구간 필터로 전환
- `VocabularyStudyView.swift` — 난이도 Picker 제거, 점수 배지 추가
- `VocabularyCardView.swift` — 난이도 도트 → 점수 구간 배지
- `QuizViewModel.swift` — `loadQuiz(targetScore:)` 파라미터 추가
- `ToeigoApp.swift` — `RootView`에 온보딩 분기 추가

---

## 7. Feature 7: 홈화면 UX 개편

### 문제
기존 "오늘의 학습" 카드가 단순 정보 표시에 그쳐 사용자 혼동을 일으켰다.

### 개편 내용
- **복습 대기**: "학습할게요"로 표시한 단어 수 표시 → 탭하면 복습 전용 스와이프 학습 시작
- **단어**: `오늘 학습한 수/일일 목표` 형태로 진행률 표시 → 탭하면 단어 학습 바로 시작
- **문법**: `오늘 푼 문제 수/일일 목표` 형태로 진행률 표시 → 탭하면 문법 퀴즈 바로 시작
- 각 항목에 `chevron.right` 아이콘과 설명 서브텍스트 추가로 탭 가능 시각적 단서 제공

### 복습 기능
- `LearningProgress`에 `markedForReview` 필드 추가
- 단어 스와이프에서 "학습할게요"(오른쪽) 선택 시 자동으로 `markedForReview = true`
- `ReviewSessionView`: 복습 대기 단어만 모아 별도 스와이프 학습 진행
- 복습 중 "알고있어요" 선택 시 `markedForReview = false`로 복습 목록에서 제거

### 생성 파일
- `DashboardView.swift` 내 `ReviewSessionView`

---

## 8. 마이페이지 구현

- 현재 수준 (추정 점수 구간) 표시
- 목표 점수, 연속 학습일, 총 XP 표시
- 단어/문법 숙달 현황
- 일일 목표 (단어/문법 N개/일)
- 목표 점수 / 수준 재설정 기능 (온보딩 재진행)
- 로그아웃 기능

### 생성 파일
- `MyPageView.swift`

---

## 파일 변경 목록

| 파일 | 상태 | 변경 내용 |
|------|------|-----------|
| `Models.swift` | 수정 | `TOEICScoreRange` 열거형, `UserProfile`, `MonthlyScore`, `Friendship` 모델 추가, `LearningProgress.markedForReview` 필드 추가, `Grammar`에 `blankTarget`/`distractors`/`quizType` 필드 추가 |
| `ToeigoApp.swift` | 수정 | SignInView 브랜딩+에러처리 개선, RootView 온보딩 분기 추가, MainDashboardView 5탭 구성, ModelContainer에 3개 모델 추가 |
| `CardViewModel.swift` | 전면 재작성 | 난이도→점수구간 필터, 15초 타이머, 오늘 학습 카운트, `markedForReview` 설정 |
| `VocabularyStudyView.swift` | 전면 재작성 | 난이도 Picker 제거, 타이머 바, 오늘 진행률, 자동 학습 처리 |
| `VocabularyCardView.swift` | 수정 | 불투명 배경 + `.drawingGroup()`, 점수구간 배지 |
| `QuizViewModel.swift` | 전면 재작성 | `blankTarget`/`distractors` 기반 문제 생성, `quizType`별 오답 전략 |
| `GrammarQuizView.swift` | 수정 | `loadQuiz`에 `targetScore` 전달, unused variable 정리 |
| `DashboardView.swift` | 전면 재작성 | 퀵 액션 카드 3종, `ReviewSessionView` 추가 |
| `DataLoader.swift` | 수정 | GrammarDTO에 3개 필드 추가 |
| `Grammar.json` | 수정 | 100개 항목에 `blankTarget`/`distractors`/`quizType` 추가 |
| `OnboardingView.swift` | 신규 | 4단계 온보딩 (목표점수→수준테스트→결과) |
| `RankingView.swift` | 신규 | 순위 시스템 (전체/친구, 월간 리셋) |
| `MyPageView.swift` | 신규 | 마이페이지 (수준/목표/통계/설정) |

---

## 아키텍처 다이어그램

```
Sign in with Apple → Keychain → AuthenticationManager
                                        ↓
                              [온보딩 완료?]
                            No ↙         ↘ Yes
                     OnboardingView    MainDashboardView
                     (목표점수선택       ┌─────┬─────┬─────┬─────┐
                      →수준테스트       홈    단어   문법   순위   마이
                      →결과)           │      │      │      │      │
                                  Dashboard Vocab  Quiz  Ranking MyPage
                                      │      │      │      │
                                      ├──→ReviewSession   │
                                      │      │      │     │
                                      └──────┴──────┘     │
                                             ↓            ↓
                                    LearningSessionManager
                                             ↓
                                   SpacedRepetitionService (SM-2)
                                             ↓
                                      SwiftData + CloudKit
```

---

## 빌드 결과

```
** BUILD SUCCEEDED **
Errors: 0
Warnings: 0
```
