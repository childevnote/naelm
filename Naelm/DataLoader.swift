//
//  DataLoader.swift
//  Naelm
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
import os

// MARK: - JSON 디코딩용 DTO (Data Transfer Object)

private struct VocabularyMeaningDTO: Decodable {
    let meaningID: String
    let pos: String?
    let korean: String?
    let exampleSentence: String?
    let exampleTranslation: String?
    let synonyms: String?
    let order: Int?
}

private struct VocabularyDTO: Decodable {
    let wordID: String
    let english: String
    let pronunciation: String?
    let frequencyLevel: Int?
    let category: String?
    let dataVersion: Int?

    // ── 단일 의미 단어용 플랫 필드 ──
    let korean: String?
    let partOfSpeech: String?
    let exampleSentence: String?
    let exampleTranslation: String?
    let synonyms: String?

    // ── 다중 의미 단어용 계층 필드 ──
    let meanings: [VocabularyMeaningDTO]?
}

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
    let blankTarget: String?
    let distractors: String?
    let quizType: String?
    let dataVersion: Int?
}

// MARK: - DataLoader

@MainActor
final class DataLoader {

    // MARK: - Public API

    static func seedAllIfNeeded(context: ModelContext) {
        seedVocabularyIfNeeded(context: context)
        seedGrammarIfNeeded(context: context)
        try? context.save()
    }

    // MARK: - Vocabulary 시딩

    static func seedVocabularyIfNeeded(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Vocabulary", withExtension: "json") else {
            AppLogger.data.warning("Vocabulary.json not found in bundle")
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            AppLogger.data.error("Failed to read Vocabulary.json: \(error)")
            return
        }

        let dtos: [VocabularyDTO]
        do {
            dtos = try JSONDecoder().decode([VocabularyDTO].self, from: data)
        } catch {
            AppLogger.data.error("Failed to decode Vocabulary.json: \(error)")
            return
        }

        let existingIDs = fetchExistingVocabularyIDs(context: context)

        var insertedCount = 0
        for dto in dtos {
            guard !existingIDs.contains(dto.wordID) else { continue }

            let vocab = Vocabulary(
                wordID: dto.wordID,
                english: dto.english,
                // 다중 의미 단어는 meanings 배열 내부에 korean이 있으므로 플랫 필드는 빈 문자열이 됨
                korean: dto.korean ?? "",
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

            // 다중 의미 삽입
            if let meaningDTOs = dto.meanings {
                for mDTO in meaningDTOs {
                    let meaning = VocabularyMeaning(
                        meaningID: mDTO.meaningID,
                        pos: mDTO.pos ?? "",
                        korean: mDTO.korean ?? "",
                        exampleSentence: mDTO.exampleSentence ?? "",
                        exampleTranslation: mDTO.exampleTranslation ?? "",
                        synonyms: mDTO.synonyms ?? "",
                        order: mDTO.order ?? 1
                    )
                    meaning.vocabulary = vocab
                    context.insert(meaning)
                }
            }

            insertedCount += 1
        }

        if insertedCount > 0 {
            AppLogger.data.info("Inserted \(insertedCount) new vocabulary items")
        } else {
            AppLogger.data.debug("Vocabulary data already up to date")
        }
    }

    // MARK: - Grammar 시딩

    static func seedGrammarIfNeeded(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Grammar", withExtension: "json") else {
            AppLogger.data.warning("Grammar.json not found in bundle")
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            AppLogger.data.error("Failed to read Grammar.json: \(error)")
            return
        }

        let dtos: [GrammarDTO]
        do {
            dtos = try JSONDecoder().decode([GrammarDTO].self, from: data)
        } catch {
            AppLogger.data.error("Failed to decode Grammar.json: \(error)")
            return
        }

        let existingIDs = fetchExistingGrammarIDs(context: context)

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
                blankTarget: dto.blankTarget ?? "",
                distractors: dto.distractors ?? "",
                quizType: dto.quizType ?? "grammar",
                dataVersion: dto.dataVersion ?? 1
            )
            context.insert(grammar)
            insertedCount += 1
        }

        if insertedCount > 0 {
            AppLogger.data.info("Inserted \(insertedCount) new grammar items")
        } else {
            AppLogger.data.debug("Grammar data already up to date")
        }
    }

    // MARK: - Private Helpers

    private static func fetchExistingVocabularyIDs(context: ModelContext) -> Set<String> {
        var descriptor = FetchDescriptor<Vocabulary>()
        descriptor.propertiesToFetch = [\Vocabulary.wordID]
        do {
            let existing = try context.fetch(descriptor)
            return Set(existing.map(\.wordID))
        } catch {
            AppLogger.data.warning("Failed to fetch existing vocabulary: \(error)")
            return []
        }
    }

    private static func fetchExistingGrammarIDs(context: ModelContext) -> Set<String> {
        var descriptor = FetchDescriptor<Grammar>()
        descriptor.propertiesToFetch = [\Grammar.grammarID]
        do {
            let existing = try context.fetch(descriptor)
            return Set(existing.map(\.grammarID))
        } catch {
            AppLogger.data.warning("Failed to fetch existing grammar: \(error)")
            return []
        }
    }
}
