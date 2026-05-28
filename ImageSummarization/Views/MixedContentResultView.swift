import SwiftUI

struct MixedContentResultView: View {
    let payload: MixedContentPayload
    let onCaptureNewImage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(uiImage: payload.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(NSLocalizedString("Selected mixed content image", comment: ""))

                    foodSection

                    Divider()

                    Text(NSLocalizedString("Text Section", comment: ""))
                        .font(.headline)
                        .bold()

                    TextSectionView(
                        title: NSLocalizedString("Extracted Text", comment: ""),
                        text: payload.extractedText,
                        placeholder: NSLocalizedString("Extracted text will appear here...", comment: "")
                    )

                    TextSectionView(
                        title: NSLocalizedString("Summarised Text", comment: ""),
                        text: payload.summarizedText,
                        placeholder: NSLocalizedString("Summary will appear here...", comment: "")
                    )
                }
                .padding()
            }

            Divider()

            Button(action: onCaptureNewImage) {
                Text(NSLocalizedString("Capture New Image", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .navigationTitle(NSLocalizedString("Mixed Content", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var foodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("Food Section", comment: ""))
                .font(.headline)
                .bold()

            Text(String(format: NSLocalizedString("Food Detected: %@", comment: ""), payload.classification.normalizedFoodQuery ?? payload.classification.topLabel))
                .font(.title3)
                .bold()

            if let nutrition = payload.nutrition {
                Text(String(format: NSLocalizedString("Calories: %@", comment: ""), nutrition.calorieDisplayValue))
                ForEach(nutrition.nutrients) { nutrient in
                    Text("• \(nutrient.name): \(nutrient.displayValue)")
                }
            }

            if let errorMessage = payload.nutritionErrorMessage {
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
