# ds4-uya

`ds4-uya` is a pure Uya, CPU-first rewrite plan for the DS4 runtime.

The current milestone is intentionally small and runnable on this Linux x86_64
machine: it provides a project skeleton, design docs, TODO plan, little-endian
binary helpers, and a GGUF inspector. Full text generation is planned in stages:
GGUF loading, tokenizer, CPU tensors, quantized kernels, transformer execution,
KV cache, sampler, and CLI chat.

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
```

For the partial model currently present in the sibling `ds4` project:

```sh
build/ds4-uya inspect /home/winger/uya/ds4/gguf/DeepSeek-V4-Flash-Q4KExperts-F16HC-F16Compressor-F16Indexer-Q8Attn-Q8Shared-Q8Out-chat-v2.gguf.part
```

## Status

- Pure Uya source only; no Metal, no C runtime reuse from the original DS4 code.
- CPU target: Linux x86_64 first.
- Implemented now: CLI plus GGUF loader, metadata/tensor-directory inspection,
  tensor lookup, tensor offsets, and truncation diagnostics.
- Not implemented yet: tokenizer and token generation.
