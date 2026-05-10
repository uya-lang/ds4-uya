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

- [ ] 定义 dtype enum。
- [ ] 定义 tensor view。
- [ ] 定义 model weight table。
- [ ] 定义 scratch arena。
- [ ] 定义 KV cache layout。
- [ ] 实现 bounds/shape 检查。

验收标准：

- 能按 tensor 名称加载 embedding/norm/head 等权重 view。
- scratch buffer 可复用，无 per-token 大量分配。

## Phase 4: reference kernels

- [ ] F32 vector ops。
- [ ] F16 load/convert。
- [ ] RMSNorm。
- [ ] RoPE。
- [ ] Softmax。
- [ ] Dense matvec。
- [ ] Q8 dot。
- [ ] Q4_K reference dot。
- [ ] SwiGLU/SiLU。

验收标准：

- 每个 kernel 有小尺寸 golden test。
- scalar reference 输出稳定。

## Phase 5: Transformer forward

- [ ] 建立模型超参结构。
- [ ] 绑定每层 tensor。
- [ ] 实现 single-token forward。
- [ ] 实现 prompt prefill 的逐 token 路径。
- [ ] 实现 logits 输出。

验收标准：

- 小模型或测试夹具能跑出 logits。
- 单层/全层输出可与参考实现对照。

## Phase 6: sampler 和 CLI generation

- [ ] greedy sampler。
- [ ] temperature。
- [ ] top-k。
- [ ] top-p。
- [ ] repeat penalty。
- [ ] `generate` 子命令。
- [ ] `chat` 子命令。

验收标准：

- 给定 seed 和参数时输出可复现。
- 低配路径至少支持 greedy generation。

## Phase 7: CPU 优化

- [ ] 为 Q8/Q4 dot 合并 dequant + dot。
- [ ] 为 AVX2/F16C 机器增加 Uya SIMD 快路径。
- [ ] 优化 KV cache 访问局部性。
- [ ] 优化 MoE expert dispatch。
- [ ] 增加 tokens/s benchmark。

验收标准：

- 优化版与 reference 误差在阈值内。
- benchmark 能报告 prompt/decode tokens/s。
