# 20260507 1차 통합 작업 보고서
**작업 일시:** 2026-05-07  
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
| 기존 항목 수 | 680개 | 680개 |
| JSON 문법 오류 | 없음 | 없음 |
| 누락된 필수 키 | **0건** | **0건** |
| 잘못된 데이터 타입 | 없음 | 없음 |
| ID 중복 | 없음 | 없음 |
| ID 누락/불연속 | 없음 | 없음 |
| frequencyLevel 분포 | 1~4단계 각 170개 (균등) | - |
| difficultyLevel 분포 | - | 1~4단계 각 170개 (균등) |

### 1-3. 수정 내역

기존 680개 항목에 대한 전수 검사 결과, 아래 기준을 모두 통과하였습니다:
- JSON 파싱 오류: **0건**
- 필수 키 누락: **0건** (Vocabulary 11개 필드, Grammar 13개 필드 전수 확인)
- ID 연속성: vocab_001 ~ vocab_680, gram_001 ~ gram_680 **완전 연속**
- 데이터 타입 오류: **0건**
- 논리적 결함 (복수 정답 가능성 등): **0건** (이전 작업 주기에서 정제 완료)

> **비고:** 기존 데이터는 이전 작업 주기(20260430)에서 이미 정제가 완료된 상태로, 이번 주기에서는 신규 생성에 집중하였습니다.

---

## 2. Trend Search Summary (최신 토익 빈출 트렌드 조사 요약)

### 2-1. 어휘 트렌드 (2024~2025 토익 빈출 핵심)

웹 검색을 통해 확인된 최신 토익 빈출 어휘 트렌드는 다음과 같습니다:

**기본 업무 동작 동사 (FreqLevel 1)**
- `expire`, `address`, `access`, `mention`, `gather` — 이메일·안내문·비즈니스 회화의 핵심 동사군. 특히 `access`(IT·HR 포털 접근)와 `address`(문제 처리)는 Part 5·7 빈출 표현.

**이메일·공지 핵심 명사 (FreqLevel 2)**
- `freight`, `eligibility`, `enrollment`, `clarification`, `collaboration` — 물류·HR 공지문(Part 7), 이메일·메모(Part 7)에서 극빈출. `clarification`은 "request a clarification" 연어 형태로 Part 5에도 출제.

**비즈니스 전략·재무 어휘 (FreqLevel 3)**
- `diversification`, `exemption`, `escalation`, `valuation`, `prototype` — 전략 보고서·법률 문서·기술 개발 문맥에서 빈출. `escalation clause`(물가 연동 조항)는 계약서 파트 전형 표현.

**고급 법률·금융 어휘 (FreqLevel 4)**
- `renegotiate`, `statutory`, `receivership`, `insolvent`, `foreclose` — 법무·금융 보도문·계약 분쟁 문맥. `statutory` (법정의)는 고용법 문서에서 빈출, `renegotiate`는 계약 개정 시나리오에서 다수 출제.

### 2-2. 문법 트렌드 (2024~2025 수험생 다빈도 오답 포인트)

- **비례 비교 구문:** `the + 비교급 ... the + 비교급` — the 관사 생략 오류가 가장 많은 오답 유형 중 하나
- **목적 부정사:** `so as to + V원형` — `in order to`와 동의 표현으로 격식 문서에서 빈출, V-ing 혼동 빈발
- **5형식 목적격 보어:** `make/keep + O + 형용사` — 부사(-ly) 혼동으로 인한 오답률 높음
- **가정법 현재:** `suggest/recommend + that + S + V원형` — 3인칭 단수 -(e)s 오류가 수험생 최다 오답 포인트
- **비교 강조:** `by far + the + 최상급` — 최상급 자리에 부사 형태 혼동
- **상호 대명사:** `each other's` — each others(잘못된 복수형) 오류 식별
- **사역동사 패턴:** `have + O + V원형` — to V(부정사) 혼동, have/make/let 공통 구조 이해 부족
- **결과 동사 구분:** `result in vs result from` — 방향(원인→결과 vs 결과←원인) 혼동

---

