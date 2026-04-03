# 📊 Toeigo — Week 1 진행률 보고서

**작성일:** 2026년 4월 4일  
**스프린트:** Week 1 — Foundation & Core Learning Features  
**전체 진행률:** ██████████░░ **87%**

---

## 1. Week 1 목표 요약

Week 1의 목표는 앱의 뼈대가 되는 3개의 핵심 파일(`Models.swift`, `DataLoader.swift`, `AppMain`)을 만들고, 단어 스와이프 학습과 문법 퀴즈라는 두 핵심 기능을 동작 가능한 수준으로 완성하는 것이었다.

---

## 2. 작업 항목별 진행률

### 🏗️ Foundation (기반 설계)

| 항목 | 목표 | 상태 | 진행률 |
|---|---|---|---|
| `Models.swift` SwiftData 모델 4종 | 4개 모델 완성 | ✅ 완료 | 100% |
| `DataLoader.swift` JSON 시딩 | 멱등성 보장, DTO 패턴 | ✅ 완료 | 100% |
| `ToeigoApp.swift` @main 진입점 | ModelContainer, RootView, 인증 분기 | ✅ 완료 | 100% |
| `KeychainHelper.swift` | Keychain CRUD, 자동 로그인 | ✅ 완료 | 100% |
| `Sign in with Apple` 연동 | 인증 성공/실패 처리, Keychain 복원 | ✅ 완료 | 100% |

**Foundation 진행률: 100%** ✅

---

### 📚 Learning Feature 1 — Vocabulary Swipe

| 항목 | 목표 | 상태 | 진행률 |
|---|---|---|---|
| `SwipeableCardStack.swift` | Tinder 스타일 DragGesture 카드 스택 | ✅ 완료 | 100% |
| `VocabularyCardView.swift` | 앞면/뒷면 flip, 발음·품사·예문 표시 | ✅ 완료 | 100% |
| `CardViewModel.swift` | 카드 덱 구성(SRS + fallback), 스와이프 처리 | ✅ 완료 | 100% |
| `VocabularyStudyView.swift` | 학습 화면 UI, 세션 완료 화면 | ✅ 완료 | 100% |
| 스와이프 방향 의미 설계 | 왼쪽=알고있어요, 오른쪽=학습할게요 | ✅ 완료 | 100% |
| 하단 액션 버튼 | 알고있어요/학습할게요 버튼 | ✅ 완료 | 100% |
| 난이도 레벨 1/2/3 Picker | 초급/중급/고급 필터링 | ✅ 완료 | 100% |
| `HapticManager.swift` | 6종 햅틱(스와이프, 완료, 탭, 축하 등) | ✅ 완료 | 100% |
| `SpacedRepetitionService.swift` | SM-2 알고리즘, 복습 스케줄링 | ✅ 완료 | 100% |
| `LearningSessionManager.swift` | 세션 XP 추적, UserActivity 기록 | ✅ 완료 | 100% |

**Vocabulary 진행률: 100%** ✅

---

### 📝 Learning Feature 2 — Grammar Quiz

| 항목 | 목표 | 상태 | 진행률 |
|---|---|---|---|
| `QuizViewModel.swift` | 문제 생성, 4지선다 보기 구성 | ✅ 완료 | 100% |
| `GrammarQuizView.swift` | Duolingo 스타일 UI, 해설 시트 | ✅ 완료 | 100% |
| 정답/오답 햅틱 피드백 | HapticManager 연동 | ✅ 완료 | 100% |
| 문법 퀴즈 fallback 로직 | Grammar 데이터 없을 때 처리 | ✅ 완료 | 100% |

**Grammar 진행률: 100%** ✅

---

### 🎮 Gamification

| 항목 | 목표 | 상태 | 진행률 |
|---|---|---|---|
| `GamificationService.swift` | XP/레벨/스트릭/7일 히스토리 계산 | ✅ 완료 | 100% |
| `DashboardView.swift` | XP 링, 스트릭, 7일 차트, 숙달 현황 | ✅ 완료 | 100% |
| 스트릭(연속 학습일) 로직 | 날짜 기반 스트릭 계산 | ✅ 완료 | 100% |
| XP 시스템 | 단어/문법 정답 XP 차등 지급 | ✅ 완료 | 100% |

**Gamification 진행률: 100%** ✅

---

### 🎨 Design System & Branding

