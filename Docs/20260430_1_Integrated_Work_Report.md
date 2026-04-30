# 20260430 1차 통합 작업 보고서
**작업 일시:** 2026-04-30  
**작업 유형:** Pre-Audit + Trend Search + Generation + Post-Audit + Finalize  
**담당:** 수석 데이터 엔지니어 / 토익 콘텐츠 크리에이터 (Copilot Agent)

---

## 1. Pre-Audit Report (기존 데이터 분석 및 정제)

### 1-1. 대상 파일
- `Naelm/Vocabulary.json`
- `Naelm/Grammar.json`

### 1-2. 분석 결과 요약

| 항목 | Vocabulary.json | Grammar.json |
|------|----------------|--------------|
| 기존 항목 수 | 620개 | 620개 |
| JSON 문법 오류 | 없음 | 없음 |
| 누락된 필수 키 | **0건** | **0건** |
| 잘못된 데이터 타입 | 없음 | 없음 |
| ID 중복 | 없음 | 없음 |
| ID 누락/불연속 | 없음 | 없음 |
| frequencyLevel 분포 | 1~4단계 각 155개 (균등) | - |
| difficultyLevel 분포 | - | 1~4단계 각 155개 (균등) |

### 1-3. 수정 내역

**발견된 이슈: 동일 단어/문법 개념 중복 (Content Duplicate) — 4건 수정**

| 대상 파일 | ID | 문제 | 처리 방법 |
|-----------|-----|------|----------|
| Vocabulary.json | vocab_582 | "agenda" 중복 (vocab_221과 동일 단어, 동일 FreqLevel) | "notice" (알림, 공지)로 교체 |
| Vocabulary.json | vocab_596 | "arbitration" 중복 (vocab_396과 동일 단어, 동일 FreqLevel) | "deposition" (진술서, 증언)으로 교체 |
| Vocabulary.json | vocab_597 | "remuneration" 중복 (vocab_153과 동일 단어, 동일 FreqLevel) | "embezzlement" (횡령)으로 교체 |
| Grammar.json | gram_582 | "품사 - 부사 자리 (동사 수식) - promptly" 제목 및 blankTarget 중복 (gram_043과 동일) | 테스트 대상 단어를 "efficiently"로 교체, 예문 및 설명 전면 재작성 |

> **비고:** ID 중복·누락, JSON 문법 오류, 스키마 오류는 없었으며, 위 4건은 모두 동일 학습 앱에서 동일 단어/개념이 중복 출제되는 학습 데이터 품질 이슈로 식별되어 수정함.

---

## 2. Trend Search Summary (최신 토익 빈출 트렌드 조사 요약)

### 2-1. 어휘 트렌드 (2023~2025 토익 빈출 핵심)
웹 검색을 통해 확인된 최신 토익 빈출 어휘 트렌드는 다음과 같습니다:

**비즈니스/사무 핵심 동사 (FreqLevel 1)**
- `proceed`, `attract`, `reserve`, `publish` — 기본 업무 커뮤니케이션 필수 동사
- `representative` — 고객 서비스, HR 문서에서 극빈출 명사

**이메일/문서 핵심 명사 (FreqLevel 2)**
- `requirement`, `registration`, `accommodation`, `revision`, `authorization` — 공지문·안내문 Part 7 핵심어

**비즈니스 전략·계획 어휘 (FreqLevel 3)**
- `supplement`, `partnership`, `resolution`, `commitment`, `modification` — 경영 보고서·기사 유형 빈출

**고급 법률·경영 어휘 (FreqLevel 4)**
- `proliferation`, `concession`, `impediment`, `restitution`, `encapsulate` — 법무·협상·분석 보고서 문맥

