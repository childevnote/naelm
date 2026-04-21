# 20260421_1_Integrated_Work_Report

**작업 일시:** 2026-04-21  
**작업 차수:** 1차  
**대상 파일:** `Naelm/Vocabulary.json`, `Naelm/Grammar.json`

---

## 1. Pre-Audit Report (기존 데이터 수정 내역)

### 1-1. Vocabulary.json 감사 결과

| 항목 | 결과 |
|------|------|
| 총 항목 수 | 360개 (vocab_001 ~ vocab_360) |
| ID 연속성 | ✅ 정상 (vocab_001 ~ vocab_360 순번 누락/중복 없음) |
| 필수 키 누락 | ✅ 없음 |
| 중복 영단어 | ✅ 없음 |
| frequencyLevel 유효값 (1~4) | ✅ 전 항목 정상 |
| 레벨별 분포 | Level 1: 90개, Level 2: 90개, Level 3: 90개, Level 4: 90개 (균등) |

**Pre-Audit 수정 사항:** 구조적·논리적 오류 없음. 수정 불필요.

---

### 1-2. Grammar.json 감사 결과

| 항목 | 결과 |
|------|------|
| 총 항목 수 | 340개 (gram_001 ~ gram_340) |
| ID 연속성 | ✅ 정상 (gram_001 ~ gram_340 순번 누락/중복 없음) |
| 필수 키 누락 | ✅ 없음 |
| 중복 title | ✅ 없음 |
| difficultyLevel 유효값 (1~4) | ✅ 전 항목 정상 |
| toeicPart | ✅ 전 항목 "Part 5" |
| 레벨별 분포 | Level 1: 85개, Level 2: 85개, Level 3: 85개, Level 4: 85개 (균등) |
| 카테고리 분포 (상위 5) | Vocabulary: 69, Word Form: 48, Conjunction: 36, Tense: 25, Preposition: 23 |

**Pre-Audit 수정 사항:** 구조적·논리적 오류 없음. 수정 불필요.

---

## 2. Trend Search Summary (최신 토익 빈출 트렌드 조사 요약)

### 2-1. 어휘 트렌드 (2023~2024 기출 분석)

웹 검색을 통해 파악한 주요 토익 빈출 어휘 트렌드:

**신규 비즈니스 패러다임 어휘:**
- ESG (Environmental, Social, Governance) 관련: `sustainable`, `governance`
- 원격근무/디지털 전환: `telecommute`, `cybersecurity`, `scalable`
- 인재 개발: `upskill`, `recruitment`

**전통 비즈니스 핵심 어휘 (기존 미등재):**
- 계약·거래: `contract`, `renewal`, `vendor`
- 조직·인사: `executive`, `vacancy`
- 마케팅·영업: `consumer`, `launch`, `synergy`
- 프로젝트: `deliverable`, `correspondence`, `enclosure`
- 재무: `monetize`, `volatility`

### 2-2. 문법 트렌드 (2023~2024 수험생 오답률 상위 포인트)

웹 검색을 통해 파악한 수험생 오답률 높은 문법 포인트:

| 순위 | 문법 포인트 | 특징 |
|------|-------------|------|
| 1 | 현재완료 + since | since절과 현재완료의 필수 결합 |
| 2 | each of + 복수명사 + 단수동사 | 복수명사에 속아 복수 동사 선택 오류 |
| 3 | 전치사 뒤 동명사 | without/by/in 뒤 to 부정사 사용 오류 |
| 4 | 가정법 과거완료 형식 | if + had p.p. vs. 단순과거 혼동 |
| 5 | It is imperative that + 동사원형 | 3인칭 단수에 -s 붙이는 오류 |
| 6 | No sooner had...than 도치 | 도치 미적용 오류 |
| 7 | 소유격 관계대명사 whose | which와 혼동 |
| 8 | 완료 수동 분사구문 Having been p.p. | Being p.p.와 시제 혼동 |

---

## 3. Generation & Post-Audit Summary

### 3-1. 새로 추가된 어휘 항목 (20개)

