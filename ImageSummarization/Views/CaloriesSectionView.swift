import SwiftUI

/// Optional detailed nutrition block for object-description results.
/// Remove or comment out this view in `ObjectDescriptionResultView` to hide calories in the UI.
struct CaloriesSectionView: View {
    let caloriesInfo: CaloriesDisplayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("Nutrition", comment: ""))
                .font(.headline)
                .bold()

            if !caloriesInfo.foodName.isEmpty {
                Text(caloriesInfo.foodName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(String(format: NSLocalizedString("Calories: %@", comment: ""), caloriesInfo.calorieText))
                .font(.body)

            if !caloriesInfo.nutrients.isEmpty {
                ForEach(caloriesInfo.nutrients) { nutrient in
                    Text("• \(nutrient.name): \(nutrient.displayValue)")
                        .font(.body)
                }
            }

            if let errorMessage = caloriesInfo.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
