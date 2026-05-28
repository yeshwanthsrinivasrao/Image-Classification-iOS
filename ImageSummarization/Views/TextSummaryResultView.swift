import SwiftUI

struct TextSummaryResultView: View {
    let payload: TextSummaryPayload
    let onCaptureNewImage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextSectionView(
                        title: NSLocalizedString("Extracted Text", comment: ""),
                        text: payload.extractedText,
                        placeholder: NSLocalizedString("Extracted text will appear here...", comment: "")
                    )

                    Divider()

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
        .navigationTitle(NSLocalizedString("Text Summary", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}
