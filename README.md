# ds4-uya

`ds4-uya` is a pure Uya, CPU-first DS4 runtime.

The current milestone is intentionally small and runnable on this Linux x86_64
machine: it provides project docs, GGUF loading, tokenizer support, CPU tensor
views, scalar and optimized kernels, a reference transformer forward path, a
sampler, an in-memory greedy generation loop, GGUF-backed generation/chat CLI
paths, DS4 Flash schema diagnostics, and benchmarks.

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
build/ds4-uya audit /path/to/model.gguf
build/ds4-uya tensor /path/to/model.gguf output_norm.weight
build/ds4-uya view /path/to/model.gguf output_norm.weight
build/ds4-uya piece /path/to/model.gguf 0
build/ds4-uya encode /path/to/model.gguf "hello"
build/ds4-uya decode /path/to/model.gguf 33310
build/ds4-uya format-chat /path/to/model.gguf "hello"
build/ds4-uya generate /path/to/model.gguf "hello"
build/ds4-uya chat /path/to/model.gguf
build/ds4-uya bench
```

For the partial model currently present in the sibling `ds4` project:

```sh
build/ds4-uya inspect /home/winger/uya/ds4/gguf/DeepSeek-V4-Flash-Q4KExperts-F16HC-F16Compressor-F16Indexer-Q8Attn-Q8Shared-Q8Out-chat-v2.gguf.part
build/ds4-uya audit /home/winger/uya/ds4/gguf/DeepSeek-V4-Flash-Q4KExperts-F16HC-F16Compressor-F16Indexer-Q8Attn-Q8Shared-Q8Out-chat-v2.gguf.part
```

For a complete local DS4 Flash Q2 file, the documented non-default targets are:

```sh
make flash-q2-audit DS4_FLASH_Q2_GGUF=/path/to/ds4-flash-q2.gguf
make flash-q2-smoke DS4_FLASH_Q2_GGUF=/path/to/ds4-flash-q2.gguf
```

## Status

- Pure Uya source only; no Metal and no C runtime reuse from the original DS4
  code in the default build/runtime path.
- CPU target: Linux x86_64 first.
- Implemented now: CLI plus GGUF loader, metadata/tensor-directory inspection,
  tensor lookup, tensor offsets, tokenizer metadata loading, token lookup,
  GPT-2 byte-level BPE encode/decode, BOS/EOS/UNK/control token handling, CPU
  tensor views, root weight binding, scratch arena, KV cache layout, truncation
  diagnostics, scalar reference kernels for F32/F16 math, RMSNorm, RoPE,
  Softmax, dense matvec, Q8_0/Q2_K/Q4_K/IQ2_* dot, SiLU/SwiGLU, Uya `@vector` F32 dot,
  fused Q8_0/Q4_K dequant-dot fast paths, KV row access, dense GQA/MQA cache
  and attention mapping, DS4 Flash schema audit diagnostics, MoE dispatch planning,
  a dense transformer forward path with logits output,
  deterministic greedy/temperature/top-k/top-p/repeat-penalty sampling, an
  in-memory greedy generation loop, mmap-backed GGUF tensor-data loading into bound model
  weights, `generate`/`chat` output backed by file weights, full GGUF
  `tokenizer.chat_template` loading with DS4/DeepSeek chat prompt formatting,
  and a synthetic prompt/decode tokens/s benchmark.
- Current GGUF-backed generation supports the dense decoder subset used by the
  CPU forward path: `blk.N.*` tensor names, dense GQA/MQA when key/value per-head
  dims equal query head_dim, F32/F16 embeddings/norms/matrices, plus
  Q8_0/Q2_K/Q4_K/IQ2_* matrix matvec. DS4 Flash MoE/compressor/indexer/HC/split-LORA
  production layouts are detected by `audit` and still fail generation with an
  explicit unsupported-layout diagnostic until the full pure Uya Flash layer is
  wired into `runtime_generate_to_buffer`.
