# ds4-uya CPU 版设计文档

## 1. 目标

`ds4-uya` 的目标是把当前 Metal-first 的 DS4 运行时重写为纯 Uya CPU
实现，使它能在用户当前 Linux x86_64 机器上运行。目标不是把旧 C/Metal
代码包一层 Uya 外壳，而是把模型文件读取、tokenizer、张量布局、量化 kernel、
Transformer 执行、KV cache、采样和 CLI 都逐步落到 Uya 代码里。

第一阶段交付一个可编译、可运行、可验证的基础项目。它先实现 GGUF inspector，
因为这是完整推理链路的入口：如果不能稳定读取模型头、metadata 和 tensor
目录，后面的 tensor mmap/加载、权重分派和 kernel 调用都会失去基准。

## 2. 当前机器约束

- OS/arch: Linux x86_64。
- CPU: Intel Xeon E5-2696 v4，支持 AVX2/F16C。
- 内存: 约 62 GiB RAM，加 62 GiB swap。
- 磁盘: `/home` 可用空间有限，当前只有约 8 GiB 级别余量。
- GPU: 无 Apple Metal；原项目的生产路径不能在这台机器上直接跑。

因此设计优先级是：

1. CPU-only，默认不依赖 GPU。
2. 支持大文件顺序读取和后续 mmap/分块读取。
3. 初期先正确，再优化；后续利用 Uya SIMD/生成 C 的 x86_64 SSE/AVX 路径做热点 kernel。
4. 不把大模型、临时展开权重或生成物放进仓库。

## 3. 原 DS4 到 ds4-uya 的边界

原 DS4 的关键事实：

- `ds4.c` 是模型/runtime 主体，但生产执行强绑定 Metal kernel。
- `metal/*.metal` 实现 bin、norm、set_rows 等 GPU kernel。
- Linux 上缺少 `ds4_metal_*` 链接目标，不能直接跑完整推理。

`ds4-uya` 的重写边界：

- 可以阅读原 DS4 的数据结构、模型流程和 kernel 语义作为参考。
- 不把 C 文件或 Metal 文件作为运行依赖。
- 每个阶段都需要有可独立验证的 Uya 实现。

## 4. 总体架构

建议模块划分如下：

- `cli`: 命令行入口，负责 `inspect`、`generate`、`chat` 等命令。
- `ds4.binary`: 小端整数、对齐、溢出检查等二进制基础设施。
- `ds4.gguf`: GGUF 文件读取、metadata 解析、tensor directory 解析。
- `ds4.tokenizer`: tokenizer metadata 读取、BPE/SentencePiece 兼容逻辑、encode/decode。
- `ds4.tensor`: CPU tensor view、shape、stride、dtype、内存所有权。
- `ds4.quant`: GGML/DS4 量化 block 解码、dot product、dequant。
- `ds4.kernels`: RMSNorm、matvec、RoPE、attention、MoE routing、activation、residual。
- `ds4.model`: 模型超参、层权重绑定、forward graph。
- `ds4.session`: KV cache、position、prompt prefill、decode step。
- `ds4.sampler`: temperature、top-k/top-p、repeat penalty、seeded RNG。
- `ds4.moe`: expert-major dispatch planning。
- `ds4.bench`: prompt/decode tokens/s microbenchmark。

第一版已落地：

- `src/main.uya`
- `src/ds4/binary.uya`
- `src/ds4/gguf.uya`
- `src/ds4/tokenizer.uya`
- `src/ds4/tensor.uya`
- `src/ds4/kernels.uya`
- `src/ds4/model.uya`
- `src/ds4/generation.uya`
- `src/ds4/sampler.uya`
- `src/ds4/moe.uya`
- `src/ds4/runtime.uya`
- `src/ds4/bench.uya`
- `src/binary_test.uya`

## 5. GGUF 加载设计

GGUF 文件分为：

1. magic/version/tensor_count/metadata_count。
2. metadata KV 区。
3. tensor info directory。
4. 对齐后的 tensor data 区。

当前 inspector 的职责：

- 检查 magic 是否为 `GGUF`。
- 读取 version、tensor_count、metadata_count。
- 安全跳过 metadata value，支持 GGUF 常见 scalar、string、array 类型。
- 打印前若干 metadata key 和 tensor name，用于确认模型结构。
- 基于文件大小和 reader position 检测 `.part` 截断。

后续 loader 会在 inspector 基础上扩展：

- 保存 metadata 中的关键超参，例如 context length、embedding size、layer count、head count。
- 保存 tokenizer metadata，交给 tokenizer 模块构建词表。
- 保存 tensor info 表：name、dtype、shape、offset、byte size。
- 支持按需读取权重，避免一次性把大模型展开进内存。

## 6. CPU tensor 与内存布局

CPU tensor 应使用轻量 view：

```text
TensorView {
    data: &byte,
    dtype: DType,
    shape: [u64; 4],
    n_dims: u32,
    stride_bytes: [u64; 4],
}
```

权重 tensor 默认只读。激活 tensor 使用 arena/scratch 分配，按层复用，避免每 token
频繁 malloc/free。KV cache 是长期状态，应单独分配并按 layer/head/token 组织。

初期采用易验证布局：

- 向量 contiguous。
- matrix 按 GGUF 原始布局建立 view，不做全局转置。
- 热点 matvec 再按 dtype 增加专门 kernel。

## 7. 量化与 kernel 策略

