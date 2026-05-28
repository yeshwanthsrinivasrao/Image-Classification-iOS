import CoreML
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let model = try MLModel(contentsOf: url)
print("Inputs:")
for key in model.modelDescription.inputDescriptionsByName.keys.sorted() {
    let desc = model.modelDescription.inputDescriptionsByName[key]!
    print("  \(key): type=\(desc.type)")
    if let shape = desc.multiArrayConstraint?.shape {
        print("    shape=\(shape)")
    }
}
print("Outputs:")
for key in model.modelDescription.outputDescriptionsByName.keys.sorted() {
    let desc = model.modelDescription.outputDescriptionsByName[key]!
    print("  \(key): type=\(desc.type)")
    if let shape = desc.multiArrayConstraint?.shape {
        print("    shape=\(shape)")
    }
}
