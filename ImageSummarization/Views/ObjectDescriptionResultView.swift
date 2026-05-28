import SwiftUI

struct ObjectDescriptionResultView: View {
    let payload: ObjectDescriptionPayload
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
                        .accessibilityLabel(NSLocalizedString("Selected image", comment: ""))

                    Text(payload.classification.displayTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: NSLocalizedString("Confidence: %.0f%%", comment: ""), payload.classification.confidence * 100))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(String(format: NSLocalizedString("Category: %@", comment: ""), payload.classification.contentType.rawValue.capitalized))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    TextSectionView(
                        title: NSLocalizedString("AI Description", comment: ""),
                        text: payload.description,
                        placeholder: NSLocalizedString("Description will appear here...", comment: "")
                    )

                    // Comment out the block below to disable calories in the UI.
                    if let caloriesInfo = payload.caloriesInfo {
                        CaloriesSectionView(caloriesInfo: caloriesInfo)
                    }
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
        .navigationTitle(NSLocalizedString("Object Description", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}
