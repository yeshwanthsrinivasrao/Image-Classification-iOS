import SwiftUI
import UIKit

@MainActor
final class ImageSummarizationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var processingResult: ImageProcessingResult?

    // MARK: - Private

    private let textExtractionService = TextExtractionService()
    private let summarizationService = SummarizationService()
    private let imageClassificationService = ImageClassificationService()
    private let textValidationService = TextValidationService()
    private let nutritionCaloriesService = NutritionCaloriesService()

    private static let noTextOrObjectMessage = NSLocalizedString(
        "Unable to analyze this image. No readable text or recognizable object was found.",
        comment: ""
    )

    // MARK: - Public API

    /// Full enhanced pipeline: text first, then object description when OCR finds no text.
    func processImage(_ image: UIImage) {
        Task {
            await runEnhancedPipeline(for: image)
        }
    }

    func resetFlow() {
        processingResult = nil
        errorMessage = nil
    }

    // MARK: - Private Pipeline

    private func runEnhancedPipeline(for image: UIImage) async {
        resetState()
        isProcessing = true

        let textOutcome = await buildTextPayload(for: image)

        switch textOutcome {
        case .success(let payload):
            processingResult = .text(payload)
            isProcessing = false
            return
        case .failure(let message):
            processingResult = .error(message)
            isProcessing = false
            return
        case .noText:
            break
        }

        do {
            let classification = try await imageClassificationService.classify(image)
            let objectDescription = try await summarizationService.summarize(
                "",
                imageLabel: classification.displayTitle,
                confidence: classification.confidence
            )

            let caloriesInfo = await nutritionCaloriesService.fetchCalories(for: classification)

            processingResult = .objectDescription(ObjectDescriptionPayload(
                image: image,
                classification: classification,
                description: objectDescription,
                caloriesInfo: caloriesInfo
            ))
        } catch {
            processingResult = .error(Self.noTextOrObjectMessage)
        }

        isProcessing = false
    }

    private func resetState() {
        errorMessage = nil
        processingResult = nil
    }

    private func buildTextPayload(for image: UIImage) async -> TextPipelineOutcome {
        do {
            let rawText = try await textExtractionService.extractText(from: image)
            let validation = textValidationService.validate(rawText)
            guard validation.isValid else {
                return .failure(validation.message)
            }

            let summary = try await summarizationService.summarize(rawText)
            return .success(TextSummaryPayload(
                image: image,
                extractedText: rawText,
                summarizedText: summary
            ))
        } catch TextExtractionError.noTextFound {
            return .noText
        } catch let error as SummarizationError {
            return .failure(error.localizedDescription)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

private enum TextPipelineOutcome {
    case success(TextSummaryPayload)
    case failure(String)
    case noText
}
