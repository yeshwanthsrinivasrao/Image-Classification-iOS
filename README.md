# Image Classification iOS

AI-powered iOS Proof of Concept (POC) built using SwiftUI, Vision, and CoreML for image analysis, OCR processing, and image summarization.

---

## Overview

This project explores on-device AI capabilities available on iOS using Apple's Vision and CoreML frameworks. The application is designed as an R&D POC to evaluate image classification, text extraction, and AI-powered summarization workflows.

---

## Features

* Image Classification using CoreML
* OCR Text Extraction using Vision Framework
* AI-based Image Summarization
* On-device Machine Learning Inference
* SwiftUI-based User Interface
* Modular Architecture for Future AI Integrations

---

## Technology Stack

* Swift 5
* SwiftUI
* Vision Framework
* CoreML
* URLSession
* Xcode

---

## Project Structure

```text
ImageSummarization/
├── ImageSummarization/
├── ImageSummarization.xcodeproj
├── scripts/
├── .cursor/
├── README.md
├── .gitignore
├── project.yml
└── Documentation Files
```

---

## AI Models

### MobileNetV2

Used for image classification and object recognition.

**Purpose**

* Detect objects present in an image
* Generate classification labels
* Provide confidence scores

### DistilBART Summarizer

Used for text summarization after OCR extraction.

**Purpose**

* Summarize extracted text
* Generate concise descriptions
* Reduce large text blocks into meaningful insights

---

## Model Initialization

### MobileNetV2 Initialization

```swift
let model = try MobileNetV2(configuration: MLModelConfiguration())
let visionModel = try VNCoreMLModel(for: model.model)
```

### DistilBART Initialization

```swift
let configuration = MLModelConfiguration()

let summarizer = try DistilBARTSummariser(
    configuration: configuration
)
```

---

## OCR Workflow

1. User selects an image.
2. Vision framework extracts text.
3. Extracted text is validated.
4. DistilBART generates summary.
5. Summary is displayed to the user.

---

## Image Classification Workflow

1. User selects an image.
2. MobileNetV2 performs classification.
3. Top prediction is extracted.
4. Classification result is displayed.

---

## Ignored Files

The following files and folders are intentionally excluded from GitHub:

### Build Artifacts

```text
DerivedData/
.build/
```

### User Specific Files

```text
xcuserdata/
.DS_Store
```

### Swift Package Manager

```text
.swiftpm/
Packages/
```

### CocoaPods

```text
Pods/
```

### Compiled CoreML Models

```text
*.mlmodelc
```

### Large AI Model Files

```text
*.mlpackage
*.mlmodel
*.bin
```

### Local Secrets

```text
.env
*.xcconfig
Secrets.swift
APIKeys.swift
```

---

## Setup Instructions

### Clone Repository

```bash
git clone https://github.com/yeshwanthsrinivasrao/Image-Classification-iOS.git
```

### Open Project

```bash
open ImageSummarization.xcodeproj
```

### Install Required Models

Large CoreML models are not included in the repository due to GitHub size limitations.

Download the required models separately and place them inside:

```text
ImageSummarization/Resources/MLModels/
```

---

## Current Limitations

* DistilBART model not included in repository.
* Large model weights are excluded.
* Image classification accuracy depends on model confidence.
* OCR quality depends on image quality.

---

## Future Enhancements

* Food Detection and Nutrition Analysis
* Calorie Estimation
* Apple Intelligence Integration
* On-device LLM Support
* Multi-language OCR
* Advanced Summarization Models

---

## Author

Yeshwanth Srinivas Rao

iOS Developer | Swift | SwiftUI | CoreML | Vision Framework