## 3. Generation and Post-Audit Summary

### 3-1. 신규 추가 Vocabulary 항목 (20개)

| wordID | English | 한국어 | 품사 | Level | Category |
|--------|---------|-------|------|-------|----------|
| vocab_681 | expire | 만료되다, 만기가 되다 | verb | 1 | Finance |
| vocab_682 | address | 처리하다, 다루다; 주소 | verb | 1 | General Business |
| vocab_683 | access | 접근하다, 이용하다; 접근권 | verb | 1 | IT |
| vocab_684 | mention | 언급하다; 언급 | verb | 1 | General Business |
| vocab_685 | gather | 모으다, 수집하다; 모이다 | verb | 1 | General Business |
| vocab_686 | freight | 화물; 화물 운송료 | noun | 2 | Logistics |
| vocab_687 | eligibility | 자격, 적격성 | noun | 2 | HR |
| vocab_688 | enrollment | 등록, 입학, 가입 | noun | 2 | General Business |
| vocab_689 | clarification | 명확화, 해명, 설명 요청 | noun | 2 | General Business |
| vocab_690 | collaboration | 협력, 공동 작업 | noun | 2 | General Business |
| vocab_691 | diversification | 다각화, 다양화 | noun | 3 | Strategy |
| vocab_692 | exemption | 면제, 적용 제외 | noun | 3 | Legal |
| vocab_693 | escalation | 확대, 단계적 증가, 상부 보고 | noun | 3 | General Business |
| vocab_694 | valuation | 가치 평가, 평가액 | noun | 3 | Finance |
| vocab_695 | prototype | 시제품, 원형 | noun | 3 | Manufacturing |
| vocab_696 | renegotiate | 재협상하다 | verb | 4 | Legal |
| vocab_697 | statutory | 법정의, 법령에 의한 | adjective | 4 | Legal |
| vocab_698 | receivership | 법정 관리, 파산 관재 | noun | 4 | Finance |
| vocab_699 | insolvent | 지급 불능의, 파산 상태인 | adjective | 4 | Finance |
| vocab_700 | foreclose | 담보권을 행사하다, 압류하다 | verb | 4 | Legal |

### 3-2. 신규 추가 Grammar 항목 (20개)

| grammarID | Title | 난이도 | Category |
|-----------|-------|--------|----------|
| gram_681 | 비교 - the + 비교급, the + 비교급 (비례 비교 구문) | 1 | Comparison |
| gram_682 | 부정사 목적 - so as to + V원형 (= in order to) | 1 | Infinitive |
| gram_683 | 5형식 - make/keep + 목적어 + 형용사 (목적격 보어 자리) | 1 | Word Form |
| gram_684 | 가정법 현재 - suggest + that + S + (should) + V원형 | 1 | Subjunctive |
| gram_685 | 부사절 접속사 - as + S + V (~함에 따라, 비례·동시) | 1 | Conjunction |
| gram_686 | 대명사 - each other vs each other's (상호 대명사 소유격) | 2 | Pronoun |
| gram_687 | 어휘 - be apt to + V원형 (~하는 경향이 있다) | 2 | Infinitive |
| gram_688 | 비교 강조 - by far + the + 최상급 | 2 | Comparison |
| gram_689 | 동사 패턴 - spend/waste + 시간·돈 + V-ing | 2 | Gerund vs Infinitive |
| gram_690 | 전치사구 - with regard to vs in regard to | 2 | Prepositional Phrase |
| gram_691 | 동사 패턴 - be known for + 명사 vs be known to + V원형 | 3 | Prepositional Phrase |
| gram_692 | 접속사 - 명령문 + and (긍정 조건) vs 명령문 + or (부정 조건) | 3 | Conjunction |
| gram_693 | 동사 패턴 - keep + O + V-ing (계속 ~하게 유지하다) | 3 | Gerund vs Infinitive |
| gram_694 | 접속사 - as far as + S + V vs as long as | 3 | Conjunction |
| gram_695 | 관계대명사 - 전치사 + whom (격식 관계절) | 3 | Relative Clause |
| gram_696 | 접속사 - albeit (비록 ~일지라도, 격식 양보) | 4 | Conjunction |
| gram_697 | 분사구문 - with + O + 형용사 (상태 표현 with 구문) | 4 | Participial Construction |
| gram_698 | 어휘 구분 - result in vs result from | 4 | Prepositional Phrase |
| gram_699 | 어휘 - be attributable to + 명사 (~에 기인하다) | 4 | Word Form |
| gram_700 | 사역동사 - have + O + V원형 (능동 사역) | 4 | Causative Verb |