| wordID | English | Korean | frequencyLevel | Category |
|--------|---------|--------|---------------|----------|
| vocab_361 | contract | 계약, 계약서 | 1 | Legal |
| vocab_362 | executive | 임원, 경영진 | 1 | Management |
| vocab_363 | vacancy | 공석, 빈 자리 | 1 | HR |
| vocab_364 | consumer | 소비자, 고객 | 1 | Marketing |
| vocab_365 | launch | 출시하다, 시작하다 | 1 | Marketing |
| vocab_366 | renewal | 갱신, 재개 | 2 | Legal |
| vocab_367 | vendor | 공급업체, 판매상 | 2 | General Business |
| vocab_368 | correspondence | 서신, 공문, 소통 | 2 | Communication |
| vocab_369 | deliverable | 납품물, 결과물 | 2 | General Business |
| vocab_370 | recruitment | 채용, 모집 | 2 | HR |
| vocab_371 | sustainable | 지속 가능한, 친환경적인 | 3 | General Business |
| vocab_372 | telecommute | 재택근무하다 | 3 | HR |
| vocab_373 | enclosure | 동봉물, 첨부물 | 3 | Communication |
| vocab_374 | scalable | 확장 가능한 | 3 | Technology |
| vocab_375 | upskill | 역량을 향상시키다 | 3 | HR |
| vocab_376 | cybersecurity | 사이버 보안 | 4 | IT |
| vocab_377 | monetize | 수익화하다 | 4 | Finance |
| vocab_378 | governance | 지배 구조, 경영 관리 | 4 | Corporate |
| vocab_379 | volatility | 변동성, 불안정성 | 4 | Finance |
| vocab_380 | synergy | 시너지, 상호 협력 효과 | 4 | Corporate |

### 3-2. 새로 추가된 문법 항목 (20개)

| grammarID | Title | difficultyLevel | Category | quizType |
|-----------|-------|-----------------|----------|----------|
| gram_341 | 품사 - 부사 자리 (형용사 수식) - highly | 1 | Word Form | form |
| gram_342 | 시제 - 현재완료 (since와 함께) | 1 | Tense | grammar |
| gram_343 | 품사 - 명사 자리 (소유격 뒤) - expansion | 1 | Word Form | form |
| gram_344 | 전치사 - within (~이내에, 기간 표현) | 1 | Preposition | grammar |
| gram_345 | 수일치 - 단수 취급 부정대명사 (each of + 복수명사) | 1 | Subject-Verb Agreement | grammar |
| gram_346 | 관사 - 정관사 the (유일한 직함 앞) | 2 | Article | grammar |
| gram_347 | 동명사 - 전치사 뒤 동명사 (without ~ing) | 2 | Gerund | form |
| gram_348 | 접속사 - 조건 접속사 (provided that = ~하는 조건으로) | 2 | Conjunction | grammar |
| gram_349 | 대명사 - 재귀대명사 강조 용법 (themselves) | 2 | Pronoun | grammar |
| gram_350 | 조동사 - must have p.p. (과거 사실에 대한 강한 추측) | 2 | Modal Verb | grammar |
| gram_351 | 병렬구조 - not only A but also B (동일 품사 병렬) | 3 | Parallel Structure | form |
| gram_352 | 가정법 과거완료 - if + had p.p., would have p.p. | 3 | Subjunctive | grammar |
| gram_353 | 동명사 vs. 부정사 - remember + to V vs. ~ing | 3 | Gerund/Infinitive | grammar |
| gram_354 | 관계절 - 소유격 관계대명사 whose | 3 | Relative Clause | grammar |
| gram_355 | 분사 - 현재분사 (능동의 명사 후치 수식) - leading | 3 | Participle | form |
| gram_356 | 도치 - No sooner had + S + p.p. + than | 4 | Inversion | grammar |
| gram_357 | 가정법 - It is imperative that + 동사원형 (당위 가정법) | 4 | Subjunctive | grammar |
| gram_358 | 연어 - come into effect (발효되다) | 4 | Collocation | meaning |
| gram_359 | 분사구문 - 완료 수동 분사구문 (Having been p.p.) | 4 | Participle Construction | form |
| gram_360 | 전치사구 - on the grounds that (~을 이유로) | 4 | Preposition | grammar |

### 3-3. Post-Audit (자가 감사) 결과

#### ① 기출 적합성 검토
- ✅ **어휘 20개 전체:** 2023~2024 TOEIC 빈출 비즈니스/일상 실용 영단어로만 구성. `contract`, `executive`, `vacancy`, `consumer`, `launch` 등 Level 1은 토익 입문자도 반드시 알아야 할 초빈출 단어. `governance`, `volatility`, `synergy` 등 Level 4는 토익 고득점자 대상 실용 비즈니스 어휘로 기출 범위 내 적합.
- ✅ **문법 20개 전체:** `since + 현재완료`, `each of + 단수동사`, `전치사 + 동명사`, `가정법 과거완료`, `당위 가정법`, `No sooner 도치`, `whose 관계대명사` 등 실전 토익 Part 5 최빈출 포인트 완벽 커버.

