# Toeigo — TOEIC 학습 앱

---

## 주요 기능

### 단어 학습
- 스와이프: **왼쪽 = 알고있어요** / **오른쪽 = 학습할게요**
- 카드 탭으로 뒤집기 (뜻, 예문, 유의어 확인)
- 목표 점수에 따른 시간 제한 (600점대 15초 ~ 900점대 6초)
- 시간 초과 시 자동으로 "학습할게요" 처리

### 문법 퀴즈 (Part 5)
- 실제 TOEIC Part 5 기출 유형의 빈칸 채우기
- 품사, 시제/태, 접속사/전치사, 대명사, 어휘 문제 혼합
- 즉시 정답/오답 피드백 + 해설 Bottom Sheet
- 오답 복습 기능

### 학습 시스템
- **SM-2 간격 반복**: 틀린 문제는 복습 주기에 따라 재출제
- **일일 학습 목표**: 목표 점수와 추정 수준 gap 기반 자동 계산
- **복습 대기**: 단어/문법 각각 관리, 문법은 시도 횟수 추적
- **XP / 스트릭**: 매일 학습 시 XP 획득, 연속 학습일 추적

### 개인화
- 최초 로그인 시 목표 점수 선택 (600/700/800/900)
- 수준 파악 테스트 (단어 10 + 문법 10 = 20문제)
- 추정 수준에 맞는 단어/문법 추천
- 900점대 단어는 별도 배지로 표시

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | SwiftUI (iOS 17+, macOS 14+) |
| 로컬 DB | SwiftData |
| 인증 | Sign in with Apple |
| 동기화 | CloudKit (자동) |
| 아키텍처 | @Observable + MVVM |
| 간격 반복 | SM-2 알고리즘 |

---

## 프로젝트 구조

```
Toeigo/
├── ToeigoApp.swift          # @main, Auth, RootView, SignIn
├── Models.swift             # SwiftData 모델 (Vocabulary, Grammar, LearningProgress, UserProfile 등)
├── DataLoader.swift         # JSON → SwiftData 시드 로더
├── BrandColors.swift        # 브랜드 테마 (Forest Green)
├── HapticManager.swift      # 햅틱 피드백
│
├── OnboardingView.swift     # 목표점수 → 수준테스트 → 결과
├── DashboardView.swift      # 학습 홈 (XP링, 잔디밭, 오늘의 학습, 주간 차트)
├── VocabularyStudyView.swift# 단어 학습 세션 (타이머, 진행률)
├── VocabularyCardView.swift # 카드 UI (앞면/뒷면 flip)
├── SwipeableCardStack.swift # 스와이프 카드 스택 컴포넌트
├── CardViewModel.swift      # 단어 학습 ViewModel
├── GrammarQuizView.swift    # 문법 퀴즈 UI
├── QuizViewModel.swift      # 문법 퀴즈 ViewModel
├── RankingView.swift        # 순위 (월간 리셋, 친구/전체)
├── MyPageView.swift         # 마이페이지 (통계, 유형별 분석, 설정)
│
├── LearningSessionManager.swift  # 학습 세션 관리 + XP 계산
├── SpacedRepetitionService.swift  # SM-2 간격 반복
├── GamificationService.swift      # 스트릭, XP, 통계 쿼리
├── KeychainHelper.swift           # Keychain 저장/복원
│
├── Vocabulary.json          # 정적 단어 데이터 (100개, 600~900점 구간)
└── Grammar.json             # 정적 문법 데이터 (100개, TOEIC Part 5 실전)
```

---

## 데이터 아키텍처

### 정적 데이터 (앱 번들, Read-Only)
- `Vocabulary`: 영어, 한국어, 발음, 품사, 예문, 난이도, 카테고리
- `Grammar`: 문제 문장, 정답, 오답 보기, 문제 유형, 해설

### 동적 데이터 (CloudKit 동기화)
- `LearningProgress`: 사용자별 문제 풀이 기록, SM-2 파라미터, 복습 마킹
- `UserActivity`: 일별 XP, 학습 단어/문법 수
- `UserProfile`: 목표 점수, 추정 수준, 일일 목표
- `MonthlyScore`: 월간 순위 점수 (매월 초기화)

