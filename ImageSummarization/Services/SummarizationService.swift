import CoreML
import Foundation
import NaturalLanguage

#if canImport(FoundationModels)
import FoundationModels
#endif

enum SummarizationError: LocalizedError {
    case modelUnavailable
    case inferenceFailed(String)
    case emptyInput
    case notSummarisable(String)  // ← add this

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return NSLocalizedString(
                "Abstractive summarisation is not available on this device. Use iOS 26 or later with Apple Intelligence, or replace DistilBARTSummariser with a Core ML model that accepts plain text input.",
                comment: ""
            )
        case .inferenceFailed(let reason):
            return String(format: NSLocalizedString("Summarization failed: %@", comment: ""), reason)
        case .emptyInput:
            return NSLocalizedString("No text provided for summarization.", comment: "")
        case .notSummarisable(let reason):
            return reason  // ← passes the model's own reason directly to UI
        }
    }
}

actor SummarizationService {

    private let textSummaryPromptTemplate = """
    You are a plain-English summarisation assistant.

    Before summarising, first evaluate whether the following extracted text contains \
    real, meaningful, human-readable content that is worth summarising.

    Text:
    %@

    Step 1 — Gate check. Treat the text as NOT meaningful if it consists mostly of:
    - App or software metadata (version numbers, build numbers, device IDs, copyright notices)
    - UI navigation labels (menu items, button names, tab titles, screen headings)
    - System or OS level text (lock screen elements, status bar info, notification previews)
    - Timestamps, dates, times, or status indicators without context
    - Single isolated words, random alphanumeric strings, or garbled OCR output
    - Any combination of the above with no coherent readable message or intent

    However, always treat the following as meaningful regardless of format:
    - Identity documents, government IDs, driving licences, or official certificates
    - Medical records, prescriptions, or health documents
    - Receipts, invoices, or financial documents
    - Any document that identifies a person, organisation, or official record
    
    If the text fails the gate check, respond with:
    { "summarisable": false, "reason": "<one sentence explaining why the text has no meaningful content>" }

    Step 2 — If and only if the text passes the gate check, write a simple plain-English \
    recap as a natural flowing paragraph of 3 to 5 sentences. Use everyday language anyone \
    can understand. Cover only what is actually written in the text. Do not add information \
    that is not present. Do not use bullet points or lists.

    Respond with:
    { "summarisable": true, "summary": "<your plain-English paragraph here>" }

    Always respond in valid JSON only. No preamble, no explanation, no markdown, no code blocks.
    """
    
    private let objectDescriptionPromptTemplate = """
    You are a factual knowledge assistant.

    A MobileNetV2 image classifier has produced the following result:
    Detected label: %@
    Confidence: %@

    Step 1 — Evaluate the label. Determine what category this label belongs to:
    - A living thing (animal, bird, insect, plant, tree, flower)
    - A food or drink item
    - A man-made object or vehicle
    - A place, structure, or landmark
    - An abstract or unclear label

    Step 2 — Based on what you determine, write a short precise factual description of \
    2 to 3 sentences in plain English that naturally covers:
    - What it is
    - What it looks like or what it does
    - One notable or interesting fact about it

    Rules:
    - Write as a clear flowing factual statement — no bullet points, no lists.
    - Do not reference the image, the classifier, or the confidence score in the summary.
    - Do not hardcode or assume a fixed structure — let the subject guide what is most relevant.
    - Only include facts that genuinely apply to this subject.
    - If confidence is below 0.5, begin with "This may be a [label]." before the description.

    Respond with exactly:
    { "summarisable": true, "summary": "<your 2 to 3 sentence factual description here>" }

    Always respond in valid JSON only. No preamble, no explanation, no markdown, no code blocks.
    """
    
    func summarize(_ text: String, imageLabel: String? = nil, confidence: Float? = nil) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = imageLabel?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty || !(trimmedLabel?.isEmpty ?? true) else {
            throw SummarizationError.emptyInput
        }

        let prompt = buildPrompt(text: trimmed, imageLabel: trimmedLabel, confidence: confidence)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await summarizeWithFoundationModels(prompt: prompt, fallbackText: trimmed, imageLabel: trimmedLabel, confidence: confidence)
        }
        #endif

        return try await summarizeWithCoreMLOrExtractiveFallback(trimmed, imageLabel: imageLabel, confidence: confidence)
    }

    // MARK: - Primary: Apple Foundation Models (iOS 26+)

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func summarizeWithFoundationModels(
        prompt: String,
        fallbackText: String,
        imageLabel: String?,
        confidence: Float?
    ) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return try await summarizeWithCoreMLOrExtractiveFallback(fallbackText, imageLabel: imageLabel, confidence: confidence)
        }

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return try parseFoundationModelResponse(response.content)
        } catch let error as SummarizationError {
            throw error
        } catch {
            throw SummarizationError.inferenceFailed(error.localizedDescription)
        }
    }
    #endif

    // MARK: - Fallback: Core ML when bundled and compatible, else extractive (model unavailable only)

    private func summarizeWithCoreMLOrExtractiveFallback(_ text: String, imageLabel: String?, confidence: Float?) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = imageLabel?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Object description: classification already succeeded; DistilBART cannot run without text.
        if let trimmedLabel, !trimmedLabel.isEmpty, trimmedText.isEmpty {
            return fallbackObjectDescription(label: trimmedLabel, confidence: confidence)
        }

        switch resolveBundledSummarizationModel() {
        case .stringModel(let compiledModel):
            return try await summarizeWithCoreMLModel(compiledModel, text: trimmedText)
        case .incompatibleBundledModel(let reason):
            // DistilBART expects token tensors (input_ids, attention_mask), not plain text — not usable as-is.
            print("Summarization Core ML: \(reason)")
            throw SummarizationError.modelUnavailable
        case .notBundled:
            guard !trimmedText.isEmpty else {
                throw SummarizationError.modelUnavailable
            }
            return intelligentExtractiveSummary(of: trimmedText)
        }
    }

    private enum BundledSummarizationModelResolution {
        case stringModel(MLModel)
        case incompatibleBundledModel(String)
        case notBundled
    }

    private func resolveBundledSummarizationModel() -> BundledSummarizationModelResolution {
        let modelURL = Bundle.main.url(forResource: "DistilBARTSummariser", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "DistilBARTSummariser", withExtension: "mlpackage")

        guard let modelURL else {
            print("Summarization: DistilBARTSummariser not found in app bundle (expected compiled .mlmodelc from .mlpackage).")
            return .notBundled
        }

        do {
            let compiledModel = try MLModel(contentsOf: modelURL)
            let inputKeys = compiledModel.modelDescription.inputDescriptionsByName.keys.sorted()
            let outputKeys = compiledModel.modelDescription.outputDescriptionsByName.keys.sorted()
            print("Summarization Core ML inputs: \(inputKeys), outputs: \(outputKeys)")

            if supportsStringInputOutput(compiledModel) {
                return .stringModel(compiledModel)
            }

            let reason = """
            DistilBARTSummariser is bundled but does not expose string in/out features. \
            This model expects token tensors (e.g. input_ids, attention_mask) and produces logits, \
            not a plain-text summary. Add a string-based summarisation Core ML model or use Foundation Models on iOS 26+.
            """
            return .incompatibleBundledModel(reason)
        } catch {
            return .incompatibleBundledModel("Failed to load DistilBARTSummariser: \(error.localizedDescription)")
        }
    }

    private func supportsStringInputOutput(_ model: MLModel) -> Bool {
        let inputs = model.modelDescription.inputDescriptionsByName
        let outputs = model.modelDescription.outputDescriptionsByName
        let hasStringInput = inputs.values.contains { $0.type == .string }
        let hasStringOutput = outputs.values.contains { $0.type == .string }
        return hasStringInput && hasStringOutput
    }

    private func summarizeWithCoreMLModel(_ compiledModel: MLModel, text: String) async throws -> String {
        guard let provider = makeStringInputProvider(for: compiledModel, text: text) else {
            let keys = compiledModel.modelDescription.inputDescriptionsByName.keys.sorted()
            throw SummarizationError.inferenceFailed(
                "No compatible string input feature found. Available inputs: \(keys.joined(separator: ", "))."
            )
        }

        do {
            let output = try await compiledModel.prediction(from: provider)
            guard let summary = firstStringOutput(from: output, model: compiledModel)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !summary.isEmpty else {
                let outputKeys = compiledModel.modelDescription.outputDescriptionsByName.keys.sorted()
                throw SummarizationError.inferenceFailed(
                    "Core ML summarisation returned no text. Available outputs: \(outputKeys.joined(separator: ", "))."
                )
            }
            return summary
        } catch let error as SummarizationError {
            throw error
        } catch {
            throw SummarizationError.inferenceFailed(error.localizedDescription)
        }
    }

    // MARK: - NaturalLanguage-based extractive summarization

    /// Scores each sentence by the frequency of its non-trivial words, then
    /// returns the top-scoring sentences (re-ordered by original position) as
    /// the summary. This produces a genuinely condensed result even when no
    /// ML model is bundled.
    private func intelligentExtractiveSummary(of text: String) -> String {
        let language = detectedLanguage(for: text)
        let sentences = tokenizeSentences(from: text, language: language)
        guard sentences.count > 1 else { return text }

        let wordFreq = wordFrequency(in: text, language: language)

        let scored: [(index: Int, sentence: String, score: Double)] = sentences
            .enumerated()
            .map { index, sentence in
                let words = significantWords(in: sentence, language: language)
                let score = words.reduce(0.0) { $0 + Double(wordFreq[$1] ?? 0) }
                let normalizedScore = words.isEmpty ? 0 : score / Double(words.count)
                return (index, sentence, normalizedScore)
            }

        let keepCount = min(sentences.count, max(2, Int(ceil(Double(sentences.count) * 0.3))))

        let summary = scored
            .sorted { $0.score > $1.score }
            .prefix(keepCount)
            .sorted { $0.index < $1.index }
            .map { $0.sentence }
            .joined(separator: " ")

        return summary
    }

    private func tokenizeSentences(from text: String, language: NLLanguage?) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        if let language {
            tokenizer.setLanguage(language)
        }
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences.isEmpty
            ? text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                  .filter { !$0.isEmpty }
            : sentences
    }

    private func significantWords(in text: String, language: NLLanguage?) -> [String] {
        var words: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        if let language {
            tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        }
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            let word = text[range].lowercased()
            // Keep nouns, verbs, adjectives, adverbs — skip stop-word classes
            if let tag, [.noun, .verb, .adjective, .adverb, .otherWord].contains(tag), word.count > 2 {
                words.append(word)
            }
            return true
        }
        return words
    }

    private func wordFrequency(in text: String, language: NLLanguage?) -> [String: Int] {
        var freq: [String: Int] = [:]
        significantWords(in: text, language: language).forEach { freq[$0, default: 0] += 1 }
        return freq
    }

    private func detectedLanguage(for text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage,
              let confidence = recognizer.languageHypotheses(withMaximum: 1)[language],
              confidence > 0.5 else {
            return nil
        }
        return language
    }

    private func makeStringInputProvider(for model: MLModel, text: String) -> MLFeatureProvider? {
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        let availableKeys = inputDescriptions.keys.sorted()
        print("CoreML summarization input keys: \(availableKeys)")

        let preferredKeys = ["text", "input_text", "input", "document", "source"]
        let stringInputName = preferredKeys.first { key in
            inputDescriptions[key]?.type == .string
        } ?? inputDescriptions.first { _, description in
            description.type == .string
        }?.key

        guard let stringInputName else {
            return nil
        }

        return try? MLDictionaryFeatureProvider(dictionary: [
            stringInputName: MLFeatureValue(string: preprocessedText(text))
        ])
    }

    private func firstStringOutput(from output: MLFeatureProvider, model: MLModel) -> String? {
        for name in model.modelDescription.outputDescriptionsByName.keys {
            if let value = output.featureValue(for: name)?.stringValue {
                return value
            }
        }
        return nil
    }

    private func preprocessedText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildPrompt(text: String, imageLabel: String?, confidence: Float?) -> String {
        if let imageLabel, text.isEmpty {
            let confidenceText = confidence
                .map { String(format: "%.0f%%", $0 * 100) } ?? "Unavailable"
            return String(format: objectDescriptionPromptTemplate, imageLabel, confidenceText)
        }

        return String(format: textSummaryPromptTemplate, text)
    }

    /// Used when Foundation Models are unavailable and only a MobileNetV2 label exists (no OCR text).
    private func fallbackObjectDescription(label: String, confidence: Float?) -> String {
        let confidenceSentence = confidence
            .map { String(format: NSLocalizedString(" The classification confidence is %.0f%%.", comment: ""), $0 * 100) } ?? ""
        return String(
            format: NSLocalizedString(
                "The image was classified as %@ using MobileNetV2.%@ A full AI-generated description is not available on this device without Apple Intelligence.",
                comment: ""
            ),
            label,
            confidenceSentence
        )
    }

    private func parseFoundationModelResponse(_ response: String) throws -> String {
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw SummarizationError.inferenceFailed("Unable to decode Foundation Models response.")
        }

        let parsed = try JSONDecoder().decode(FoundationSummaryResponse.self, from: data)

        if parsed.summarisable, let summary = parsed.summary, !summary.isEmpty {
            return summary
        }

        // ← throws notSummarisable instead of inferenceFailed
        throw SummarizationError.notSummarisable(
            parsed.reason ?? "The extracted text does not contain enough meaningful content to summarise."
        )
    }
}

private struct FoundationSummaryResponse: Decodable {
    let summarisable: Bool
    let summary: String?
    let reason: String?
}