| 항목 | 목표 | 상태 | 진행률 |
|---|---|---|---|
| `BrandColors.swift` | 딥 포레스트 그린 브랜딩 컬러 시스템 | ✅ 완료 | 100% |
| VocabularyCardView 브랜딩 | 난이도 도트, 품사 배지, 카드 컬러 | ✅ 완료 | 100% |
| VocabularyStudyView 브랜딩 | 배경 그라디언트, 버튼 컬러 | ✅ 완료 | 100% |
| SwipeableCardStack 브랜딩 | 오버레이, 버튼 컬러, 쉐도우 | ✅ 완료 | 100% |
| DashboardView 브랜딩 | 브랜드 컬러 적용 | ✅ 완료 | 100% |
| 다크모드 대응 | colorScheme 분기, 그라디언트 분리 | ✅ 완료 | 100% |
| GrammarQuizView 브랜딩 | 정답/오답 색상, 버튼 컬러 | 🔄 부분 적용 | 70% |
| SignInView 브랜딩 | 로고 컬러, 버튼 스타일 | ⬜ 미완료 | 0% |
| 설정 탭 브랜딩 | 브랜드 컬러 전체 적용 | ⬜ 미완료 | 0% |

**Design 진행률: 74%** 🔄

---

### 🗄️ Static Data (정적 데이터)

| 항목 | 목표 | 상태 | 진행률 |
|---|---|---|---|
| `Vocabulary.json` | 100개 (Level 1: 34개, Level 2: 34개, Level 3: 32개) | ✅ 완료 | 100% |
| `Grammar.json` | 100개 (Level 1: 20개, Level 2: 53개, Level 3: 27개) | ✅ 완료 | 100% |
| 난이도 분류 (frequencyLevel) | 1/2/3 단계 구분 | ✅ 완료 | 100% |
| 카테고리 분류 | 12개 카테고리 | ✅ 완료 | 100% |
| IPA 발음 기호 | 전 단어 포함 | ✅ 완료 | 100% |

**Data 진행률: 100%** ✅

---

### 🐛 Bug Fixes

| 버그 | 원인 | 수정 | 상태 |
|---|---|---|---|
| 단어 창 "학습할 단어가 없다" | TabView 자식에 authManager 미전달 | `.environment(authManager)` 명시 추가 | ✅ 수정 완료 |
| 문법 창 "문제가 없다" | TabView 자식에 authManager 미전달 | `.environment(authManager)` 명시 추가 | ✅ 수정 완료 |
| 시딩 후 데이터 조회 실패 | context.save() 누락 | `try? context.save()` 추가 | ✅ 수정 완료 |
| 첫 실행 시 빈 카드 덱 | SRS fallback 로직 부재 | 직접 Vocabulary fetch fallback 추가 | ✅ 수정 완료 |

**Bug Fix 진행률: 100%** ✅

---

## 3. 전체 진행률 요약

```
Foundation         ████████████ 100%
Vocabulary Swipe   ████████████ 100%
Grammar Quiz       ████████████ 100%
Gamification       ████████████ 100%
Design System      █████████░░░  74%
Static Data        ████████████ 100%
Bug Fixes          ████████████ 100%
─────────────────────────────────────
전체 Week 1         ██████████░░  87%
```

---

## 4. 미완료 항목 (이월)

| 항목 | 우선순위 | 예상 작업시간 |
|---|---|---|
| SignInView 브랜딩 (로고, 버튼 컬러) | Medium | 30분 |
| GrammarQuizView 브랜딩 마무리 | Medium | 30분 |
| 설정 탭 브랜딩 | Low | 20분 |
| CloudKit 동기화 실기기 테스트 | High | 2시간 |
| Xcode Cloud CI/CD 파이프라인 설정 | High | 2시간 |

---

## 5. 빌드 상태

```
xcodebuild -scheme Toeigo -destination 'platform=iOS Simulator,name=iPhone 17'
** BUILD SUCCEEDED **   ✅ (에러 0, 경고 0)
```

---

## 6. 기술 부채

| 항목 | 내용 | 우선순위 |
|---|---|---|
| CloudKit 컨테이너 ID 설정 | Xcode 프로젝트 Signing에 CloudKit 컨테이너 추가 필요 | High |
| `#Predicate` Optional 관계 | SpacedRepetitionService의 fetchNewVocabulary 쿼리 개선 | Medium |
| Unit Test 부재 | DataLoader, SpacedRepetitionService 단위 테스트 작성 | Medium |
| 접근성(Accessibility) 라벨 | VoiceOver 지원 레이블 미적용 | Low |

---

*보고서 작성: 2026년 4월 4일*  
*다음 스프린트: Week 2 — CloudKit Sync & Xcode Cloud CI/CD*