DS4 模型名中包含多种精度信息，例如 Q4KExperts、F16、Q8Attn 等。CPU 实现不要一开始
追求所有 kernel 最优，而要按可运行路径递进：

1. F32/F16 scalar reference kernel。
2. Q8 dot reference kernel。
3. Q4_K 等 GGML block reference kernel。
4. 针对 Xeon AVX2/F16C 的 Uya SIMD/C99 后端优化。
5. 对 MoE expert matvec 做 batch/group 优化。

每个 kernel 都需要 reference 对照：

- 小矩阵固定输入输出。
- 与旧 DS4/ggml/llama.cpp 同 dtype kernel 对照误差。
- 标量版和 SIMD 版输出误差阈值一致。

## 8. Transformer 推理链路

完整 decode step：

1. token id -> embedding row。
2. 每层执行 RMSNorm。
3. 计算 Q/K/V。
4. RoPE。
5. 写入 KV cache。
6. attention score/value。
7. residual。
8. FFN 或 MoE routing + expert。
9. final norm。
10. lm_head 输出 logits。
11. sampler 选择下一 token。

Prefill 与 decode 应共用 layer kernel，但调度不同。初期可以只做 batch=1 decode，
prefill 也逐 token 跑，先保证正确；后续再做 prompt prefill 批量化。

## 9. 验证策略

按阶段设置验收：

- GGUF: 能读取完整模型的 header、metadata、tensor directory；对 `.part` 文件能明确报截断位置。
- Tokenizer: 固定 prompt encode/decode roundtrip，特殊 token 正确。
- Tensor: shape/stride/dtype 计算正确，越界和截断检测可靠。
- Kernel: 小尺寸 golden tests；随机输入和 reference 对照。
- Model: 单层 forward 对照；完整 logits 对照；最后才做生成文本 smoke test。
- CLI: 错误路径清楚，模型路径不存在、模型截断、dtype 未支持都能给出明确返回码。

## 10. 性能路线

在当前机器上，性能瓶颈会集中在 matvec、attention 和 MoE experts：

- 先用标量 reference 建立正确性。
- 再按 dtype 实现 block dot product。
- 用 cache-friendly 的连续 scratch buffer，减少随机访问。
- 对 Q8/Q4 block 解码和 dot 合并，避免先全量 dequant 到 F32。
- Uya `@vector` F32 dot fast path 先覆盖可验证热点；后续按后端能力继续扩展到更宽 x86_64 SIMD。
- MoE routing 先产出 expert-major dispatch plan，后续 expert matvec 可直接按 expert 分组批量执行。
- `bench` CLI 报告 synthetic prompt/decode tokens/s，先用于本机回归趋势；真实模型 benchmark 后续在更多 DS4 dtype/layout 支持后再补。
- `audit` CLI 只读取 GGUF header/metadata/tensor directory，不读取 tensor data；它用于
  DS4 Flash/Q2 大模型 schema 审计，也能在 `.gguf.part` 截断文件上输出 Flash MoE、
  compressor、indexer、HC、split-LORA、dtype 分布和 unsupported 诊断。

性能目标分三档：

1. Correct: 能在小模型或截断测试上完整走通。
2. Usable: 小参数 DS4/GGUF 模型可交互生成。
3. Optimized: 大模型在 CPU 上达到可接受 tokens/s，但不承诺等价 GPU 性能。

## 11. 当前交付范围

当前已经实现到 GGUF-backed generation 阶段：

- 新建纯 Uya 项目。
- 设计文档和 TODO。
- CLI。
- GGUF loader/inspector。
- tokenizer encode/decode。
- CPU tensor dtype/view、root weight table、scratch arena、KV cache layout。
- F32/F16、RMSNorm、RoPE、Softmax、dense matvec、Q8_0/Q2_K/Q4_K/IQ2_* dot、SiLU/SwiGLU 标量 reference kernel。
- dense 小模型 forward：超参、层权重绑定、single-token、逐 token prefill、KV cache、logits 输出。
- dense GQA/MQA：KV cache 按 kv heads 存储，query heads 映射到 kv heads；当前 dense 路径要求 key/value per-head dim 与 query head_dim 一致。
- greedy、temperature、top-k、top-p、repeat penalty 采样。
- 基于 in-memory model fixture 的 greedy generation loop，把 prefill、forward、sampler 串起来。
- Uya `@vector` F32 dot、fused Q8_0/Q4_K dequant-dot fast path，并保留 reference 对照。
- KV cache row-pointer 访问，attention/store 路径减少逐元素 offset 计算。
- MoE expert-major dispatch plan。
- `bench` CLI，可报告 prompt/decode tokens/s。
- GGUF tensor data 通过只读 `mmap` 挂到 `TensorView.data`，并绑定进 forward。
- `generate`/`chat` CLI 走真实 GGUF 权重的 encode -> prefill -> sample -> decode 链路。
- binary/GGUF/tokenizer/tensor/kernel/model/sampler/optimization/runtime 测试。

当前 GGUF-backed generation 覆盖 dense decoder 子集：`blk.N.*` tensor 命名、
dense GQA/MQA、F32/F16 norm 与矩阵、Q8_0/Q2_K/Q4_K/IQ2_* matvec。完整 DS4
Flash MoE/compressor/indexer/HC/split-LORA 生产布局仍需要继续扩展，但会明确返回
unsupported-layout 诊断，不再假装生成。
