import Foundation
import UIKit

enum ImageContentType: String {
    case food
    case animal
    case text
    case mixed
    case other
}

struct ClassificationResult {
    /// Single user-facing name (e.g. "Jackfruit", "Sloth") — not comma-separated synonyms.
    let displayTitle: String
    /// Cleaned primary MobileNet label used for summarisation prompts.
    let topLabel: String
    let confidence: Float
    let normalizedFoodQuery: String?
    let contentType: ImageContentType

    var isFood: Bool {
        contentType == .food
    }
}

struct NutrientFact: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String

    var displayValue: String {
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formatted) \(unit)"
    }
}

struct NutritionInfo {
    let foodName: String
    let calories: Double?
    let nutrients: [NutrientFact]

    var calorieDisplayValue: String {
        guard let calories else { return "Not available" }
        return String(format: "%.0f kcal", calories)
    }
}

enum TextValidationResult {
    case valid
    case empty
    case dummyContent
    case nonLanguage
    case meaninglessContent

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .valid:
            return ""
        case .empty:
            return NSLocalizedString("No text could be extracted from this image.", comment: "")
        case .dummyContent:
            return NSLocalizedString("This image contains placeholder or dummy text and cannot be summarised.", comment: "")
        case .nonLanguage:
            return NSLocalizedString("Image contains symbols or characters only. No meaningful text to summarise.", comment: "")
        case .meaninglessContent:
            return NSLocalizedString("The extracted text does not contain enough meaningful content to summarise.", comment: "")
        }
    }
}

struct ObjectDescriptionPayload {
    let image: UIImage
    let classification: ClassificationResult
    let description: String
    /// Optional; populated by `NutritionCaloriesService`. Omit or pass `nil` when calories are disabled.
    let caloriesInfo: CaloriesDisplayInfo?
}

struct TextSummaryPayload {
    let image: UIImage
    let extractedText: String
    let summarizedText: String
}

struct FoodResultPayload {
    let image: UIImage
    let classification: ClassificationResult
    let nutrition: NutritionInfo?
    let errorMessage: String?
}

struct MixedContentPayload {
    let image: UIImage
    let classification: ClassificationResult
    let nutrition: NutritionInfo?
    let nutritionErrorMessage: String?
    let extractedText: String
    let summarizedText: String
}

enum ImageProcessingResult {
    case food(FoodResultPayload)
    case text(TextSummaryPayload)
    // case mixed(MixedContentPayload) — removed; object+text images use text-only or general error.
    case objectDescription(ObjectDescriptionPayload)
    case error(String)
}
