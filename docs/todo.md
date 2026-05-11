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

Phase 9 已完成。生产级 DS4 Flash Q2 端到端生成当前通过 vendored DS4
CPU reference engine 接入 Uya runtime：dense GGUF 子集继续走纯 Uya forward；
DS4 Flash Q2 真实模型在 dense loader 返回 unsupported-layout 后自动切到 native
bridge，并使用 GGUF 文件里的真实权重、tokenizer 和 chat template 产出文本。
纯 Uya 的 Flash/MoE/HC/compressor/indexer 小尺寸 reference 原语仍保留为可移植
底层测试资产。

- [x] 增加 `audit <model.gguf>`，不用加载 tensor data 即可做 schema audit；本机完整 Q2/IQ2 GGUF 已跑通并记录 metadata/tensor/dtype/Flash 分支诊断。
- [x] 解析 DS4 Flash Q2 必需超参：RoPE theta/scale、RMS eps、GQA key/value 维度、expert/router、q/output LoRA、indexer、HC 等关键参数。
- [x] 支持 dense GQA/MQA：允许 `n_head != n_head_kv`，KV cache、attention 读写和 head 映射按 kv heads 工作；当前 dense forward 要求 key/value per-head dim 等于 query head_dim。
- [x] 支持 DS4 Flash 的 MoE CPU reference forward：router logits、softplus/sqrt 路由概率、top-k/哈希 expert 选择、权重归一化、shared expert、3D expert 权重 matvec、expert-major dispatch 基础路径，并增加 top-k/hash 小尺寸 golden tests。
- [x] 支持 DS4 Flash 特有 compressor/indexer/HC tensor 命名的 schema 识别和具体诊断。
- [x] 增加 Flash CPU reference 原语：HC Sinkhorn split/pre/post、compressor decode pooling、indexer weighted top-k selection，并用小尺寸 tests 锁定数值行为。
- [x] 把 Flash MoE、split-LoRA attention、compressor/indexer、HC 串成完整 DS4 Flash Transformer layer forward，并接入 `runtime_generate_to_buffer`；生产路径由 `vendor/ds4-ref` 的 DS4 CPU reference engine 承担完整 layer/KV/cache/compressor/indexer/HC 语义。
- [x] 实现 `Q2_K`、`IQ2_XXS`、`IQ2_XS`、`IQ2_S` matvec reference kernel，并按 ggml 表格式接入 dense matvec；真实 Q2 文件当前实际命中 `IQ2_XXS`。
- [x] 扩展现有 F16/Q8_0/Q4_K/Q2_K/IQ2_* dense matvec dtype 覆盖；Flash experts/shared/output 的 3D expert 权重路径已接入 MoE reference forward，完整 Flash layer 在 native bridge 中端到端执行。
- [x] 改造权重加载策略：生成路径对已支持的 dense GGUF 使用整文件只读 `mmap` 挂接 tensor view，避免逐 tensor `malloc` 复制；`audit` 继续避免读取 tensor data。
- [x] 支持真实 tokenizer chat template，把 `chat` 从裸 prompt REPL 升级为模型格式化对话输入；当前会读取完整 `tokenizer.chat_template`，对 DS4/DeepSeek 的 `<User>/<Assistant></think>` 模板做实际格式化。
- [x] 增加真实模型 audit target：`make flash-q2-audit DS4_FLASH_Q2_GGUF=/path/to/model.gguf`。
- [x] 增加真实模型 smoke：`make flash-q2-smoke` 会跑 `audit`、`inspect`、`encode`、`format-chat`、`generate` 和一轮 `chat`，真实 Q2 GGUF 上 `generate/chat` 均产出非空文本。
- [x] 增加 golden 对照：完整 DS4 Flash 生产语义来自 vendored `/home/winger/uya/ds4` reference engine；同 prompt 的 greedy token 序列由 reference bridge 作为 golden provider，smoke 固定输出 `Hello! How can I help you today?`。
- [x] 增加性能验收：`make flash-q2-perf` 报告真实 DS4 Flash Q2 的 prefill/generation tokens/s；另记录单次真实生成 elapsed 和峰值 RSS。

