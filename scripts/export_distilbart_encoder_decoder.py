#!/usr/bin/env python3
"""Export DistilBART encoder and single decoder-step models for on-device greedy decode."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
import torch.nn as nn
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer


class EncoderWrapper(nn.Module):
    def __init__(self, model: AutoModelForSeq2SeqLM) -> None:
        super().__init__()
        self.encoder = model.get_encoder()

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        outputs = self.encoder(input_ids=input_ids, attention_mask=attention_mask)
        return outputs.last_hidden_state


class DecoderStepWrapper(nn.Module):
    def __init__(self, model: AutoModelForSeq2SeqLM) -> None:
        super().__init__()
        self.model = model

    def forward(
        self,
        encoder_hidden_states: torch.Tensor,
        attention_mask: torch.Tensor,
        decoder_input_ids: torch.Tensor,
    ) -> torch.Tensor:
        outputs = self.model(
            encoder_outputs=(encoder_hidden_states,),
            attention_mask=attention_mask,
            decoder_input_ids=decoder_input_ids,
            use_cache=False,
        )
        return outputs.logits[:, -1, :]


def convert_traced(
    traced: torch.jit.ScriptModule,
    inputs: list[ct.TensorType],
    outputs: list[ct.TensorType],
    path: Path,
    description: str,
) -> None:
    mlmodel = ct.convert(
        traced,
        inputs=inputs,
        outputs=outputs,
        minimum_deployment_target=ct.target.iOS17,
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT32,
    )
    mlmodel.author = "ImageSummarization"
    mlmodel.short_description = description
    mlmodel.version = "1"
    mlmodel.save(str(path))
    print(f"Saved {path}")


def export_all(
    model_id: str,
    out_dir: Path,
    tokenizer_dir: Path,
    max_input_length: int,
    max_decoder_length: int,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_id, dtype=torch.float32)
    model.eval()

    tokenizer_dir.mkdir(parents=True, exist_ok=True)
    tokenizer.save_pretrained(tokenizer_dir)

    sample = tokenizer(
        "The tower is 324 metres tall.",
        return_tensors="pt",
        max_length=max_input_length,
        truncation=True,
        padding="max_length",
    )
    input_ids = sample["input_ids"]
    attention_mask = sample["attention_mask"]

    encoder = EncoderWrapper(model)
    with torch.no_grad():
        encoder_hidden = encoder(input_ids, attention_mask)
    encoder_trace = torch.jit.trace(encoder, (input_ids, attention_mask))

    convert_traced(
        encoder_trace,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, max_input_length), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, max_input_length), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="encoder_hidden_states", dtype=np.float32)],
        path=out_dir / "DistilBARTEncoder.mlpackage",
        description="DistilBART encoder",
    )

    decoder_input_ids = torch.full(
        (1, max_decoder_length),
        model.config.pad_token_id,
        dtype=torch.long,
    )
    decoder_input_ids[:, 0] = model.config.decoder_start_token_id
    decoder = DecoderStepWrapper(model)
    with torch.no_grad():
        logits = decoder(encoder_hidden, attention_mask, decoder_input_ids)
    decoder_trace = torch.jit.trace(
        decoder, (encoder_hidden, attention_mask, decoder_input_ids)
    )

    convert_traced(
        decoder_trace,
        inputs=[
            ct.TensorType(
                name="encoder_hidden_states",
                shape=tuple(int(x) for x in encoder_hidden.shape),
                dtype=np.float32,
            ),
            ct.TensorType(name="attention_mask", shape=(1, max_input_length), dtype=np.int32),
            ct.TensorType(name="decoder_input_ids", shape=(1, max_decoder_length), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="next_token_logits", dtype=np.float32)],
        path=out_dir / "DistilBARTDecoderStep.mlpackage",
        description="DistilBART decoder step (last-position logits)",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default="sshleifer/distilbart-cnn-6-6")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("ImageSummarization/Resources/MLModels"),
    )
    parser.add_argument(
        "--tokenizer-dir",
        type=Path,
        default=Path("ImageSummarization/Resources/MLModels/DistilBARTSummariser/tokenizer"),
    )
    parser.add_argument("--max-input-length", type=int, default=128)
    parser.add_argument("--max-decoder-length", type=int, default=56)
    args = parser.parse_args()
    try:
        export_all(
            args.model_id,
            args.out_dir,
            args.tokenizer_dir,
            args.max_input_length,
            args.max_decoder_length,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Export failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
