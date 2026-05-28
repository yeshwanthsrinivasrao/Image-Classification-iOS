import CoreML
import Foundation

let packagePath = CommandLine.arguments[1]
let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: packagePath))
let model = try MLModel(contentsOf: compiled)

func predict(inputIds: MLMultiArray, attentionMask: MLMultiArray) throws -> Int32 {
    let provider = try MLDictionaryFeatureProvider(dictionary: [
        "input_ids": MLFeatureValue(multiArray: inputIds),
        "attention_mask": MLFeatureValue(multiArray: attentionMask),
    ])
    let output = try model.prediction(from: provider)
    let logits = output.featureValue(for: "logits")!.multiArrayValue!
    let vocab = logits.shape[2].intValue
    var bestId: Int32 = 0
    var bestScore = -Float.greatestFiniteMagnitude
    for token in 0..<vocab {
        let score = logits[[0, 0, token] as [NSNumber]].floatValue
        if score > bestScore {
            bestScore = score
            bestId = Int32(token)
        }
    }
    return bestId
}

var inputIds = try MLMultiArray(shape: [1, 128], dataType: .int32)
var attentionMask = try MLMultiArray(shape: [1, 128], dataType: .int32)
// Fake encoded source: pad=1, bos-like ids at start
for index in 0..<128 {
    inputIds[[0, index] as [NSNumber]] = 1
    attentionMask[[0, index] as [NSNumber]] = index < 20 ? 1 : 0
}

var generated: [Int32] = []
for step in 0..<8 {
    let token = try predict(inputIds: inputIds, attentionMask: attentionMask)
    generated.append(token)
    print("step", step, "token", token)
    // Append token into next free encoder slot
    let used = (0..<128).filter { attentionMask[[0, $0] as [NSNumber]].intValue == 1 }.count
    if used < 128 {
        inputIds[[0, used] as [NSNumber]] = NSNumber(value: token)
        attentionMask[[0, used] as [NSNumber]] = 1
    }
}
print("generated ids:", generated)
