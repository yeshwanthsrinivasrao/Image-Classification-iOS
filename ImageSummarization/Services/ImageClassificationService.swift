import CoreML
import UIKit
import Vision

enum ImageClassificationError: LocalizedError {
    case invalidImage
    case modelUnavailable
    case classificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("The selected image could not be classified.", comment: "")
        case .modelUnavailable:
            return NSLocalizedString("MobileNetV2 model is unavailable. Please verify the model is included in the app target.", comment: "")
        case .classificationFailed(let reason):
            return String(format: NSLocalizedString("Image classification failed: %@", comment: ""), reason)
        }
    }
}

actor ImageClassificationService {
    func classify(_ image: UIImage) async throws -> ClassificationResult {
        guard let cgImage = image.cgImage else {
            throw ImageClassificationError.invalidImage
        }

        guard let modelURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc") else {
            throw ImageClassificationError.modelUnavailable
        }

        let mlModel = try MLModel(contentsOf: modelURL)
        let visionModel = try VNCoreMLModel(for: mlModel)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error {
                    continuation.resume(throwing: ImageClassificationError.classificationFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(throwing: ImageClassificationError.classificationFailed("No classification result was returned."))
                    return
                }

                guard let topResult = observations
                    .filter({ $0.confidence > 0.25 })
                    .first else {
                    continuation.resume(throwing: ImageClassificationError.classificationFailed("No classification result was returned."))
                    return
                }

                let primaryRaw = Self.primaryIdentifierSegment(from: topResult.identifier)
                let cleanedLabel = Self.formatLabel(primaryRaw)

                // Animals are checked before food so labels like "cabbage butterfly" are not
                // misclassified as food via substring matches (e.g. "cabbage").
                let contentType: ImageContentType
                let normalizedQuery: String?
                if AnimalLabelMapper.isAnimal(label: cleanedLabel) {
                    contentType = .animal
                    normalizedQuery = nil
                } else if let foodQuery = FoodLabelMapper.normalizedFoodQuery(for: cleanedLabel) {
                    contentType = .food
                    normalizedQuery = foodQuery
                } else {
                    contentType = .other
                    normalizedQuery = nil
                }

                let displayTitle = Self.displayTitle(
                    cleanedLabel: cleanedLabel,
                    contentType: contentType
                )

                continuation.resume(returning: ClassificationResult(
                    displayTitle: displayTitle,
                    topLabel: cleanedLabel,
                    confidence: topResult.confidence,
                    normalizedFoodQuery: normalizedQuery,
                    contentType: contentType
                ))
            }

            request.imageCropAndScaleOption = .centerCrop

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ImageClassificationError.classificationFailed(error.localizedDescription))
            }
        }

        // VNClassifyImageRequest path superseded by VNCoreMLRequest + MobileNetV2.
        // return try await withCheckedThrowingContinuation { continuation in
        //     let request = VNClassifyImageRequest { request, error in
        //         if let error {
        //             continuation.resume(throwing: ImageClassificationError.classificationFailed(error.localizedDescription))
        //             return
        //         }
        //
        //         guard let observations = request.results as? [VNClassificationObservation],
        //               let topResult = observations.first else {
        //             continuation.resume(throwing: ImageClassificationError.classificationFailed("No classification result was returned."))
        //             return
        //         }
        //
        //         let normalizedQuery = FoodLabelMapper.normalizedFoodQuery(for: topResult.identifier)
        //         let contentType: ImageContentType
        //         if normalizedQuery != nil {
        //             contentType = .food
        //         } else if AnimalLabelMapper.isAnimal(label: topResult.identifier) {
        //             contentType = .animal
        //         } else {
        //             contentType = .other
        //         }
        //         print(topResult.identifier)
        //         print(contentType)
        //         continuation.resume(returning: ClassificationResult(
        //             topLabel: topResult.identifier,
        //             confidence: topResult.confidence,
        //             normalizedFoodQuery: normalizedQuery,
        //             contentType: contentType
        //         ))
        //     }
        //
        //     // VNClassifyImageRequest uses Vision's built-in image handling and
        //     // does not expose VNCoreMLRequest.imageCropAndScaleOption.
        //     // request.imageCropAndScaleOption = .centerCrop
        //
        //     do {
        //         let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        //         try handler.perform([request])
        //     } catch {
        //         continuation.resume(throwing: ImageClassificationError.classificationFailed(error.localizedDescription))
        //     }
        // }
    }

    /// MobileNet/Vision identifiers may include synonyms after commas (e.g. "jackfruit,jak,jack").
    private static func primaryIdentifierSegment(from identifier: String) -> String {
        let segment = identifier
            .components(separatedBy: CharacterSet(charactersIn: ",;/"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return segment?.isEmpty == false ? segment! : identifier
    }

    private static func formatLabel(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private static func displayTitle(cleanedLabel: String, contentType: ImageContentType) -> String {
        switch contentType {
        case .animal:
            return AnimalLabelMapper.displayTitle(for: cleanedLabel) ?? cleanedLabel
        case .food:
            return cleanedLabel
        default:
            return cleanedLabel
        }
    }
}

enum FoodLabelMapper {
    private static let explicitMappings: [String: String] = [
        "granny smith": "apple",
        "carbonara": "pasta carbonara",
        "spaghetti squash": "squash",
        "bagel": "bagel",
        "pretzel": "pretzel",
        "cheeseburger": "cheeseburger",
        "hotdog": "hot dog",
        "pizza": "pizza",
        "burrito": "burrito",
        "ice cream": "ice cream",
        "banana": "banana",
        "lemon": "lemon",
        "orange": "orange",
        "pineapple": "pineapple",
        "strawberry": "strawberry",
        "custard apple": "custard apple",
        "fig": "fig",
        "pomegranate": "pomegranate",
        "bell pepper": "bell pepper",
        "cucumber": "cucumber",
        "artichoke": "artichoke",
        "mushroom": "mushroom",
        "jackfruit": "jackfruit",
        "broccoli": "broccoli",
        "cauliflower": "cauliflower",
        "zucchini": "zucchini"
    ]

    private static let foodKeywords: Set<String> = [
        "apple", "banana", "orange", "lemon", "pineapple", "strawberry", "fig",
        "pomegranate", "pepper", "cucumber", "artichoke", "mushroom", "pizza",
        "burger", "cheeseburger", "hotdog", "hot dog", "bagel", "pretzel",
        "burrito", "carbonara", "pasta", "ice cream", "squash", "custard",
        "jackfruit", "broccoli", "cauliflower", "zucchini", "carrot", "tomato",
        "potato", "cabbage", "lettuce", "corn", "bean", "bread", "cake", "pie",
        "salad", "soup", "steak", "meat", "rice", "noodle",
        "salmon", "tuna", "shrimp", "crab", "lobster"
    ]

    static func normalizedFoodQuery(for label: String) -> String? {
        let candidate = label
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        if let mapped = explicitMappings[candidate] {
            return mapped
        }

        if foodKeywords.contains(candidate) {
            return candidate
        }

        let words = LabelTokenParser.wordTokens(from: candidate)
        if let keyword = foodKeywords.first(where: { words.contains($0) }),
           !AnimalLabelMapper.sharesAnimalWord(keyword: keyword) {
            return explicitMappings[keyword] ?? keyword
        }

        return nil
    }

}

private enum LabelTokenParser {
    static func wordTokens(from label: String) -> Set<String> {
        Set(
            label.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map { String($0).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
}

private enum AnimalLabelMapper {
    private static let animalKeywords: Set<String> = [
        "animal", "dog", "cat", "bird", "horse", "cow", "sheep", "goat", "pig",
        "deer", "lion", "tiger", "bear", "elephant", "zebra", "giraffe",
        "monkey", "ape", "rabbit", "squirrel", "fox", "wolf", "fish", "shark",
        "whale", "dolphin", "snake", "lizard", "frog", "turtle", "insect",
        "butterfly", "bee", "spider", "duck", "goose", "chicken", "hen",
        "rooster", "penguin", "koala", "kangaroo", "leopard", "cheetah", "sloth"
    ]

    /// Short common name for UI (e.g. "Three-Toed Sloth" → "Sloth").
    static func displayTitle(for label: String) -> String? {
        let lower = label.lowercased()
        let ordered = animalKeywords.sorted { $0.count > $1.count }
        guard let match = ordered.first(where: { lower.contains($0) }) else {
            return nil
        }
        return match.prefix(1).uppercased() + match.dropFirst()
    }

    static func isAnimal(label: String) -> Bool {
        let lower = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }

        if animalKeywords.contains(lower) {
            return true
        }

        let words = LabelTokenParser.wordTokens(from: lower)
        if animalKeywords.contains(where: { words.contains($0) }) {
            return true
        }

        return animalKeywords.contains { keyword in
            lower.contains(keyword)
        }
    }

    /// Food keywords that are also animal terms (e.g. if "fish" were in both lists) must not classify animals as food.
    static func sharesAnimalWord(keyword: String) -> Bool {
        animalKeywords.contains(keyword)
    }
}
