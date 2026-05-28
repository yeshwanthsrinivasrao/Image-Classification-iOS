import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel = ImageSummarizationViewModel()

    @State private var showSourceDialog = false
    @State private var showGalleryPicker = false
    @State private var showCameraPicker = false
    @State private var selectedImage: UIImage?
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 56))
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)

                        Text(NSLocalizedString("Choose or capture an image to classify its content.", comment: ""))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        Text(NSLocalizedString("Text and object results are shown on separate screens when available.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    Divider()

                    Button {
                        showSourceDialog = true
                    } label: {
                        Text(NSLocalizedString("Select / Capture Image", comment: ""))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .accessibilityLabel(NSLocalizedString("Select or capture an image", comment: ""))
                    .accessibilityHint(NSLocalizedString("Opens a menu to choose from the gallery or capture with the camera", comment: ""))
                    .disabled(viewModel.isProcessing)
                }

                if viewModel.isProcessing {
                    ProgressOverlayView()
                }
            }
            .navigationTitle(NSLocalizedString("Image Summarization", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: resultIsPresented) {
                resultDestination
            }
        }
        .confirmationDialog(
            NSLocalizedString("Choose Image Source", comment: ""),
            isPresented: $showSourceDialog,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Choose from Gallery", comment: "")) {
                showGalleryPicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(NSLocalizedString("Capture from Camera", comment: "")) {
                    showCameraPicker = true
                }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        }
        .sheet(isPresented: $showGalleryPicker) {
            PHPickerWrapper(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPickerWrapper(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            guard let image = newImage else { return }
            viewModel.processImage(image)
            selectedImage = nil
        }
        .onChange(of: viewModel.errorMessage) { message in
            if message != nil {
                showErrorAlert = true
            }
        }
        .alert(
            NSLocalizedString("Error", comment: ""),
            isPresented: $showErrorAlert
        ) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var resultIsPresented: Binding<Bool> {
        Binding {
            viewModel.processingResult != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.resetFlow()
            }
        }
    }

    @ViewBuilder
    private var resultDestination: some View {
        if let result = viewModel.processingResult {
            switch result {
            case .food(let payload):
                FoodResultView(payload: payload, onCaptureNewImage: restartCapture)
            case .text(let payload):
                TextSummaryResultView(payload: payload, onCaptureNewImage: restartCapture)
            case .objectDescription(let payload):
                ObjectDescriptionResultView(payload: payload, onCaptureNewImage: restartCapture)
            case .error(let message):
                ErrorResultView(message: message, onCaptureNewImage: restartCapture)
            }
        } else {
            EmptyView()
        }
    }

    private func restartCapture() {
        viewModel.resetFlow()
        showSourceDialog = true
    }
}

#Preview {
    ContentView()
}
