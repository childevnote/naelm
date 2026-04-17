# Naelm

TOEIC 학습을 위한 iOS 앱입니다. 단어와 문법을 간격 반복 알고리즘 기반으로 체계적으로 학습할 수 있으며, 게이미피케이션 요소와 통계 대시보드를 제공합니다.

---

## 목차

- [개요](#개요)
- [주요 기능](#주요-기능)
- [화면 구성](#화면-구성)
- [데이터 모델](#데이터-모델)
- [핵심 서비스](#핵심-서비스)
- [기술 스택](#기술-스택)
- [프로젝트 구조](#프로젝트-구조)

---

## 개요

Naelm은 TOEIC 목표 점수를 설정하고 맞춤형 단어·문법 학습을 진행하는 iOS 앱입니다. Sign in with Apple로 인증하며, SwiftData와 CloudKit을 통해 데이터를 로컬 저장하고 자동 동기화합니다.

- 지원 플랫폼: iOS
- 언어: Swift
- 폰트: Pretendard (Regular, Medium, SemiBold, Bold)

---

## 주요 기능

### 인증

- Sign in with Apple을 통한 로그인/로그아웃
- Keychain에 사용자 인증 정보 보관
- 앱 재실행 시 인증 상태 자동 복원

### 온보딩

- 목표 TOEIC 점수 선택 (600 / 700 / 800 / 900)
- 수준 파악 테스트: 선택한 목표 점수 구간에 맞는 문제 출제, 10초 제한 타이머
- 테스트 결과를 기반으로 현재 추정 수준 저장
- 온보딩 완료 후 메인 화면으로 진입

### 단어 학습

- 스와이프 카드 방식 학습 (오른쪽: 알아요 / 왼쪽: 모르겠어요)
- 카드 앞면: 영어 단어, 발음 기호, 품사
- 카드 뒷면: 한국어 뜻, 예문(영어/한국어), TOEIC 카테고리, 동의어, 다중 의미 지원
- 제한 시간 설정 가능 (5~25초, 기본 15초), 타이머 만료 시 자동 스와이프
- 세션 진행 중 단어 북마크(저장) 기능
- 학습 완료 후 세션 결과 화면 표시 (학습 단어 수, 정답률, 획득 XP, 소요 시간)
- 일일 학습 목표 달성 여부 표시

### 문법 퀴즈

- Duolingo 스타일 빈칸 채우기 4지선다 문제
- TOEIC Part 5/6 기반 문제 구성
- 정답/오답 즉시 피드백 (애니메이션 포함)
- 오답 시 문법 설명, 올바른 예문, 틀린 예문, 팁 하단 시트로 표시
- 제한 시간 설정 가능 (5~25초, 기본 15초)
- 세션 완료 후 결과 화면 표시

### 간격 반복 복습

- SM-2 알고리즘 기반 복습 일정 자동 계산
- 오늘 복습 예정인 단어/문법 항목 별도 세션으로 제공
- 정답 품질(0~5등급)에 따라 다음 복습 간격과 난이도 계수 업데이트
- 오답 시 간격 리셋, 정답 시 간격 점진 증가
- 사용자가 직접 "학습할게요"로 복습 대상 단어 표시 가능

### 학습 대시보드

- 현재 연속 학습일(스트릭) 표시
- 오늘 학습한 단어 수 / 문법 수 / 일일 목표 대비 진행률
- 오늘 복습 예정 단어 수 / 문법 수
- 7일간 학습 활동 막대 그래프 (XP 기준, 일일 목표 달성일 강조)
- 총 학습 단어 수, 총 학습 일수, 목표 점수 표시
- 월간 학습 달력 (활동일 표시)
- 단어 학습 / 문법 퀴즈 / 복습 세션 진입 버튼
- 당겨서 새로고침(pull to refresh) 지원

### 북마크

- 학습 중 저장한 단어 목록 확인
- 카테고리, 품사, 난이도 레벨 필터 지원
- 의미 표시/숨기기 토글
- 북마크 삭제 기능

### 랭킹

- 이번 달 XP 총합 기반 점수 산정
- 매월 1일 자동 초기화
- 친구 순위 / 전체 순위 탭 구분

### 마이페이지

- 현재 추정 수준 및 목표 점수 표시
- 연속 학습일, 누적 XP, 레벨, 레벨 진행도 표시
- 총 학습 단어 수 / 문법 수
- 문제 유형별(카테고리별) 정답/오답 통계 그래프
- 타이머 활성화 여부 및 단어/문법 타이머 시간 개별 설정
- 다크모드 / 라이트모드 / 시스템 설정 연동 테마 선택
- 일일 날짜별 응원 메시지 (30개 순환, 마퀴 배너)
- 학습 데이터 초기화
- 계정 삭제 (확인 단계 포함)
- 개선사항 피드백 전송

### 게이미피케이션

- XP(경험치) 획득: 단어 학습, 문법 퀴즈, 복습 완료 시 지급
- 레벨 시스템: 누적 XP 기반 레벨 계산 (레벨 n마다 n×100 XP 필요)
- 레벨 진행도 바 및 다음 레벨까지 남은 XP 표시
- 일일 목표 달성 여부 기록

---

## 화면 구성

앱은 탭 기반으로 구성되며, 각 탭은 하단 탭바로 이동합니다.

| 탭 | 화면 |
|---|---|
| 학습 홈 | DashboardView |
| 단어 학습 | VocabularyStudyView (SwipeableCardStack) |
| 문법 퀴즈 | GrammarQuizView |
| 랭킹 | RankingView |
| 마이페이지 | MyPageView |

진입 흐름:

1. SplashView (로딩)
2. Sign in with Apple (미인증 시)
3. OnboardingView (최초 실행 시) → 목표 점수 선택 → 수준 파악 테스트 → 결과 확인
4. 메인 탭바 화면

학습 세션 완료 후에는 LessonCompleteView에서 결과를 확인합니다.

---

## 데이터 모델

SwiftData를 사용하며 CloudKit으로 자동 동기화됩니다.

| 모델 | 설명 |
|---|---|
| UserProfile | 사용자 프로필. 목표 점수, 추정 수준, 일일 목표, 타이머 설정, 온보딩 완료 여부 |
| Vocabulary | TOEIC 단어. 영어, 한국어 뜻, 발음, 품사, 빈도 레벨, 예문, 카테고리, 동의어 |
| VocabularyMeaning | 단어의 다중 의미/품사 항목. Vocabulary와 1:N 관계 |
| Grammar | TOEIC 문법 포인트. 제목, 설명, TOEIC Part, 난이도, 예문, 팁, 빈칸 정답, 오답 보기 |
| LearningProgress | 단어/문법별 학습 진행 상태. SM-2 필드(interval, repetitions, easeFactor, nextReviewDate), 정답/오답 횟수, 스트릭, 숙달 여부, 복습 표시 여부 |
| UserActivity | 일별 학습 활동 로그. 학습 단어/문법 수, 학습 시간, 퀴즈 정답률, XP, 일일 목표 달성 여부 |
| MonthlyScore | 월별 토익 점수 기록. 점수, 목표 달성률 |
| Friendship | 사용자 간 친구/차단 관계 |
| BookmarkedWord | 사용자가 저장한 단어 목록. Vocabulary와 연결 |

번들에 포함된 `Vocabulary.json`, `Grammar.json`에서 앱 최초 실행 시 데이터를 시딩합니다. wordID/grammarID 기반으로 중복 삽입을 방지합니다.

---

## 핵심 서비스

### SpacedRepetitionService

SM-2(SuperMemo 2) 알고리즘을 구현한 순수 함수 기반 서비스입니다.

- 사용자 응답 품질(0~5등급)을 입력받아 다음 복습 간격, 반복 횟수, 난이도 계수, 복습 예정일 계산
- 품질 3 미만: 간격 리셋 및 처음부터 재학습
- 품질 3 이상: 반복 횟수에 따라 간격 점진 증가 (1일 → 6일 → 이전 간격 × easeFactor)
- easeFactor 최솟값: 1.3

### GamificationService

- 연속 학습 스트릭 계산
- 일일 XP 집계 및 목표 달성 판정
- 7일간 학습 활동 히스토리 제공 (DailySummary)
- 누적 XP 기반 레벨 및 진행도 계산

### LearningSessionManager

- 학습 세션 전반 관리 (시작, 진행, 완료)
- 세션 중 XP 적립 및 UserActivity 기록
- 일일 목표 달성 여부 판정

### CardViewModel / QuizViewModel

- 단어 카드 덱 / 문법 퀴즈 문제 생성 및 상태 관리
- 목표 점수에 맞는 빈도 레벨 필터링
- 오답 보기 무작위 배치

### DataLoader

- 번들 JSON에서 Vocabulary, Grammar 데이터 로딩 및 시딩
- 중복 체크 후 신규 항목만 삽입

### HapticManager

- 탭, 정답, 오답 등 상황별 햅틱 피드백 제공

### KeychainHelper

- Sign in with Apple 인증 정보 Keychain 저장/조회/삭제

---

## 기술 스택

- Swift, SwiftUI
- SwiftData (로컬 영속 저장)
- CloudKit (자동 동기화)
- AuthenticationServices (Sign in with Apple)
- SM-2 간격 반복 알고리즘
- Pretendard 커스텀 폰트

---

## 프로젝트 구조

```
Naelm/
├── NaelmApp.swift                  # 앱 진입점, ModelContainer 설정, RootView
├── ContentView.swift               # RootView 래퍼
├── Models.swift                    # SwiftData 모델 전체 정의
├── DataLoader.swift                # JSON 시드 데이터 로딩
├── SplashView.swift                # 스플래시 화면
├── OnboardingView.swift            # 온보딩 (목표 점수 선택 + 수준 파악 테스트)
├── DashboardView.swift             # 학습 홈 대시보드
├── VocabularyStudyView.swift       # 단어 학습 (스와이프 카드)
├── VocabularyCardView.swift        # 단어 카드 UI 컴포넌트
├── SwipeableCardStack.swift        # 스와이프 카드 스택 컴포넌트
├── GrammarQuizView.swift           # 문법 퀴즈
├── BookmarkListView.swift          # 북마크 단어 목록
├── RankingView.swift               # 랭킹
├── MyPageView.swift                # 마이페이지
├── LessonCompleteView.swift        # 세션 완료 결과 화면
├── FeedbackView.swift              # 피드백 입력
├── CardViewModel.swift             # 단어 카드 뷰모델
├── QuizViewModel.swift             # 문법 퀴즈 뷰모델
├── LearningSessionManager.swift    # 학습 세션 관리
├── SpacedRepetitionService.swift   # SM-2 알고리즘
├── GamificationService.swift       # XP, 레벨, 스트릭
├── KeychainHelper.swift            # Keychain 인증 정보 관리
├── HapticManager.swift             # 햅틱 피드백
├── AppFonts.swift                  # Pretendard 폰트 설정
├── AppLogger.swift                 # 로깅
├── BrandColors.swift               # 색상 및 테마 정의
├── Vocabulary.json                 # 단어 시드 데이터
├── Grammar.json                    # 문법 시드 데이터
└── Assets.xcassets/                # 앱 아이콘, 색상 에셋
```