### 3-3. Post-Audit 자가 감사 체크리스트 결과

| 항목 | 결과 |
|------|------|
| 기출 적합성 — 지나치게 학술적·지엽적 어휘/문법 포함 여부 | **이상 없음** (모두 토익 Part 5/7 실제 문서 스타일 반영) |
| 복수 정답 원천 차단 — 오답 3개가 100% 오답인지 | **이상 없음** (아래 수정 내역 참조) |
| 스키마 일치 — 모든 필수 필드 누락 없이 작성 여부 | **이상 없음** (전 필드 완비) |
| 중복 체크 — 기존 및 신규 데이터 간 영단어/문법 개념 중복 | **이상 없음** (기존 680개 전체와 대조 완료) |

**반려/수정 기록:**

- `vocab_698` (초안: `divestiture`): 기존 vocab_419에 동일 단어(`divestiture`)가 이미 등재된 것 발견. **반려 후 `receivership`(법정 관리)으로 즉시 교체.** receivership은 기존 데이터에 없으며 TOEIC 법률·금융 Part 7 빈출 표현으로 확인됨.

- `gram_685` (as 접속사): 초안에서 distractors로 `Because`를 제안했으나, "Because the company's global presence expanded, its need for staff increased"가 논리적으로 허용될 수 있어 `Regardless of`(명사구 전치사, 절 접속 불가)로 교체하여 복수 정답 가능성 원천 차단.

- `gram_692` (명령문 + and/or): 초안에서 "File the report by Monday, or your submission will be accepted" 형태로 설계했으나, "or" 문장이 긍정 결과와 연결되는 경우 논리적 혼선이 있을 수 있어 "Submit... by Friday, and your request will be processed"(명확한 긍정 결과)로 재설계하여 정오답 논리를 명확화.

- `gram_696` (albeit): 초안 incorrectExample에서 "despite by a narrow margin"을 사용했으나, despite는 전치사이고 "by a narrow margin"은 전치사구이므로 despite 뒤에 올 수 없어 정오답 구분이 명확함. 최종적으로 `although by a very narrow margin`(although 뒤에 절이 없어 비문법적)을 incorrectExample로 확정. 오답은 `although,despite,whereas` — 모두 절/구 구조 호환 불가 또는 의미 불일치로 100% 오답 확인.

---

## 4. Final Verification (최종 검증)

### 4-1. JSON 구조 검증

| 파일 | 항목 수 | 마지막 ID | 스키마 오류 | ID 중복 | ID 누락 |
|------|--------|----------|------------|---------|---------|
| Vocabulary.json | **700개** | vocab_700 | 0건 | 0건 | 0건 |
| Grammar.json | **700개** | gram_700 | 0건 | 0건 | 0건 |

### 4-2. ID 연속성 확인
- Vocabulary: vocab_001 → vocab_700 (연속, 누락 없음)
- Grammar: gram_001 → gram_700 (연속, 누락 없음)

### 4-3. frequencyLevel / difficultyLevel 분포

| Level | Vocabulary (신규 추가 후) | Grammar (신규 추가 후) |
|-------|--------------------------|----------------------|
| 1 | 175개 | 175개 |
| 2 | 175개 | 175개 |
| 3 | 175개 | 175개 |
| 4 | 175개 | 175개 |
| **합계** | **700개** | **700개** |

### 4-4. 결론
모든 데이터는 JSON 순수 배열 형식으로 저장되었으며, 스키마 일치·ID 연속성·난이도 균등 분포(각 175개)가 확인되었습니다. 작업 완료.