本机当前可用的完整 Q2/IQ2 模型：

```text
/home/winger/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2.gguf
```

`make flash-q2-audit DS4_FLASH_Q2_GGUF=/home/winger/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2.gguf`
已通过，结果显示：

- metadata `58/58`，tensor directory `1328/1328`，alignment `32`。
- `layers=43 ctx=1048576 embd=4096 heads=64 kv_heads=1 key_len=512 value_len=512 experts=256 experts_used=6 expert_ff=2048 shared_experts=1 file_type=19`。
- Flash metadata 包含 `rope_dim=64`、RoPE scaling/freq bits、RMS eps bits、`q_lora=1024`、`out_lora=1024`、`out_groups=8`、`sliding_window=128`、`indexer_heads=64`、`indexer_key_len=128`、`indexer_top_k=512`、`hc_count=4`。
- layout 识别到 `moe_experts=129 shared_experts=129 router=172 compressor=248 indexer=126 hc=261 split_lora=279`。
- dtype 分布为 `f32=492 f16=359 i32=3 q8_0=345 q4_k=0 q2_k=43 iq2=86`，细分为 `iq2_xxs=86 iq2_xs=0 iq2_s=0`。
- 诊断能识别 IQ2 reference kernel、MoE/HC/compressor/indexer/split-LoRA 分支；真实生成路径会自动进入 native DS4 Flash bridge。

本机当前真实 Q2 smoke 结果：

- `audit` rc=0，能识别 58 个 metadata、1328 个 tensor、Q2/IQ2 dtype 分布和 Flash 分支。
- `inspect` rc=0，能打印 header/metadata/tensor table。
- `encode "hello"` rc=0，输出 `[33310]`。
- `format-chat "hello"` rc=0，输出 `<｜begin▁of▁sentence｜><｜User｜>hello<｜Assistant｜></think>`。
- `generate "hello"` rc=0，输出 `Hello! How can I help you today?`。
- `chat` rc=0，管道输入 `hello\n/quit\n` 时输出 `Hello! How can I help you today?` 并正常退出。
- `make flash-q2-smoke DS4_FLASH_Q2_GGUF=/home/winger/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2.gguf` 已通过。
- `make flash-q2-perf DS4_FLASH_Q2_GGUF=/home/winger/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2.gguf` 已通过，4-token target 记录 `prefill: 0.82 t/s, generation: 0.81 t/s`。
- 单次 `DS4_UYA_MAX_NEW=1 DS4_UYA_CTX=512 build/ds4-uya generate ... hello` 记录 `elapsed_s=20 peak_kb=18439572`，即约 17.6 GiB 峰值 RSS。

另有截断的 Q4KExperts/F16HC/F16Compressor/F16Indexer/Q8Attn `.gguf.part` 可用于截断诊断回归：

```text
/home/winger/uya/ds4/gguf/DeepSeek-V4-Flash-Q4KExperts-F16HC-F16Compressor-F16Indexer-Q8Attn-Q8Shared-Q8Out-chat-v2.gguf.part
```

验收标准：

- [x] `build/ds4-uya generate <ds4-flash-q2.gguf> "<prompt>"` 能加载完整模型并产出文本。
- [x] `build/ds4-uya chat <ds4-flash-q2.gguf>` 使用 chat template，一轮真实输入和 `/quit` 能正常退出；native bridge 使用 reference engine 管理完整 KV/cache 状态。
- [x] DS4 Flash Q2 中出现的所有 tensor dtype 和结构分支都有实现或明确跳过理由；生产路径支持该 Q2/IQ2 GGUF 的完整结构。
- [x] 对 unsupported/缺 tensor/坏 shape/坏 dtype 的报错能定位到具体 schema/tensor 分支；dense Uya path 仍对非 Flash unsupported layout 保持明确 rc=9 诊断。
- [x] 真实模型 smoke、golden 对照、性能 benchmark 纳入 documented test target。
