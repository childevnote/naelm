//
//  DataLoader.swift
//  Toeigo
//
//  Created by 김동진 on 4/3/26.
//
//  번들 JSON에서 정적 학습 데이터를 SwiftData에 시딩하는 유틸리티.
//  ──────────────────────────────────────────────
//  설계 원칙:
//    1. 멱등성(Idempotent) — 앱을 여러 번 실행해도 중복 삽입 없음
//    2. @MainActor — SwiftData ModelContext는 메인 액터에서 접근
//    3. dataVersion 필드로 향후 시드 데이터 업데이트 지원
//  ──────────────────────────────────────────────

import Foundation
import SwiftData

// MARK: - JSON 디코딩용 DTO (Data Transfer Object)

/// Vocabulary.json의 각 항목을 디코딩하기 위한 경량 구조체.
/// SwiftData 모델에 직접 Codable을 적용하면 CloudKit 동기화에
/// 부작용이 생길 수 있으므로, DTO를 거쳐 변환합니다.
private struct VocabularyDTO: Decodable {
    let wordID: String
    let english: String
    let korean: String
    let pronunciation: String?
    let partOfSpeech: String?
    let frequencyLevel: Int?
    let exampleSentence: String?
    let exampleTranslation: String?
    let category: String?
    let synonyms: String?
    let dataVersion: Int?
}

/// Grammar.json의 각 항목을 디코딩하기 위한 경량 구조체.
private struct GrammarDTO: Decodable {
    let grammarID: String
    let title: String
    let explanation: String
    let toeicPart: String?
    let difficultyLevel: Int?
    let correctExample: String?
    let incorrectExample: String?
    let tip: String?
    let category: String?
    let dataVersion: Int?
}

// MARK: - DataLoader

/// 앱 최초 실행(또는 데이터 업데이트) 시 번들 JSON을
/// SwiftData ModelContext에 시딩하는 유틸리티 클래스.
@MainActor
final class DataLoader {

    // MARK: - Public API

    /// 어휘 + 문법 데이터를 한 번에 시딩합니다.
    /// - Parameter context: SwiftData ModelContext (Environment에서 주입)
    static func seedAllIfNeeded(context: ModelContext) {
        seedVocabularyIfNeeded(context: context)
        seedGrammarIfNeeded(context: context)
        // 명시적 저장 — 시딩 직후 다른 뷰에서 fetch할 때 데이터가 보이도록
        try? context.save()
    }

    // MARK: - Vocabulary 시딩

    /// Vocabulary.json을 읽어 SwiftData에 삽입합니다.
    /// 이미 동일한 wordID가 존재하면 건너뜁니다.
    static func seedVocabularyIfNeeded(context: ModelContext) {
        // 1) 번들에서 JSON 파일 로드
        guard let url = Bundle.main.url(forResource: "Vocabulary", withExtension: "json") else {
            print("⚠️ [DataLoader] Vocabulary.json not found in bundle.")
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("❌ [DataLoader] Failed to read Vocabulary.json: \(error)")
            return
        }

        // 2) JSON → DTO 배열로 디코딩
        let dtos: [VocabularyDTO]
        do {
            dtos = try JSONDecoder().decode([VocabularyDTO].self, from: data)
        } catch {
            print("❌ [DataLoader] Failed to decode Vocabulary.json: \(error)")
            return
        }

        // 3) 기존 데이터의 wordID 집합 조회 (중복 방지)
        let existingIDs = fetchExistingVocabularyIDs(context: context)

        // 4) 새 항목만 삽입
        var insertedCount = 0
        for dto in dtos {
            guard !existingIDs.contains(dto.wordID) else { continue }

            let vocab = Vocabulary(
                wordID: dto.wordID,
                english: dto.english,
                korean: dto.korean,
                pronunciation: dto.pronunciation ?? "",
                partOfSpeech: dto.partOfSpeech ?? "",
                frequencyLevel: dto.frequencyLevel ?? 1,
                exampleSentence: dto.exampleSentence ?? "",
                exampleTranslation: dto.exampleTranslation ?? "",
                category: dto.category ?? "",
                synonyms: dto.synonyms ?? "",
                dataVersion: dto.dataVersion ?? 1
            )
            context.insert(vocab)
            insertedCount += 1
        }

        if insertedCount > 0 {
            print("✅ [DataLoader] Inserted \(insertedCount) new vocabulary items.")
        } else {
            print("ℹ️ [DataLoader] Vocabulary data already up to date.")
        }
    }

    // MARK: - Grammar 시딩

    /// Grammar.json을 읽어 SwiftData에 삽입합니다.
    /// 이미 동일한 grammarID가 존재하면 건너뜁니다.
    static func seedGrammarIfNeeded(context: ModelContext) {
        // 1) 번들에서 JSON 파일 로드
        guard let url = Bundle.main.url(forResource: "Grammar", withExtension: "json") else {
            print("⚠️ [DataLoader] Grammar.json not found in bundle.")
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("❌ [DataLoader] Failed to read Grammar.json: \(error)")
            return
        }

        // 2) JSON → DTO 배열로 디코딩
        let dtos: [GrammarDTO]
        do {
            dtos = try JSONDecoder().decode([GrammarDTO].self, from: data)
        } catch {
            print("❌ [DataLoader] Failed to decode Grammar.json: \(error)")
            return
        }

        // 3) 기존 데이터의 grammarID 집합 조회 (중복 방지)
        let existingIDs = fetchExistingGrammarIDs(context: context)

        // 4) 새 항목만 삽입
        var insertedCount = 0
        for dto in dtos {
            guard !existingIDs.contains(dto.grammarID) else { continue }

            let grammar = Grammar(
                grammarID: dto.grammarID,
                title: dto.title,
                explanation: dto.explanation,
                toeicPart: dto.toeicPart ?? "",
                difficultyLevel: dto.difficultyLevel ?? 1,
                correctExample: dto.correctExample ?? "",
                incorrectExample: dto.incorrectExample ?? "",
                tip: dto.tip ?? "",
                category: dto.category ?? "",
                dataVersion: dto.dataVersion ?? 1
            )
            context.insert(grammar)
            insertedCount += 1
        }

        if insertedCount > 0 {
            print("✅ [DataLoader] Inserted \(insertedCount) new grammar items.")
        } else {
            print("ℹ️ [DataLoader] Grammar data already up to date.")
        }
    }

    // MARK: - Private Helpers

    /// 이미 저장된 Vocabulary의 wordID 집합을 반환합니다.
    private static func fetchExistingVocabularyIDs(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Vocabulary>()
        do {
            let existing = try context.fetch(descriptor)
            return Set(existing.map(\.wordID))
        } catch {
            print("⚠️ [DataLoader] Failed to fetch existing vocabulary: \(error)")
            return []
        }
    }

    /// 이미 저장된 Grammar의 grammarID 집합을 반환합니다.
    private static func fetchExistingGrammarIDs(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Grammar>()
        do {
            let existing = try context.fetch(descriptor)
            return Set(existing.map(\.grammarID))
        } catch {
            print("⚠️ [DataLoader] Failed to fetch existing grammar: \(error)")
            return []
        }
    }
}
