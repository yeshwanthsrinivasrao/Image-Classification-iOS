import Foundation

enum NutritionError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case noFoodFound
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return NSLocalizedString("USDA API key is not configured. Add USDA_API_KEY in the project build settings to enable nutrition lookup.", comment: "")
        case .invalidURL:
            return NSLocalizedString("Unable to create USDA nutrition request.", comment: "")
        case .noFoodFound:
            return NSLocalizedString("No nutrition data was found for this food.", comment: "")
        case .requestFailed(let reason):
            return String(format: NSLocalizedString("Nutrition lookup failed: %@", comment: ""), reason)
        }
    }
}

actor NutritionService {
    private let endpoint = "https://api.nal.usda.gov/fdc/v1/foods/search"

    func fetchNutrition(for query: String) async throws -> NutritionInfo {
        let apiKey = try apiKey()

        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "pageSize", value: "1")
        ]

        guard let url = components?.url else {
            throw NutritionError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw NutritionError.requestFailed("The USDA service returned an unexpected response.")
            }

            let decoded = try JSONDecoder().decode(USDAFoodSearchResponse.self, from: data)
            guard let food = decoded.foods.first else {
                throw NutritionError.noFoodFound
            }

            return NutritionInfo(
                foodName: food.description,
                calories: food.nutrientValue(named: "Energy"),
                nutrients: [
                        food.nutrientFact(name: "Protein", matching: "Protein"),
                        food.nutrientFact(name: "Carbohydrates", matching: "Carbohydrate"),
                        food.nutrientFact(name: "Fat", matching: "Total lipid"),
                        food.nutrientFact(name: "Fiber", matching: "Fiber, total dietary"),
                        food.nutrientFact(name: "Sugars", matching: "Total Sugars"),
                        food.nutrientFact(name: "Sodium", matching: "Sodium, Na"),
                        food.nutrientFact(name: "Calcium", matching: "Calcium, Ca"),
                        food.nutrientFact(name: "Vitamin A", matching: "Vitamin A"),
                        food.nutrientFact(name: "Vitamin C", matching: "Vitamin C"),
                        food.nutrientFact(name: "Cholesterol", matching: "Cholesterol"),
                        food.nutrientFact(name: "Saturated Fat", matching: "Fatty acids, total saturated")
                    ].compactMap { $0 }
            )
        } catch let error as NutritionError {
            throw error
        } catch {
            throw NutritionError.requestFailed(error.localizedDescription)
        }
    }

    private func apiKey() throws -> String {
        
        guard let value = Bundle.main.object(forInfoDictionaryKey: "USDA_API_KEY") as? String else {throw NutritionError.missingAPIKey}

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("$(") else {
            throw NutritionError.missingAPIKey
        }

        return trimmed
    }
}

private struct USDAFoodSearchResponse: Decodable {
    let foods: [USDAFood]
}

private struct USDAFood: Decodable {
    let description: String
    let foodNutrients: [USDAFoodNutrient]

    func nutrientValue(named name: String) -> Double? {
        foodNutrients.first { $0.nutrientName.localizedCaseInsensitiveContains(name) }?.value
    }

    func nutrientFact(name displayName: String, matching nutrientName: String) -> NutrientFact? {
        guard let nutrient = foodNutrients.first(where: {
            $0.nutrientName.localizedCaseInsensitiveContains(nutrientName)
        }) else {
            return nil
        }

        return NutrientFact(
            name: displayName,
            value: nutrient.value,
            unit: nutrient.unitName.lowercased()
        )
    }
}

private struct USDAFoodNutrient: Decodable {
    let nutrientName: String
    let value: Double
    let unitName: String
}
