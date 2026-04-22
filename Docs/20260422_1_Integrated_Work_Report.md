# Integrated Work Report — 2026-04-22 #1

## 1. Pre-Audit Results

| File | Item Count | Issues Found |
|------|-----------|--------------|
| Vocabulary.json | 400 | None |
| Grammar.json | 400 | None |

No missing keys, no duplicate IDs, no duplicate titles, and all `dataVersion` values were `1` across all 400 existing entries in both files.

---

## 2. New Vocabulary Items (vocab_401 ~ vocab_420)

### frequencyLevel 1 — Most Frequent TOEIC Business Words (vocab_401~405)

| ID | English | Korean | Category | PoS |
|----|---------|--------|----------|-----|
| vocab_401 | conference | 회의, 컨퍼런스 | Office | noun |
| vocab_402 | expense | 비용, 지출 | Finance | noun |
| vocab_403 | resign | 사직하다, 사임하다 | HR | verb |
| vocab_404 | evaluate | 평가하다, 사정하다 | Business Operations | verb |
| vocab_405 | recruit | 채용하다, 모집하다 | HR | verb |

### frequencyLevel 2 — High Frequency (vocab_406~410)

| ID | English | Korean | Category | PoS |
|----|---------|--------|----------|-----|
| vocab_406 | merger | 합병, 인수합병 | Finance | noun |
| vocab_407 | dividend | 배당금, 이익 배당 | Finance | noun |
| vocab_408 | deficit | 적자, 부족액 | Finance | noun |
| vocab_409 | payroll | 급여 명부, 급여 지급 총액 | HR | noun |
| vocab_410 | margin | 마진, 수익률, 여백 | Finance | noun |

### frequencyLevel 3 — Medium Frequency (vocab_411~415)

| ID | English | Korean | Category | PoS |
|----|---------|--------|----------|-----|
| vocab_411 | franchise | 프랜차이즈, 가맹 사업 | Business Operations | noun |
| vocab_412 | mandate | 명령하다, 권한을 부여하다 | Corporate | verb |
| vocab_413 | outsourcing | 아웃소싱, 외주 처리 | Business Operations | noun |
| vocab_414 | deferral | 이연, 연기 | Finance | noun |
| vocab_415 | covenant | 계약 조건, 서약 | Legal | noun |

### frequencyLevel 4 — Lower Frequency, TOEIC-Relevant (vocab_416~420)

| ID | English | Korean | Category | PoS |
|----|---------|--------|----------|-----|
| vocab_416 | arbitrage | 차익거래, 재정 거래 | Finance | noun |
| vocab_417 | perpetuity | 영구, 영속성 | Finance | noun |
| vocab_418 | indemnity | 배상, 보상 | Legal | noun |
| vocab_419 | divestiture | 자산 매각, 사업 처분 | Corporate | noun |
| vocab_420 | solvency | 지급 능력, 지불 능력 | Finance | noun |

---

## 3. New Grammar Items (gram_401 ~ gram_420)

### difficultyLevel 1 — Basic (gram_401~405)

| ID | Title | Category | quizType |
|----|-------|----------|---------|
| gram_401 | 단순현재 vs 현재진행 - 습관적 행동 vs 현재 진행 동작 | Tense | form |
| gram_402 | 전치사 in/on/at - 시간 표현 기본 구분 | Preposition | usage |
| gram_403 | 관사 a vs an - 모음 발음 앞에서 an 사용 | Article | form |
| gram_404 | 주격 vs 목적격 인칭대명사 - 전치사 뒤 목적격 필수 | Pronoun | form |
| gram_405 | 주어-동사 수 일치 기본 - 수식어구 삽입에 의한 혼동 | Subject-Verb Agreement | form |

### difficultyLevel 2 — Intermediate (gram_406~410)

| ID | Title | Category | quizType |
|----|-------|----------|---------|
| gram_406 | 관계대명사 which - 계속적 용법과 that의 불가 | Relative Clause | form |
| gram_407 | 비교급 강조 부사 - much/far/even/still + 비교급 | Comparative | usage |
| gram_408 | 조동사 must not vs do not have to - 금지 vs 불필요 | Modal Verb | meaning |
| gram_409 | 관계대명사 whom - 전치사+whom 목적격 구조 | Relative Clause | form |
| gram_410 | 원급 비교 부정형 - not as + 형용사 + as 구조 | Comparative | form |

### difficultyLevel 3 — Advanced (gram_411~415)

| ID | Title | Category | quizType |
|----|-------|----------|---------|
| gram_411 | 가정법 현재 vs 가정법 과거 - 실현 가능성 구분 | Conditional | form |
| gram_412 | 도치 - Only after + 절 문두 배치 시 주절 도치 | Inversion | form |
| gram_413 | 조동사 완료형 - should have p.p. 후회와 비판 표현 | Modal Verb | meaning |
| gram_414 | 복합관계대명사 whoever vs whomever - 절 내 역할 구별 | Relative Clause | form |
| gram_415 | 명사절 접속사 whether vs if - 주어절·전치사 목적어 위치 | Noun Clause | usage |

### difficultyLevel 4 — Expert (gram_416~420)

| ID | Title | Category | quizType |
|----|-------|----------|---------|
| gram_416 | 완료분사구문 수동 - Having been + p.p.와 Being + p.p. 구별 | Participle | form |
| gram_417 | 강조 구문 분열문 - It is/was ~ that 구조와 that vs which | Emphasis | form |
| gram_418 | 상관접속사 수 일치 - not only A but also B에서 B 기준 동사 | Correlative Conjunction | form |
| gram_419 | 혼합 가정법 - If + 과거완료(조건), would + 동사원형(현재 결과) | Conditional | form |
| gram_420 | lest ~ (should) + 동사원형 - 두려움·예방 목적 부사절 | Subjunctive | form |

---

## 4. Post-Audit Results

| Check | Result |
|-------|--------|
| All 20 vocab items have all required fields | PASS |
| All 20 grammar items have all required fields | PASS |
| No duplicate vocab titles with existing data | PASS |
| No duplicate grammar titles with existing data | PASS |
| Grammar distractors are 100% wrong answers | PASS |
| All IDs are sequential (vocab_401~420, gram_401~420) | PASS |
| Vocab frequencyLevel distribution (5 per level 1-4) | PASS |
| Grammar difficultyLevel distribution (5 per level 1-4) | PASS |
| All dataVersion = 1 | PASS |
| All toeicPart = "Part 5" | PASS |
| Distractors comma-separated, no spaces, 3 per item | PASS |

---

## 5. File Write Summary

| File | Before | After | Items Added |
|------|--------|-------|-------------|
| Naelm/Vocabulary.json | 400 items | 420 items | 20 |
| Naelm/Grammar.json | 400 items | 420 items | 20 |

---

*Generated on 2026-04-22 by Naelm Content Engineering Pipeline*
