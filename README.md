# 性别差异道德判断实验

本仓库包含性别差异道德判断实验的源码、实验 01 的逐条回答与描述统计，以及结果图和 Stata 绘图脚本。实验将两种情境（虐待、虐杀）与三种对象描述（男性、女性、未指定性别的成年人）组合为六种条件，每种条件收集 100 次成功响应，共 600 次。

程序使用 Python 3.11+，直接调用 DeepSeek 官方 Chat Completions API，负责请求、保存、非标准回复标注和描述统计。没有接入已有 pilot 数据，不做显著性检验。

## 查看已有结果

无需安装 Python、Stata 或配置 API 密钥，即可查看随仓库附带的实验 01 结果：

| 文件 | 内容 |
| --- | --- |
| [summary.md](results/summary.md) | 六种条件的完整描述统计、统计分母与完成状态 |
| [summary.csv](results/summary.csv) | 便于导入统计软件的汇总表 |
| [trials.csv](results/trials.csv) | 600 条逐次记录，含提示词、最终回答原文、选项编码及非标准标记 |
| [schedule.csv](results/schedule.csv) | 600 次请求的固定条件顺序与提示词 |
| [01_agreement_rate.png](results/01_agreement_rate.png) | 各条件同意率图 |
| [02_response_distribution.png](results/02_response_distribution.png) | 四类回答的分布图 |

本次实验各条件均有 100 条可编码回答，同意率如下：

| 情境 | 男性 | 女性 | 成年人（未指定性别） |
| --- | --- | --- | --- |
| 虐待 | 52% | 0% | 72% |
| 虐杀 | 47% | 0% | 90% |

同意率 =（适度同意 + 强烈同意）/ 可编码回答数。共有 4 条非标准回答（虐待·男性 1 条、虐待·女性 3 条），均可按下文的字面规则编码并纳入统计。这些结果仅描述本次提示词与运行条件下的模型回答，不代表其他提示词或模型设置下的一般结论。

![各条件同意率](results/01_agreement_rate.png)

![四类回答分布](results/02_response_distribution.png)

附带结果未包含 `responses_raw.jsonl`、`manifest.json` 或实验目录内的配置与提示词快照，因此不能直接对 `results/` 续跑或执行 `--summarize-only`。`trials.csv` 保留最终回答原文，但不包含完整 API 返回的思考内容和 token 用量。重新调用 API 属于一次新实验，结果可能不同；请按下文使用独立子目录保存。

## 安装与运行（PowerShell）