### 2-2. 문법 트렌드 (2023~2025 수험생 다빈도 오답 포인트)
- **구동사(Phrasal Verbs):** `carry out`, `bring about`, `run out of`, `look into`, `put up with`, `come up with` — 실제 비즈니스 맥락에서 빈출, 오답률 높음
- **to부정사 vs 동명사 혼동:** `try/forget/regret + V-ing vs to V` 의미 구분 — Part 5 최빈출 오류 유형
- **조동사 구문:** `had better + 동사원형`, `used to vs be used to` — 형태 및 의미 혼동 빈발
- **전치사 및 전치사구:** `except for`, `along with`, `upon + V-ing`, `in charge of` — 문맥적 의미 선별 문제 다수 출제
- **도치 구문:** `Not until + S + V` 강조 도치 — 고난도 Part 5 빈출

---

## 3. Generation and Post-Audit Summary

### 3-1. 신규 추가 Vocabulary 항목 (20개)

| wordID | English | 한국어 | 품사 | Level | Category |
|--------|---------|-------|------|-------|----------|
| vocab_621 | proceed | 진행하다, 나아가다 | verb | 1 | General Business |
| vocab_622 | attract | 끌어들이다, 유치하다 | verb | 1 | Marketing |
| vocab_623 | representative | 대표자, 담당자 | noun | 1 | HR |
| vocab_624 | reserve | 예약하다; 비축하다 | verb | 1 | General Business |
| vocab_625 | publish | 발행하다, 게시하다 | verb | 1 | General Business |
| vocab_626 | requirement | 요건, 조건 | noun | 2 | HR |
| vocab_627 | registration | 등록 | noun | 2 | General Business |
| vocab_628 | accommodation | 숙박 시설; 편의, 조정 | noun | 2 | Travel |
| vocab_629 | revision | 수정, 개정 | noun | 2 | General Business |
| vocab_630 | authorization | 승인, 허가 | noun | 2 | Finance |
| vocab_631 | supplement | 보충하다; 보충 자료 | verb | 3 | General Business |
| vocab_632 | partnership | 파트너십, 제휴 | noun | 3 | General Business |
| vocab_633 | resolution | 해결, 결의 | noun | 3 | General Business |
| vocab_634 | commitment | 헌신, 약속 | noun | 3 | HR |
| vocab_635 | modification | 수정, 변경 | noun | 3 | Manufacturing |
| vocab_636 | proliferation | 급증, 확산 | noun | 4 | IT |
| vocab_637 | concession | 양보, 특허권 | noun | 4 | Legal |
| vocab_638 | impediment | 장애물, 방해 | noun | 4 | General Business |
| vocab_639 | restitution | 배상, 원상복구 | noun | 4 | Legal |
| vocab_640 | encapsulate | 압축하다, 요약하다 | verb | 4 | General Business |

### 3-2. 신규 추가 Grammar 항목 (20개)

| grammarID | Title | 난이도 | Category |
|-----------|-------|--------|----------|
| gram_621 | 전치사 - except for (~을 제외하고) | 1 | Preposition |
| gram_622 | 부정사 - 형용사 + enough + to V | 1 | Infinitive |
| gram_623 | 연어 - carry out (수행하다) | 1 | Collocation |
| gram_624 | 전치사 - along with (~와 함께) | 1 | Preposition |
| gram_625 | 품사 - 형용사 자리 (명사 수식) - excessive | 1 | Word Form |
| gram_626 | 전치사 - upon + V-ing (하자마자) | 2 | Preposition |
| gram_627 | 연어 - bring about (야기하다) | 2 | Collocation |
| gram_628 | 어휘 - used to V vs be used to V-ing | 2 | Vocabulary |
| gram_629 | 연어 - run out of (~가 다 떨어지다) | 2 | Collocation |
| gram_630 | 전치사구 - in charge of (~의 책임을 맡은) | 2 | Prepositional Phrase |
| gram_631 | 연어 - refrain from V-ing (자제하다) | 3 | Collocation |
| gram_632 | 조동사 - had better + V원형 (강한 권고) | 3 | Modal Verb |
| gram_633 | 어휘 구동사 - look into vs 유사 구동사 | 3 | Vocabulary |
| gram_634 | 동명사 vs 부정사 - try + V-ing vs try + to V | 3 | Gerund vs Infinitive |
| gram_635 | 동명사 vs 부정사 - forget + V-ing vs forget + to V | 3 | Gerund vs Infinitive |
| gram_636 | 어휘 구동사 - put off vs put forward vs put up with | 4 | Phrasal Verb |
| gram_637 | 어휘 구동사 - come up with (~을 착안하다) | 4 | Phrasal Verb |
| gram_638 | 연어 - make an effort vs 유사 연어 구별 | 4 | Collocation |
| gram_639 | 동명사 vs 부정사 - regret + V-ing vs regret + to V | 4 | Gerund vs Infinitive |
| gram_640 | 도치 - Not until + S + V (부정어 문두 도치) | 4 | Inversion |

