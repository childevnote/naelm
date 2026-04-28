# 20260428_1_Integrated_Work_Report

> **생성일:** 2026년 04월 28일  
> **작업 차수:** 1차  
> **작업자:** Copilot 에이전트 (수석 데이터 엔지니어 역할)

---

## 1. Pre-Audit Report (기존 데이터 수정 내역)

### 1-1. Vocabulary.json 감사 결과

| 항목 | 결과 |
|------|------|
| 총 항목 수(감사 시점) | 500개 (vocab_001 ~ vocab_500) |
| ID 연속성 | ✅ 정상 |
| 필수 키 누락 | ✅ 없음 |
| 중복 english | ✅ 없음 |
| frequencyLevel 유효값 (1~4) | ✅ 전 항목 정상 |
| 수정 사항 | 없음 |

### 1-2. Grammar.json 감사 결과

| 항목 | 결과 |
|------|------|
| 총 항목 수(감사 시점) | 500개 (gram_001 ~ gram_500) |
| ID 연속성 | ✅ 정상 |
| 필수 키 누락 | ✅ 없음 |
| 중복 title | ✅ 없음 |
| difficultyLevel 유효값 (1~4) | ✅ 전 항목 정상 |
| 수정 사항 | gram_498, gram_499, gram_500 해설·오답 보기 정밀 보강 |

### 1-3. 기존 Grammar 개선 상세

| ID | 항목 | 수정 내용 |
|----|------|----------|
| gram_498 | 연어 - yield a return | `produce`처럼 정답 가능성이 열려 있던 설명을 제거하고, 오답 보기를 `make, do, reach`로 정비하여 복수 정답 가능성을 차단 |
| gram_499 | 전치사구 - pursuant to | `Pertaining to`처럼 의미상 유사하게 읽힐 수 있는 보기를 제거하고, 전치사 결합 자체가 틀린 보기만 남기도록 재설계 |
| gram_500 | 어휘 - expedite vs facilitate vs accelerate | 목적어를 `original signed documents`로 바꿔 `facilitate/accelerate`의 정답 가능성을 차단하고 해설을 재작성 |

---

## 2. Trend Search Summary (최신 토익 빈출 트렌드)

최근 5년(2020~2026) TOEIC 학습 자료·기출 경향 분석 결과, 이번 생성에는 아래 트렌드를 반영했습니다.

### 2-1. Vocabulary 트렌드

- **사무/회의 운영 어휘:** attendee, agenda, correspondence, reschedule, guideline 계열의 실제 업무 커뮤니케이션 어휘 빈도가 높게 유지됨
- **HR·채용 어휘:** applicant, benefits, promotion, performance review, recruit 등 채용·복리후생 문맥 어휘가 반복 출제됨
- **재무·정산 어휘:** receipt, revenue, invoice, budget, profit margin, deduct 등 정산/비용 처리 관련 어휘 비중이 큼
- **물류·운영 어휘:** inspection, maintenance, shipment, inventory, retailer, outage 등 현장 운영·시설·시스템 장애 어휘가 최근 자료에서 자주 다뤄짐
- **고객 응답/설문 문맥:** survey, respondent, recipient처럼 설문 결과·안내 메일 문맥에 자연스럽게 등장하는 실용 어휘가 강화됨

> 반영 출처: 990prep TOEIC Business Vocabulary(2025/2026), Lingomelo Ultimate TOEIC Word List(2025), Redswan TOEIC Business Vocabulary(2026), Quizlet TOEIC Vocabulary Lists(2026), MyTOEICCoach/Famous James/Top-Students의 Part 5 어휘·문법 분석 자료

### 2-2. Grammar 트렌드

- **수 일치 함정:** one of the, the number of, each/every, 상관접속사 등 주어 판단형 문제 지속 빈출
- **전치사/접속사 구별:** because vs because of, in case vs in case of, 전치사구 결합 정확성 문제가 반복 출제됨
- **준동사 패턴:** be worth + V-ing, be responsible for + V-ing, prevent A from V-ing처럼 전치사 뒤 동명사 연결이 고빈도 함정으로 유지됨
- **격식 비즈니스 표현:** in response to, in advance of, in keeping with, whereby, per + 단위 같은 문서형 표현 비중이 높아짐
- **의미 혼동 어휘:** late vs lately, attend vs attend to처럼 형태는 익숙하지만 의미가 갈리는 함정형 보기가 자주 출제됨

---

## 3. Generation and Post-Audit Summary (신규 생성 및 자가 감사 요약)

### 3-1. 신규 Vocabulary 항목 (vocab_501 ~ vocab_520)