#### ② 복수 정답 원천 차단 검토
모든 문법 항목에 대해 오답지 3개의 단일 오답성을 검증:

| grammarID | 오답 검증 결과 |
|-----------|---------------|
| gram_341 | high(의미 다름), height(명사), highness(명사) — 모두 100% 오답 ✅ |
| gram_342 | increased(since와 불가), will increase(미래), are increasing(진행) ✅ |
| gram_343 | expand(동사), expanding(분사), expanded(분사) — 명사 자리 불가 ✅ |
| gram_344 | beyond(반대 의미), between(두 대상 사이), among(셋 이상 사이) ✅ |
| gram_345 | are/were/have been — 모두 복수 동사형 ✅ |
| gram_346 | a(부정관사), an(부정관사), one(수사) — 정관사 자리 불가 ✅ |
| gram_347 | to exceed(부정사), exceed(동사원형), exceeded(과거형) ✅ |
| gram_348 | in case of(전치사구+명사), regardless of(의미 다름), in spite of(양보) ✅ |
| gram_349 | them(목적격), they(주격), their(소유격) — 재귀 강조 불가 ✅ |
| gram_350 | must be delayed(현재), should be delayed(당위), could delay(능동) ✅ |
| gram_351 | improving(분사), improved(분사), to improve(부정사) — 병렬 파괴 ✅ |
| gram_352 | conducted(단순과거), have conducted(현재완료), were conducting(과거진행) ✅ |
| gram_353 | submitting(과거 기억), submitted(분사), submit(원형) ✅ |
| gram_354 | which(소유격 불가), that(소유격 불가), whom(목적격) ✅ |
| gram_355 | led(수동 의미 상충), to lead(미래/목적), has led(중복 동사) ✅ |
| gram_356 | 도치 없는 형태 3종 — 모두 No sooner 문두 도치 규칙 위반 ✅ |
| gram_357 | submits(-s 오류), submitted(과거), to submit(부정사) ✅ |
| gram_358 | put into(타동사), bring into(타동사), get into(비표준) ✅ |
| gram_359 | Being promoted(동시성), Promoting(능동), Promoted to become(비문) ✅ |
| gram_360 | on account of(명사/동명사 전용), due to the reason that(비문법), for the reason of(비표준) ✅ |

#### ③ 스키마 일치 검토
- ✅ 어휘 20개: 필수 11개 키 전 항목 완비
- ✅ 문법 20개: 필수 13개 키 전 항목 완비
- ✅ explanation·tip·incorrectExample 전 항목 1타 강사 수준 해설 작성 완료

#### ④ 중복 체크
- ✅ 기존 360개 어휘와 신규 20개 간 영단어 중복 없음
- ✅ 기존 340개 문법 title과 신규 20개 간 중복 없음

**반려/재생성 항목:** 없음 (전 항목 1차 자가 감사 통과)

---

## 4. Final Verification

### 4-1. 최종 파일 현황

| 파일 | 기존 항목 수 | 신규 추가 | 최종 항목 수 |
|------|------------|----------|------------|
| Vocabulary.json | 360 | +20 | **380** |
| Grammar.json | 340 | +20 | **360** |

### 4-2. ID 연속성 및 레벨 분포 검증

**Vocabulary.json:**
- ID 범위: vocab_001 ~ vocab_380 (연속, 누락/중복 없음) ✅
- frequencyLevel 분포: Level 1: 95개, Level 2: 95개, Level 3: 95개, Level 4: 95개 (균등) ✅

**Grammar.json:**
- ID 범위: gram_001 ~ gram_360 (연속, 누락/중복 없음) ✅
- difficultyLevel 분포: Level 1: 90개, Level 2: 90개, Level 3: 90개, Level 4: 90개 (균등) ✅

### 4-3. JSON 구조 무결성
- ✅ 두 파일 모두 순수한 JSON 배열 형식 (`[...]`) 유지
- ✅ Python `json.load()` 파싱 오류 없음
- ✅ `dataVersion: 1` 일관 적용
- ✅ `toeicPart: "Part 5"` 일관 적용 (Grammar.json)

---

*본 보고서는 Naelm 토익 학습 앱 데이터 무결성 관리 프로세스에 따라 자동 생성되었습니다.*
