import CoreML
import Foundation

let packagePath = CommandLine.arguments[1]
let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: packagePath))
let model = try MLModel(contentsOf: compiled)

var inputIds = try MLMultiArray(shape: [1, 128], dataType: .int32)
var attentionMask = try MLMultiArray(shape: [1, 128], dataType: .int32)
for index in 0..<128 {
    inputIds[[0, index] as [NSNumber]] = 1
    attentionMask[[0, index] as [NSNumber]] = index == 0 ? 1 : 0
}

var decoderInputIds = try MLMultiArray(shape: [1, 4], dataType: .int32)
decoderInputIds[[0, 0] as [NSNumber]] = 0
decoderInputIds[[0, 1] as [NSNumber]] = 42
decoderInputIds[[0, 2] as [NSNumber]] = 42
decoderInputIds[[0, 3] as [NSNumber]] = 42

let base = try MLDictionaryFeatureProvider(dictionary: [
    "input_ids": MLFeatureValue(multiArray: inputIds),
    "attention_mask": MLFeatureValue(multiArray: attentionMask),
])
let withDecoder = try MLDictionaryFeatureProvider(dictionary: [
    "input_ids": MLFeatureValue(multiArray: inputIds),
    "attention_mask": MLFeatureValue(multiArray: attentionMask),
    "decoder_input_ids": MLFeatureValue(multiArray: decoderInputIds),
])

let baseOut = try model.prediction(from: base)
let baseLogits = baseOut.featureValue(for: "logits")!.multiArrayValue!
print("Base logits shape:", baseLogits.shape)

do {
    let decoderOut = try model.prediction(from: withDecoder)
    let decoderLogits = decoderOut.featureValue(for: "logits")!.multiArrayValue!
    print("Decoder-input logits shape:", decoderLogits.shape)
} catch {
    print("decoder_input_ids rejected:", error.localizedDescription)
}