| ID | English | frequencyLevel | Category |
|----|---------|----------------|----------|
| vocab_501 | attendee | 1 | Meeting |
| vocab_502 | applicant | 1 | HR |
| vocab_503 | receipt | 1 | Finance |
| vocab_504 | maintenance | 1 | Operations |
| vocab_505 | survey | 1 | Customer Service |
| vocab_506 | guideline | 2 | Compliance |
| vocab_507 | inspection | 2 | Operations |
| vocab_508 | benefits | 2 | HR |
| vocab_509 | reschedule | 2 | Scheduling |
| vocab_510 | durable | 2 | Product Quality |
| vocab_511 | subscription | 3 | Technology |
| vocab_512 | respondent | 3 | Research |
| vocab_513 | retailer | 3 | Sales |
| vocab_514 | tentative | 3 | Scheduling |
| vocab_515 | renovate | 3 | Facilities |
| vocab_516 | premises | 4 | Security |
| vocab_517 | recipient | 4 | Communication |
| vocab_518 | oversee | 4 | Management |
| vocab_519 | deduct | 4 | Finance |
| vocab_520 | outage | 4 | Technology |

### 3-2. 신규 Grammar 항목 (gram_501 ~ gram_520)

| ID | Title | difficultyLevel | Category |
|----|-------|----------------|----------|
| gram_501 | 수 일치 - one of the + 복수명사 + 단수동사 | 1 | Subject-Verb Agreement |
| gram_502 | 접속사 vs 전치사 - because + 절 vs because of + 명사 | 1 | Conjunction |
| gram_503 | 표현 - be scheduled to + 동사원형 | 1 | Infinitive |
| gram_504 | 동명사 - be worth + V-ing | 1 | Gerund |
| gram_505 | 어휘 - attend vs attend to (참석하다 vs 처리하다) | 1 | Vocabulary |
| gram_506 | 전치사/접속사 - in case of + 명사 vs in case + 절 | 2 | Preposition |
| gram_507 | 전치사구 - in response to (~에 대한 응답으로) | 2 | Preposition |
| gram_508 | 동명사 - be responsible for + V-ing | 2 | Gerund |
| gram_509 | 어휘 - late vs lately (늦게 vs 최근에) | 2 | Vocabulary |
| gram_510 | 수 일치 - the number of + 복수명사 + 단수동사 | 2 | Subject-Verb Agreement |
| gram_511 | 전치사구 - instead of + V-ing | 3 | Gerund |
| gram_512 | 분사 - remaining + 명사 (남아 있는) | 3 | Participle |
| gram_513 | 전치사 - similar to (~와 유사한) | 3 | Preposition |
| gram_514 | 명사절 - whether A or B (양자택일 구조) | 3 | Noun Clause |
| gram_515 | 전치사구 - in advance of (~에 앞서) | 3 | Preposition |
| gram_516 | 전치사구 - in keeping with (~에 부합하여) | 4 | Preposition |
| gram_517 | 관계부사 - whereby (그에 따라/그 수단으로) | 4 | Relative Adverb |
| gram_518 | 비교급 강조 - far + 비교급 | 4 | Comparison |
| gram_519 | 전치사 - per + 단위/기준 | 4 | Preposition |
| gram_520 | 동사구 - prevent A from V-ing | 4 | Verb Pattern |


### 3-3. Post-Audit (자가 감사) 결과

| 검사 항목 | 결과 |
|---------|------|
| 신규 Vocabulary 20개 필수 필드 완비 | ✅ PASS |
| 신규 Grammar 20개 필수 필드 완비 | ✅ PASS |
| 기존/신규 Vocabulary 중복 없음 | ✅ PASS |
| 기존/신규 Grammar title 중복 없음 | ✅ PASS |
| Grammar distractors 3개 고정 및 정답 중복 없음 | ✅ PASS |
| Frequency/Difficulty 분포 (각 5개씩) | ✅ PASS |
| 기출 적합성 재검토 | ✅ PASS |

**반려/수정 기록:**  
- 초안 문법 후보 중 `whether or not` 유형은 `whether` 단독 정답 가능성이 남아 파기 후, `be responsible for + V-ing` 항목으로 교체했습니다.  
- 기존 gram_498~500은 복수 정답 가능성을 유발할 수 있는 보기·예문을 수정한 뒤 재검수했습니다.

---

## 4. Final Verification (최종 검증)

| 파일 | 최종 항목 수 | ID 범위 | 결과 |
|------|--------------|---------|------|
| Vocabulary.json | 520 | vocab_001 ~ vocab_520 | ✅ 연속 / 중복 없음 |
| Grammar.json | 520 | gram_001 ~ gram_520 | ✅ 연속 / 중복 없음 |

- ✅ 두 파일 모두 순수 JSON 배열 형식 유지
- ✅ Python `json.load()` 파싱 검증 완료
- ✅ 신규 Vocabulary frequencyLevel 1~4 각 5개씩 배치 완료
- ✅ 신규 Grammar difficultyLevel 1~4 각 5개씩 배치 완료
- ✅ Pre-Audit 수정 3건 반영 후 Grammar 정답 단일성 재확인 완료
