import Foundation

struct CaloriesNutrientLine: Equatable, Identifiable {
    var id: String { name }
    let name: String
    let displayValue: String
}

/// Display model for optional nutrition on object-description results.
/// Kept separate so calories UI and fetch logic can be disabled without affecting core flows.
struct CaloriesDisplayInfo: Equatable {
    let foodName: String
    let calorieText: String
    let nutrients: [CaloriesNutrientLine]
    let errorMessage: String?

    static func from(nutrition: NutritionInfo) -> CaloriesDisplayInfo {
        CaloriesDisplayInfo(
            foodName: nutrition.foodName,
            calorieText: nutrition.calorieDisplayValue,
            nutrients: nutrition.nutrients.map {
                CaloriesNutrientLine(name: $0.name, displayValue: $0.displayValue)
            },
            errorMessage: nil
        )
    }

    static func unavailable(message: String) -> CaloriesDisplayInfo {
        CaloriesDisplayInfo(
            foodName: "",
            calorieText: NSLocalizedString("Not available", comment: ""),
            nutrients: [],
            errorMessage: message
        )
    }
}