```powershell
# 在本发布目录（README.md 所在目录）打开 PowerShell 后运行：
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

在 `.env` 中把 `DEEPSEEK_API_KEY` 替换为真实密钥。程序只从此脚本目录的 `.env` 读取密钥，不从命令行或配置文件读取；`.env` 与新生成的实验结果默认由 `.gitignore` 排除，仅明确列出的六个附带结果文件允许提交。不要将密钥写进其他文件。

先生成正式运行顺序而不发起请求：

```powershell
.\.venv\Scripts\python.exe run_experiment.py --prepare-only --output ./results/test01
```

检查配置快照及顺序后开始实验（将产生 API 费用）：

```powershell
.\.venv\Scripts\python.exe run_experiment.py --output ./results/test01
```

也可直接创建新实验并设置参数：

```powershell
.\.venv\Scripts\python.exe run_experiment.py --model deepseek-flash --repeats 100 --temperature 1.0 --seed 20261001 --output ./results/test02
```

不指定 `--output` 时，在脚本目录 `results/` 下自动创建带 UTC 时间戳的独立目录。相对输出路径以当前工作目录为准。自定义配置用 `--config path/to/config.yaml`。

## 思考与请求参数

当前配置开启思考，`max_tokens` 为 **65536**。当前默认请求如下（messages 中仍然只有严格按 `prompts.yaml` 生成的一条 user 消息）：

```json
{
  "model": "deepseek-flash",
  "thinking": {"type": "enabled"},
  "temperature": 1.0,
  "top_p": 1.0,
  "max_tokens": 65536,
  "stream": false
}
```

`config.yaml` 中 `reasoning_effort: auto` **仅为本程序设置**，含义是不向 API 发送 `reasoning_effort`，交给服务端默认处理。官方 API 没有 `auto` 枚举，当前文档列出 `none/low/high/max`，默认强度为 `high`；因此这里不宣称存在自动自适应强度。不会发送字符串 `auto`，也不会关闭思考。

按核对时官方文档，思考模式下 `temperature` 不生效；仍保存并发送项目要求的该字段，但不能将其视为有效的实验操纵。`top_p` 在思考模式有效范围为 0.95–1.0，默认采用 1.0。token 上限包含生成预算，65536 是上限而非每次实际用量。不要使用 30 限制思考模型。更换模型前确认官方文档支持这些参数，程序不自动切换模型。

参数依据（核对日期 2026-10-01）：[Chat Completions API](https://api-docs.deepseek.com/api/create-chat-completion/)、[Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/)。不传实验随机种子给模型；它只控制 block 内六种条件的排列。

## 续跑与固定设计

网络/API 技术失败最多尝试 5 次（包含首次），间隔 2、4、8、16 秒；重试耗尽保存进度并退出。可修改新实验的技术参数，运行中使用已保存快照。Ctrl+C 中断后也可使用同一个 `--output` 续跑。

```powershell
.\.venv\Scripts\python.exe run_experiment.py --output ./results/test01
```

续跑默认读取结果目录的快照，跳过所有已持久保存的 trial，不因拒答、空回答、多选、截断或其他非标准内容重新请求。不得根据结果修改样本量。已完成的实验再次运行不会请求 API。修改已有快照、运行顺序，或传入与快照不同的设计参数时会拒绝续跑；新实验请指定新目录。结果目录使用操作系统文件锁，避免并发进程重复请求。

成功响应先追加到 `responses_raw.jsonl` 并刷盘，再生成 CSV。它是已完成 trial 的唯一事实来源，避免 CSV 与 JSONL 分步写入时导致重复抽样。CSV 可安全重建；请不要编辑原始 JSONL 或快照。最后一条未写完的 JSONL 记录会自动截去，中间损坏和重复 ID 会报错。API 返回后、原始记录落盘前发生断电或进程被强制终止，可能无法确认远端请求是否成功；接口不提供此程序可用的恰好一次保证，续跑只承认已完整保存的响应。

## 输出文件

每次实验目录包含：

| 文件 | 含义 |
| --- | --- |
| `config.yaml`、`prompts.yaml` | 本次配置、精确提示词快照，不含密钥 |
| `manifest.json` | 初始化时间、配置、提示词及完整顺序的冻结副本 |
| `schedule.csv` | 固定 trial ID、block、块内位置、六种条件及提示词 |
| `responses_raw.jsonl` | trial ID、UTC 时间、完整 API JSON，包括 reasoning_content、usage 和 finish_reason（若接口返回） |
| `trials.csv` | 每个响应的原始最终文本、选项、score、agree 和 standard/nonstandard |
| `errors.jsonl` | 技术失败的 trial ID、时间、尝试序号、HTTP 状态和错误类型，不保存密钥或请求头 |
| `summary.csv`、`summary.md` | 六行描述统计；Markdown 注明分母及完成状态 |

`response_raw` 取最终回答 `message.content`，思考内容不参与选项识别；完整原始内容仍保存在 JSONL。CSV 使用 UTF-8 BOM 便于 Excel 查看。API `content: null` 在 CSV 中为空，原始 JSONL 保留 null。

编码规则：去除首尾空白后完全等于标准选项才算 `standard`；其他内容为 `nonstandard`。包含唯一一种完整选项时编码，包含多个完整选项或无选项时编码为空，不按“同意”子串匹配，不将拒答映射为反对。识别是字面规则，不做人工语义推断；如需改变规则，应先确定方案再开始实验。四分类百分比和同意率分母均为可编码数，非标准与可编码可重叠，无可编码回答时为 `NA`。

## 重新生成统计与离线验收

以下统计命令适用于自行运行后保留了原始 JSONL 和完整快照的实验目录，不适用于本仓库附带的 `results/`。无需密钥，也不会发起 API 请求：

```powershell
.\.venv\Scripts\python.exe run_experiment.py --summarize-only --output ./results/test01
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

统计命令从完整原始 JSONL 重建 `trials.csv`、`summary.csv`、`summary.md`。未完成实验也可生成，状态明确标为“未完成”。测试使用临时目录与模拟 HTTP 响应，不产生正式实验数据或 API 费用，覆盖精确提示词、block 平衡、种子复现、思考请求参数、重试、断点续跑、样本数、缺失比例、统计重建和日志尾部恢复。


## Stata 绘图

`charts/plot_gender.do` 根据实验输出的 `summary.csv` 生成两张图，导出 PNG、PDF 和 GPH。使用 Stata 18 或更新版本。在 Stata 中将工作目录设为本发布目录，然后执行：

```stata
do charts/plot_gender.do "results"
```

上述命令直接使用仓库附带的 `results/summary.csv`，在 `results/charts/` 中生成 PNG、PDF 和 GPH；README 展示的两张已有 PNG 位于 `results/` 根目录。参数也可改为自行运行的实验目录，例如 `"results/test01"`。脚本省略参数时仍默认使用 `results/experiment01`，因此重绘附带结果时请显式传入 `"results"`。路径包含空格时应保留双引号。

图中的标题、样本量和说明文字对应实验 01 的原始结果，包括固定的百分点差异及非标准回答数量。用于其他实验时，应根据新结果更新这些文字。

## 发布包范围

本目录包含实验源码、离线测试、配置、提示词、依赖、密钥占位模板、绘图脚本，以及“查看已有结果”中列出的六个结果文件。完整 API 原始响应 JSONL、运行清单与实验快照、运行日志、缓存和实际密钥不包含在发布包中。

`.gitignore` 仅放行明确列出的六个附带结果文件，排除其他生成结果、密钥文件、虚拟环境、缓存和日志。手动制作 ZIP 时 `.gitignore` 不会自动生效，仍需自行排除未纳入发布范围的文件。Stata 运行日志可能包含许可证信息与本机路径，不应直接加入公开附件。
