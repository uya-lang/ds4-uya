# ds4-uya TODO

## Phase 0: 项目基座

- [x] 新建 `~/uya/ds4-uya`。
- [x] 写 `README.md`。
- [x] 写 `docs/design.md`。
- [x] 写 `docs/todo.md`。
- [x] 增加 `Makefile`。
- [x] 实现纯 Uya CLI。
- [x] 实现 little-endian binary helpers。
- [x] 实现 GGUF inspector。
- [x] 增加 binary helper 测试。

验收标准：

- `make build` 生成 `build/ds4-uya`。
- `build/ds4-uya --help` 可运行。
- `build/ds4-uya inspect <file>` 能输出 GGUF header 或明确错误。
- `make test` 通过。

## Phase 1: GGUF loader

- [x] 把 inspector 扩展成持久化 loader。
- [x] 记录 metadata key/value 中的关键模型超参。
- [x] 记录 tokenizer metadata。
- [x] 记录完整 tensor info 表。
- [x] 计算每个 tensor 的绝对文件 offset 和 byte size。
- [x] 支持 alignment。
- [x] 对 `.part` 文件报出截断发生在 metadata、tensor directory 还是 tensor data。

验收标准：

- 能列出完整模型所有 tensor。
- 能按 tensor 名称查到 dtype、shape、offset。
- 对坏文件/截断文件不崩溃。

## Phase 2: tokenizer

- [x] 解析 GGUF tokenizer metadata。
- [x] 实现 token id 到 piece。
- [x] 实现 encode。
- [x] 实现 decode。
- [x] 支持 BOS/EOS/UNK/control tokens。
- [x] 增加 roundtrip tests。

验收标准：

- 固定 prompt 的 token 序列与参考实现一致。
- decode 能还原普通文本和特殊 token 策略。

## Phase 3: CPU tensor runtime

- [x] 定义 dtype enum。
- [x] 定义 tensor view。
- [x] 定义 model weight table。
- [x] 定义 scratch arena。
- [x] 定义 KV cache layout。
- [x] 实现 bounds/shape 检查。

验收标准：

- 能按 tensor 名称加载 embedding/norm/head 等权重 view。
- scratch buffer 可复用，无 per-token 大量分配。

## Phase 4: reference kernels

- [x] F32 vector ops。
- [x] F16 load/convert。
- [x] RMSNorm。
- [x] RoPE。
- [x] Softmax。
- [x] Dense matvec。
- [x] Q8 dot。
- [x] Q4_K reference dot。
- [x] SwiGLU/SiLU。

验收标准：

- 每个 kernel 有小尺寸 golden test。
- scalar reference 输出稳定。

## Phase 5: Transformer forward

- [x] 建立模型超参结构。
- [x] 绑定每层 tensor。
- [x] 实现 single-token forward。
- [x] 实现 prompt prefill 的逐 token 路径。
- [x] 实现 logits 输出。

验收标准：

- 小模型或测试夹具能跑出 logits。
- 单层/全层输出可与参考实现对照。

## Phase 6: sampler 和 CLI generation

- [x] greedy sampler。
- [x] temperature。
- [x] top-k。
- [x] top-p。
- [x] repeat penalty。
- [x] `generate` 子命令。
- [x] `chat` 子命令。

验收标准：

- 给定 seed 和参数时输出可复现。
- 低配路径至少支持 greedy generation。

## Phase 7: CPU 优化

- [x] 为 Q8/Q4 dot 合并 dequant + dot。
- [x] 为 AVX2/F16C 机器增加 Uya SIMD 快路径。
- [x] 优化 KV cache 访问局部性。
- [x] 优化 MoE expert dispatch。
- [x] 增加 tokens/s benchmark。

验收标准：

- 优化版与 reference 误差在阈值内。
- benchmark 能报告 prompt/decode tokens/s。

## Phase 8: GGUF-backed 端到端文本生成

- [x] 从 GGUF tensor data 区读取实际权重 bytes。
- [x] 把文件权重挂到 `TensorView.data`，再绑定进 `ModelWeights`。
- [x] 从 GGUF metadata/tensor shape 推导 dense CPU forward 所需 config。
- [x] forward 支持 F16 norm/matrix，并放行 F32/F16/Q8_0/Q4_K dense matvec。
- [x] `generate` 子命令执行 encode -> prefill -> decode loop -> decode text。
- [x] `chat` 子命令加载一次模型并进入 stdin REPL。
- [x] 增加真实 GGUF fixture 的 runtime 端到端测试。

验收标准：

- 测试会写入一个小型 GGUF 文件，并从文件 tensor offsets 加载权重。
- `runtime_session_generate_to_buffer` 能基于 GGUF 权重生成可 decode 文本。
- 不支持的 DS4 MoE/GQA/命名布局返回明确 unsupported-layout 错误，而不是静默假生成。
