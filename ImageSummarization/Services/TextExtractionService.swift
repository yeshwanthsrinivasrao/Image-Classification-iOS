import UIKit
import Vision

enum TextExtractionError: LocalizedError {
    case invalidImage
    case noTextFound
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("The selected image could not be processed.", comment: "")
        case .noTextFound:
            return NSLocalizedString("No text was found in the image.", comment: "")
        case .recognitionFailed(let reason):
            return String(format: NSLocalizedString("Text recognition failed: %@", comment: ""), reason)
        }
    }
}

actor TextExtractionService {
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = normalizedCGImage(from: image) else {
                    throw TextExtractionError.invalidImage
                }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: TextExtractionError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: TextExtractionError.noTextFound)
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")
                if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: TextExtractionError.noTextFound)
                } else {
                    continuation.resume(returning: fullText)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.02

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TextExtractionError.recognitionFailed(error.localizedDescription))
            }
        }
    }
    	
    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage { return cg }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in image.draw(at: .zero) }
        return normalized.cgImage
    }
}
