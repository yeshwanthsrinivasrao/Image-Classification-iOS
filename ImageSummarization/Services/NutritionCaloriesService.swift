import Foundation

/// Fetches USDA calories for object-description screens.
/// Comment out usages in the ViewModel and `CaloriesSectionView` in the UI to disable calories without changing other flows.
actor NutritionCaloriesService {
    private let nutritionService = NutritionService()

    func fetchCalories(for classification: ClassificationResult) async -> CaloriesDisplayInfo? {
        guard classification.contentType == .food else {
            return nil
        }

        let query = (classification.normalizedFoodQuery ?? classification.topLabel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return nil
        }

        do {
            let nutrition = try await nutritionService.fetchNutrition(for: query)
            return .from(nutrition: nutrition)
        } catch {
            return .unavailable(message: error.localizedDescription)
        }
    }
}
