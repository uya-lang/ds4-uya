# Project Guidance

- Keep this project pure Uya. Do not copy Metal kernels or depend on the old C
  runtime as part of the implementation.
- Target Linux x86_64 CPU first; Apple Metal support belongs only in historical
  comparison notes.
- Prefer small, testable modules: binary helpers, GGUF reader, tokenizer, tensor
  storage, quantization kernels, model graph, session/KV cache, sampler, CLI.
- Be honest about runtime status. A GGUF inspector or loader is not generation.
- Avoid large model downloads in this repository. Use paths to external GGUF
  files and keep fixtures tiny.

