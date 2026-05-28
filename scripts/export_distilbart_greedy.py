#!/usr/bin/env python3
"""Export DistilBART greedy summarization to Core ML with fixed-shape token output."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
import torch.nn as nn
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer


class GreedySummarizer(nn.Module):
    """Unrolled greedy decode for a fixed number of new tokens (Core ML friendly)."""

    def __init__(self, model: AutoModelForSeq2SeqLM, max_new_tokens: int) -> None:
        super().__init__()
        self.model = model
        self.max_new_tokens = max_new_tokens
        self.decoder_start_token_id = model.config.decoder_start_token_id
        self.eos_token_id = model.config.eos_token_id

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        encoder_outputs = self.model.get_encoder()(
            input_ids=input_ids,
            attention_mask=attention_mask,
        )
        batch_size = input_ids.shape[0]
        device = input_ids.device
        decoder_input_ids = torch.full(
            (batch_size, 1),
            self.decoder_start_token_id,
            dtype=torch.long,
            device=device,
        )
        generated: list[torch.Tensor] = []
        for _ in range(self.max_new_tokens):
            outputs = self.model(
                attention_mask=attention_mask,
                decoder_input_ids=decoder_input_ids,
                encoder_outputs=encoder_outputs,
                use_cache=False,
            )
            next_token = outputs.logits[:, -1, :].argmax(dim=-1, keepdim=True)
            generated.append(next_token)
            decoder_input_ids = torch.cat([decoder_input_ids, next_token], dim=1)
        return torch.cat(generated, dim=1)


def export(
    model_id: str,
    output_path: Path,
    max_input_length: int,
    max_new_tokens: int,
    tokenizer_dir: Path,
) -> None:
    print(f"Loading {model_id}...")
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_id, torch_dtype=torch.float32)
    model.to(torch.float32)
    model.eval()

    tokenizer_dir.mkdir(parents=True, exist_ok=True)
    tokenizer.save_pretrained(tokenizer_dir)
    print(f"Saved tokenizer to {tokenizer_dir}")

    wrapper = GreedySummarizer(model, max_new_tokens=max_new_tokens)
    wrapper.eval()

    example = tokenizer(
        "The tower is 324 metres tall, about the same height as an 81-storey building.",
        return_tensors="pt",
        max_length=max_input_length,
        truncation=True,
        padding="max_length",
    )
    input_ids = example["input_ids"]
    attention_mask = example["attention_mask"]

    print("Tracing greedy summarizer...")
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (input_ids, attention_mask))

    print("Converting to Core ML...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, max_input_length), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, max_input_length), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="generated_token_ids", dtype=np.int32)],
        minimum_deployment_target=ct.target.iOS15,
        convert_to="neuralnetwork",
    )
    mlmodel.author = "ImageSummarization"
    mlmodel.short_description = "DistilBART greedy summarization (fixed output length)"
    mlmodel.version = "1"
    mlmodel.save(str(output_path))
    print(f"Saved Core ML model to {output_path}")

    # Sanity check against PyTorch reference
    with torch.no_grad():
        ref_ids = wrapper(input_ids, attention_mask)[0].tolist()
    ref_text = tokenizer.decode(ref_ids, skip_special_tokens=True)
    print("Reference summary:", ref_text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default="sshleifer/distilbart-cnn-6-6")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("ImageSummarization/Resources/MLModels/DistilBARTSummariserGen.mlpackage"),
    )
    parser.add_argument(
        "--tokenizer-dir",
        type=Path,
        default=Path("ImageSummarization/Resources/MLModels/DistilBARTSummariser/tokenizer"),
    )
    parser.add_argument("--max-input-length", type=int, default=128)
    parser.add_argument("--max-new-tokens", type=int, default=56)
    args = parser.parse_args()

    try:
        export(
            args.model_id,
            args.output,
            args.max_input_length,
            args.max_new_tokens,
            args.tokenizer_dir,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Export failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
