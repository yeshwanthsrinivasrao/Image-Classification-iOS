import SwiftUI

struct ErrorResultView: View {
    let message: String
    let onCaptureNewImage: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.label))
                .padding(.horizontal)

            Button(action: onCaptureNewImage) {
                Text(NSLocalizedString("Capture New Image", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle(NSLocalizedString("Unsupported Image", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}