### 3-3. Post-Audit 자가 감사 체크리스트 결과

| 항목 | 결과 |
|------|------|
| 기출 적합성 — 지나치게 학술적·지엽적 어휘/문법 포함 여부 | **이상 없음** (모두 토익 Part 5/7 실제 문서 스타일 반영) |
| 복수 정답 원천 차단 — 오답 3개가 100% 오답인지 | **이상 없음** (단, 아래 주의 사항 참조) |
| 스키마 일치 — 모든 필수 필드 누락 없이 작성 여부 | **이상 없음** |
| 중복 체크 — 기존 및 신규 데이터 간 영단어/문법 개념 중복 | **이상 없음** (기존 620개 전체와 대조 완료) |

**주의 사항 — 반려/수정 기록:**
- `gram_626` (upon + V-ing): 초안에서 distractor로 `After`를 제안했으나, "After + V-ing"도 문맥에 따라 의미상 허용될 수 있어 `Before`, `Without`, `Despite`로 교체하여 복수 정답 가능성 원천 차단.
- `gram_628` (used to vs be used to): 초안에서 정답을 "is used to"로 설계했으나, 과거 맥락(before joining)에서 "used to + V원형"이 정답이 되도록 문장을 재설계하여 오답 명확성 향상.
- `gram_630` (in charge of): 초안 distractor에 "besides"(~ 외에도)를 포함했으나, 이 단어가 추가의 의미로 along with와 유사하여 혼동 가능성이 있어 `in spite of`로 교체.
- `gram_634` (try + V-ing vs try + to V): 두 표현이 맥락에 따라 교환 가능한 경우를 방지하기 위해 문제 해결 실험 맥락(troubleshooting)으로 설계하고 정오답 예문 차이를 명확히 구분하여 확정.

---

## 4. Final Verification (최종 검증)

### 4-1. JSON 구조 검증

| 파일 | 항목 수 | 마지막 ID | 스키마 오류 | ID 중복 | ID 누락 |
|------|--------|----------|------------|---------|---------|
| Vocabulary.json | **640개** | vocab_640 | 0건 | 0건 | 0건 |
| Grammar.json | **640개** | gram_640 | 0건 | 0건 | 0건 |

### 4-2. ID 연속성 확인
- Vocabulary: vocab_001 → vocab_640 (연속, 누락 없음)
- Grammar: gram_001 → gram_640 (연속, 누락 없음)

### 4-3. frequencyLevel / difficultyLevel 분포

| Level | Vocabulary (신규 추가 후) | Grammar (신규 추가 후) |
|-------|--------------------------|----------------------|
| 1 | 160개 | 160개 |
| 2 | 160개 | 160개 |
| 3 | 160개 | 160개 |
| 4 | 160개 | 160개 |
| **합계** | **640개** | **640개** |

### 4-4. 결론
모든 데이터는 JSON 순수 배열 형식으로 저장되었으며, 스키마 일치·ID 연속성·난이도 균등 분포가 확인되었습니다. 작업 완료.
