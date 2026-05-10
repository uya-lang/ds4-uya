# ds4-uya

`ds4-uya` is a pure Uya, CPU-first rewrite plan for the DS4 runtime.

The current milestone is intentionally small and runnable on this Linux x86_64
machine: it provides project docs, GGUF loading, tokenizer support, CPU tensor
views, scalar reference kernels, and a reference transformer forward path. Full
text generation is planned in stages: sampler wiring and CLI chat.

## Build

```sh
make build
```

The default compiler path is:

```sh
/home/winger/uya/uya/bin/uya
```

Override it with:

```sh
make build UYA=/path/to/uya
```

## Usage

```sh
build/ds4-uya --help
build/ds4-uya inspect /path/to/model.gguf
build/ds4-uya tensor /path/to/model.gguf output_norm.weight
build/ds4-uya view /path/to/model.gguf output_norm.weight
build/ds4-uya piece /path/to/model.gguf 0
build/ds4-uya encode /path/to/model.gguf "hello"
build/ds4-uya decode /path/to/model.gguf 33310
```

For the partial model currently present in the sibling `ds4` project:

```sh
build/ds4-uya inspect /home/winger/uya/ds4/gguf/DeepSeek-V4-Flash-Q4KExperts-F16HC-F16Compressor-F16Indexer-Q8Attn-Q8Shared-Q8Out-chat-v2.gguf.part
```

## Status

- Pure Uya source only; no Metal, no C runtime reuse from the original DS4 code.
- CPU target: Linux x86_64 first.
- Implemented now: CLI plus GGUF loader, metadata/tensor-directory inspection,
  tensor lookup, tensor offsets, tokenizer metadata loading, token lookup,
  GPT-2 byte-level BPE encode/decode, BOS/EOS/UNK/control token handling, CPU
  tensor views, root weight binding, scratch arena, KV cache layout, truncation
  diagnostics, and scalar reference kernels for F32/F16 math, RMSNorm, RoPE,
  Softmax, dense matvec, Q8_0/Q4_K dot, SiLU/SwiGLU, and a dense F32
  transformer forward fixture path with logits output.
- Not implemented yet: sampler and token generation CLI.
