import Foundation
import NaturalLanguage

struct TextValidationService {
    private let placeholderPatterns = [
        "lorem ipsum",
        "dolor sit amet",
        "sample text",
        "your text here",
        "insert content",
        "placeholder",
        "todo",
        "tbd"
    ]

    private let uiOnlyLabels: Set<String> = [
        "title", "title 1", "label", "button", "cell", "image", "text"
    ]

    func validate(_ text: String) -> TextValidationResult {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard !normalized.isEmpty else {
            return .empty
        }

        let lowercased = normalized.lowercased()

        if isNonLanguage(lowercased) {
            return .nonLanguage
        }

        if containsPlaceholderPattern(lowercased) || isRepeatedFiller(lowercased) || isUIOnlyText(lowercased) {
            return .dummyContent
        }

        // ID cards and official documents use short labelled lines, not prose — allow summarisation.
        if isOfficialDocumentContent(text) {
            return .valid
        }

        // Use raw text (preserve newlines) for structure-based checks; normalized text hides line fragments.
        if isSystemScreenOrNotificationContent(text) {
            return .meaninglessContent
        }

        if isMeaninglessContent(text) {
            return .meaninglessContent
        }

        return .valid
    }

    /// Government ID, passport, licence, and similar official documents (short structured OCR, not prose).
    private func isOfficialDocumentContent(_ text: String) -> Bool {
        let lower = text.lowercased()

        let documentPhrases = [
            "identity card", "identity", "identification", "id card", "national id",
            "passport", "driving licence", "driving license", "driver licence", "driver license",
            "driver's license", "learners permit", "learner permit",
            "date of birth", "dob", "place of birth", "expiry", "expires", "expiration",
            "valid until", "valid thru", "valid through", "issue date", "issued",
            "license number", "licence number", "document no", "document number",
            "card no", "card number", "id no", "id number", "identification number",
            "aadhaar", "aadhar", "pan card", "voter id", "voter identification",
            "social security", "immigration", "visa", "residence permit",
            "government of", "republic of", "ministry of", "department of",
            "citizen", "nationality", "sex:", "gender:", "signature", "photograph",
            "enrolment", "enrollment", "registration number", "permanent account",
            "emp id", "employee id", "employee number", "employee code", "phone number"
        ]

        if documentPhrases.contains(where: { lower.contains($0) }) {
            return true
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return false }

        let letterCount = text.filter(\.isLetter).count
        let digitCount = text.filter(\.isNumber).count

        let hasDatePattern = text.range(
            of: #"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}"#,
            options: .regularExpression
        ) != nil

        let hasLabelValueLine = lines.contains { line in
            line.range(
                of: #"(?i)^[a-z][a-z\s]{1,24}\s*[:#]\s*\S+"#,
                options: .regularExpression
            ) != nil
        }

        let hasAlphanumericID = text.range(
            of: #"(?i)(?:id|no|number)\s*[:#]?\s*[a-z0-9\-]{4,}"#,
            options: .regularExpression
        ) != nil

        if hasDatePattern && letterCount >= 8 && digitCount >= 2 {
            return true
        }

        if hasLabelValueLine && lines.count >= 3 && letterCount >= 10 {
            return true
        }

        if hasAlphanumericID && lines.count >= 2 && letterCount >= 6 {
            return true
        }

        return false
    }

    /// Lock screen, notification shade, and status-bar OCR (e.g. Wi‑Fi, time, "Notification Centre").
    private func isSystemScreenOrNotificationContent(_ text: String) -> Bool {
        let lower = text.lowercased()
        let systemPhrases = [
            "notification centre",
            "notification center",
            "notification shade",
            "control centre",
            "control center",
            "lock screen",
            "status bar",
            "do not disturb",
            "focus mode",
            "battery",
            "cellular",
            "wi-fi",
            "wifi"
        ]

        if systemPhrases.contains(where: { lower.contains($0) }) {
            return true
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 3 else { return false }

        let shortLineCount = lines.filter { tokenCount(in: $0) <= 2 }.count
        let mostlyFragments = Double(shortLineCount) / Double(lines.count) > 0.6

        let timeOnlyLines = lines.filter { line in
            line.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil
        }.count

        let dateLikeLines = lines.filter { line in
            line.range(of: #"(?i)^(mon|tue|wed|thu|fri|sat|sun)\b"#, options: .regularExpression) != nil
                && tokenCount(in: line) <= 4
        }.count

        return mostlyFragments && (timeOnlyLines > 0 || dateLikeLines > 0 || lower.contains("notification"))
    }

    private func containsPlaceholderPattern(_ text: String) -> Bool {
        placeholderPatterns.contains { text.contains($0) } || text == "n/a"
    }

    private func isRepeatedFiller(_ text: String) -> Bool {
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard words.count >= 3 else { return false }

        let grouped = Dictionary(grouping: words, by: { $0 })
        if grouped.values.contains(where: { $0.count >= 3 }) {
            return true
        }

        return Set(words).count <= 2 && words.count >= 4
    }

    private func isUIOnlyText(_ text: String) -> Bool {
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return false }
        return words.allSatisfy { word in
            uiOnlyLabels.contains(word) || Int(word) != nil
        }
    }

    private func isNonLanguage(_ text: String) -> Bool {
        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty else { return true }

        let alphanumeric = text.filter { $0.isLetter || $0.isNumber }
        guard !alphanumeric.isEmpty else { return true }

        let letterRatio = Double(letters.count) / Double(alphanumeric.count)
        return letterRatio < 0.25
    }

    private func isMeaninglessContent(_ text: String) -> Bool {
        let tokenStats = linguisticTokenStats(for: text)
        guard tokenStats.totalTokens > 0 else { return true }

        let meaningfulRatio = Double(tokenStats.meaningfulTokens) / Double(tokenStats.totalTokens)
        let nonWordRatio = Double(tokenStats.numericOrSymbolicTokens) / Double(tokenStats.totalTokens)

        if tokenStats.meaningfulTokens < 5 {
            return true
        }

        if meaningfulRatio < 0.4 {
            return true
        }

        if nonWordRatio > 0.6 {
            return true
        }

        if mostlyShortFragmentLines(text) && !containsSentenceLikePhrase(text) {
            return true
        }

        return false
    }

    private func linguisticTokenStats(for text: String) -> (totalTokens: Int, meaningfulTokens: Int, numericOrSymbolicTokens: Int) {
        var totalTokens = 0
        var meaningfulTokens = 0
        var numericOrSymbolicTokens = 0

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace]
        ) { tag, range in
            let token = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { return true }

            totalTokens += 1

            if token.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isSymbol }) {
                numericOrSymbolicTokens += 1
                return true
            }

            if let tag, [.noun, .verb, .adjective, .adverb].contains(tag) {
                meaningfulTokens += 1
            }

            return true
        }

        return (totalTokens, meaningfulTokens, numericOrSymbolicTokens)
    }

    private func mostlyShortFragmentLines(_ text: String) -> Bool {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return true }

        let shortLines = lines.filter { line in
            tokenCount(in: line) <= 2
        }

        return Double(shortLines.count) / Double(lines.count) > 0.6
    }

    private func containsSentenceLikePhrase(_ text: String) -> Bool {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var hasPhrase = false

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            if tokenCount(in: sentence) >= 5 && sentence.contains(where: { ".!?".contains($0) }) {
                hasPhrase = true
                return false
            }
            return true
        }

        return hasPhrase
    }

    private func tokenCount(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }
}
