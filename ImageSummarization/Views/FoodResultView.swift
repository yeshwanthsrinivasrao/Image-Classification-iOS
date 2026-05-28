import SwiftUI

struct FoodResultView: View {
    let payload: FoodResultPayload
    let onCaptureNewImage: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(uiImage: payload.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(NSLocalizedString("Selected food image", comment: ""))

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: NSLocalizedString("Food Detected: %@", comment: ""), payload.classification.normalizedFoodQuery ?? payload.classification.topLabel))
                        .font(.title3)
                        .bold()

                    Text(String(format: NSLocalizedString("Confidence: %.0f%%", comment: ""), payload.classification.confidence * 100))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let nutrition = payload.nutrition {
                        nutritionContent(nutrition)
                    }

                    if let errorMessage = payload.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                Button(action: onCaptureNewImage) {
                    Text(NSLocalizedString("Capture New Image", comment: ""))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("Food Details", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nutritionContent(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(nutrition.foodName)
                .font(.headline)

            Text(String(format: NSLocalizedString("Calories: %@", comment: ""), nutrition.calorieDisplayValue))
                .font(.body)

            ForEach(nutrition.nutrients) { nutrient in
                Text("• \(nutrient.name): \(nutrient.displayValue)")
                    .font(.body)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
