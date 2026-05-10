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

## Phase 9: DS4 Flash Q2 完整支持

当前 Phase 8 已经能跑 GGUF-backed dense decoder 子集，但还不是 DS4 Flash Q2
生产模型的完整支持。完整支持还需要补齐以下内容：

- [ ] 用完整 DS4 Flash Q2 GGUF 跑一次 schema audit，记录所有 metadata key、tensor name、shape、dtype、分片/对齐规则。
- [ ] 解析 DS4 Flash Q2 必需超参：`feed_forward_length`、RoPE theta/scale、RMS eps、GQA key/value 维度、expert/router 相关参数。
- [ ] 支持 GQA/MQA：允许 `n_head != n_head_kv`，KV cache、attention 读写和 head 映射按 kv heads 工作。
- [ ] 支持 DS4 Flash 的 MoE forward：router logits、top-k expert 选择、shared expert、expert 权重绑定和 expert-major dispatch 真正接入模型层。
- [ ] 支持 DS4 Flash 特有 compressor/indexer/HC tensor 命名和 forward 分支，缺失或未知 tensor 要给出具体诊断。
- [ ] 实现 Q2 系列 matvec kernel：至少覆盖实际文件中出现的 `Q2_K`、`IQ2_XXS`、`IQ2_XS`、`IQ2_S` 等 dtype，并与 reference dot 对照。
- [ ] 扩展现有 Q4/Q8/F16 路径，覆盖 experts、attention、shared/output 等不同 tensor 位置的混合 dtype。
- [ ] 改造权重加载策略：大模型不能默认 `malloc` 读入所有 tensor，需要 mmap/按需加载/分块加载，并保持 tensor lifetime 清晰。
- [ ] 支持真实 tokenizer chat template，把 `chat` 从裸 prompt REPL 升级为模型格式化对话输入。
- [ ] 增加真实模型 smoke：`inspect`、`encode`、`generate`、`chat` 在 DS4 Flash Q2 GGUF 上不崩溃，并能产出非空文本。
- [ ] 增加 golden 对照：同 prompt 与原 DS4 或可信参考实现对齐 logits top-k / token 序列，误差和可接受差异写入测试说明。
- [ ] 增加性能验收：报告真实 DS4 Flash Q2 的 prompt/decode tokens/s、峰值内存、加载时间。

验收标准：

- `build/ds4-uya generate <ds4-flash-q2.gguf> "<prompt>"` 能加载完整模型并产出文本。
- `build/ds4-uya chat <ds4-flash-q2.gguf>` 使用 chat template，多轮输入不会破坏 KV/cache 状态或内存。
- DS4 Flash Q2 中出现的所有 tensor dtype 和结构分支都有实现或明确跳过理由。
- 对 unsupported/缺 tensor/坏 shape/坏 dtype 的报错能定位到具体 layer 和 tensor name。
- 真实模型 smoke、golden 对照、性能 benchmark 纳入 `make test` 或单独的 documented test target。
