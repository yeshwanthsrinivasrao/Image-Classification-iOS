import SwiftUI

struct ProgressOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                    .tint(Color(.white))

                Text(NSLocalizedString("Processing...", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray).opacity(0.8))
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("Processing image, please wait.", comment: ""))
    }
}

#Preview {
    ProgressOverlayView()
}