---

## 문법 문제 유형 분포

| 유형 | 개수 | 설명 |
|------|------|------|
| Word Form (품사) | 20 | 명사/형용사/부사/동사 자리 판별 |
| Tense (시제) | 7 | 현재/과거/미래/완료 시제 선택 |
| Voice (태) | 3 | 능동/수동태 선택 |
| Conjunction (접속사) | 12 | 접속사 vs 전치사, 접속부사 |
| Preposition (전치사) | 5 | 전치사구 활용 |
| Pronoun (대명사) | 4 | 인칭/소유/재귀/관계대명사 |
| Relative Clause | 3 | 관계대명사/관계부사 |
| Vocabulary (어휘) | 42 | 유사 어휘 변별, 콜로케이션 |
| 기타 | 4 | 수 일치, 가정법, 분사, to부정사 |

---

## 빌드 & 실행

### 요구사항
- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+
- Apple Developer 계정 (Sign in with Apple + CloudKit)

### 시뮬레이터 테스트
시뮬레이터에서는 Sign in with Apple이 지원되지 않으므로 (error 1000), DEBUG 빌드에서 "테스트 모드로 시작" 버튼을 사용한다.

---

## 순위 시스템

- **점수 공식**: `시도 횟수 x 0.3 + 정답 수 x 0.7`
- **매월 초기화**: `MonthlyScore.month` 필드 기준 ("2026-04")
- **친구/전체 탭**: `Friendship` 모델로 친구 관계 관리

---

## 개발 환경

- 1인 개발 + AI Pair Programming
- GitHub main 브랜치
- Xcode Cloud 자동 배포 (TestFlight)

---

## 커밋 컨벤션

[Conventional Commits](https://www.conventionalcommits.org/) 기반으로 작성한다.

### 형식

```
<type>(<scope>): <subject>
```

### Type

| Type | 설명 |
|------|------|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 기능 변경 없는 코드 구조 개선 |
| `style` | UI/UX 디자인 변경 (레이아웃, 색상, 애니메이션 등) |
| `data` | 정적 데이터(JSON) 추가/수정 |
| `docs` | 문서(README, devlog 등) 추가/수정 |
| `chore` | 빌드 설정, 프로젝트 구성 등 기타 변경 |
| `test` | 테스트 코드 추가/수정 |

### Scope (선택)

`quiz`, `vocab`, `dashboard`, `mypage`, `onboarding`, `auth`, `model`, `session`, `review`, `ranking` 등 변경 대상 모듈.

### 예시

```
feat(quiz): add timer bar to grammar quiz session
fix(quiz): fix goHome not working after quiz complete
style(dashboard): redesign grass chart layout
data(grammar): rewrite 100 questions for TOEIC Part 5
docs: add commit convention to README
```

### 규칙

- 커밋 메시지는 **영문**으로 작성한다.
- subject는 **소문자**로 시작하고, 마침표를 붙이지 않는다.
- 하나의 커밋은 **하나의 논리적 변경 단위**로 구성한다.
- 여러 파일에 걸친 변경이라도 하나의 기능/버그에 해당하면 하나의 커밋으로 묶는다.

---

## 코딩 규칙

- **SwiftUI + @Observable 패턴**: ViewModel은 `@Observable` 클래스, View에서는 `@State`로 소유.
- **네이밍**: Swift API Design Guidelines 준수. 타입은 PascalCase, 변수/함수는 camelCase.
- **이모지 금지**: UI 텍스트에 이모지를 사용하지 않는다. SF Symbols 아이콘만 사용.
- **CloudKit 호환**: SwiftData `@Model`의 모든 프로퍼티는 기본값 또는 Optional. `@Attribute(.unique)` 적극 활용.
- **다크모드**: 모든 화면은 라이트/다크 모두 대응. `BrandTheme`의 색상 시스템 사용.
- **브랜드 컬러**: Forest Green 계열 (`BrandTheme.accent`). 흰색과 조화.

---

## 라이선스

Private — All rights reserved.
