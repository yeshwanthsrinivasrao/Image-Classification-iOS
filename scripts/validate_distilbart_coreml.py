#!/usr/bin/env python3
"""Compare bundled Core ML DistilBART against PyTorch generate()."""

from pathlib import Path

import numpy as np
import torch
import coremltools as ct
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "ImageSummarization/Resources/MLModels/DistilBARTSummariser.mlpackage"
TEXT = (
    "The tower is 324 metres tall, about the same height as an 81-storey building, "
    "and the tallest structure in Paris."
)

model_id = "sshleifer/distilbart-cnn-6-6"
tokenizer = AutoTokenizer.from_pretrained(model_id)
pt_model = AutoModelForSeq2SeqLM.from_pretrained(model_id).eval()

enc = tokenizer(TEXT, return_tensors="pt", max_length=128, truncation=True, padding="max_length")
with torch.no_grad():
    generated = pt_model.generate(
        **enc,
        max_new_tokens=56,
        min_new_tokens=1,
        do_sample=False,
        num_beams=1,
    )
pt_summary = tokenizer.decode(generated[0], skip_special_tokens=True)
print("PyTorch summary:", pt_summary)

compiled = ct.models.MLModel.compile_model(str(PACKAGE))
ml = ct.models.MLModel(str(compiled))
out = ml.predict(
    {
        "input_ids": enc["input_ids"].numpy().astype(np.int32),
        "attention_mask": enc["attention_mask"].numpy().astype(np.int32),
    }
)
logits = out["logits"]
print("Core ML logits shape:", logits.shape, "dtype:", logits.dtype)
next_id = int(np.argmax(logits))
print("Core ML argmax token id:", next_id, "->", tokenizer.decode([next_id]))
print("Core ML top-5 ids:", np.argsort(logits.reshape(-1))[-5:][::-1])
