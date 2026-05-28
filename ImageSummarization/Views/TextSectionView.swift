import SwiftUI

struct TextSectionView: View {
    let title: String
    let text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .bold()
                .foregroundColor(Color(.label))
                .accessibilityAddTraits(.isHeader)

            Group {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color(.placeholderText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .foregroundColor(Color(.label))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel(title)
            .accessibilityValue(text.isEmpty ? placeholder : text)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TextSectionView(
            title: "Extracted Text",
            text: "Sample extracted text from an image.",
            placeholder: "Extracted text will appear here..."
        )
        TextSectionView(
            title: "Summarized Text",
            text: "",
            placeholder: "Summary will appear here..."
        )
    }
    .padding()
}
