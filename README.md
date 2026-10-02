# LLM 与执剑人：实验代码与数据

本仓库收录 Report《LLM与执剑人》对应的实验代码、提示词、逐条回答与汇总图表，用于查阅实验设置、核对记录，以及重新运行实验。实验结果、讨论与局限集中在 Report 中，本 README 主要说明仓库结构和使用方法。

**完整报告：[report_single.html](report_single.html)。** 图片已嵌入 HTML，下载该文件后用浏览器打开即可离线阅读，不需要额外下载图片。GitHub 文件页面可能只显示源码，可通过下载原始文件后打开来阅读。

## 目录导航

| 目录 | 实验设置 | Report 对应 |
| --- | --- | --- |
| [experiment01](experiment01/) | 中文四档量表，无系统提示词；首次运行 | 表 1 |
| [experiment01-2](experiment01-2/) | 与 experiment01 相同设置的独立重复运行 | 表 2 |
| [experiment02](experiment02/) | 中文四档量表，加入系统提示词 | 表 3 |
| [experiment03](experiment03/) | 英文七档量表，无系统提示词 | 表 4 |
| [experiment04](experiment04/) | 英文七档量表，加入系统提示词 | 表 5 |
| [experiment05](experiment05/) | 英文七档量表，在用户提示词中加入客观、真实、理性及无预设性别偏好的要求；无系统提示词 | 表 6 |

`experiment01-2` 是第一次实验的重复运行，不是 `experiment02`。发布目录编号与部分历史运行标识不同，数据中的历史标识予以保留。

各实验目录可以分别运行，基本结构相同：

| 文件或目录 | 内容 |
| --- | --- |
| `README.md` | 该实验的说明、数据入口与运行方法 |
| `run_experiment.py` | 实验主程序：配置校验、请求调度、API 调用、回答编码与汇总 |
| `config.yaml` | 模型接口、请求参数、重复次数、顺序随机种子与重试设置 |
| `prompts.yaml` | 提示词模板、实验条件与回答选项 |
| `requirements.txt` | Python 依赖及版本范围 |
| `.env.example` | API 密钥配置模板，发布版本不含密钥 |
| `.gitignore` | 本地密钥、缓存及运行产物的 Git 忽略规则 |
| `tests/` | 自动化测试，使用模拟请求检查调度、编码、重试及恢复等逻辑 |
| `charts/plot_gender.do` | 读取汇总数据并绘图的 Stata 脚本 |
| `results/schedule.csv` | 提问顺序、条件与实际问题文本 |
| `results/trials.csv` | 逐条最终回答及编码结果 |
| `results/summary.csv`、`results/summary.md` | 机器可读和便于阅读的描述统计 |
| `results/*.png` | 已生成的图表；英文实验另含平均得分图 |

[experiment05/DESIGN.md](experiment05/DESIGN.md) 另行记录了第五个实验的设计说明。

发布数据不含完整 API 响应日志、思考内容、token 用量、请求原始日志或运行 manifest。因此，这些目录适合查阅和分析已发布结果，但不能直接作为完整运行现场来恢复任务。

## 实验设计概览

实验使用极端道德两难情境，交叉改变行为与对象，观察模型对给定陈述的量表回答。每组设置包含两类行为、三类对象，共六个条件；每个条件重复 100 次。

采用分块随机顺序：每个区块包含全部六个条件，各出现一次，再在区块内随机排列，共 100 个区块。随机种子控制的是提问顺序，不是模型生成答案的随机性。

**每次提问都是独立 API 调用，不携带此前问答或对话历史。** 无系统提示词的设置只发送当前用户消息；有系统提示词的设置发送系统消息与当前用户消息。系统提示词为 `you are a helpful assistant`。

中文实验使用四档量表，英文实验使用七档量表。不同语言版本在措辞、行为词与量表上存在差异，不能把跨版本比较理解为只改变了语言。精确提示词请查看各目录的 `prompts.yaml` 和 `results/schedule.csv`。

报告中的模型名称与调用接口中的模型标识需区分：代码配置使用 `deepseek-flash`。该接口标识没有固定到不可变的模型版本；服务端更新与生成随机性都可能使重新运行的回答发生变化。

## 环境依赖

- **阅读报告和已有结果**：浏览器、文本编辑器或支持 CSV 的工具即可，无需 API 密钥。
- **运行实验程序**：建议 Python 3.11 或更新版本，依赖为 `requests`、`PyYAML`、`python-dotenv`，具体版本范围以各目录的 `requirements.txt` 为准。
- **实际调用模型**：需要可用的 DeepSeek API 密钥与网络连接，调用会产生费用。
- **重新绘图（可选）**：Stata 18 或更新版本；项目使用 StataNow/SE 18.5。Python 实验程序不依赖 Stata。

## 代码实现路径

主流程集中在各目录的 `run_experiment.py` 中：

1. **读取与校验**：加载 `config.yaml`、`prompts.yaml`，检查实验条件与提示词是否符合该版本设计。
2. **生成计划**：`make_schedule` 按配置生成分块随机顺序；`prepare` 保存计划及运行配置快照。
3. **逐条请求**：`request_trial` 为当前题目重新构造消息，通过 HTTP 调用模型。技术性失败按配置重试；不会因回答不同意、拒绝或格式不合要求而重新抽取答案。
4. **保存与恢复**：执行过程保存原始响应日志，记录已完成的试次；保留完整日志的新运行可在中断后从同一输出目录恢复。
5. **编码与汇总**：`classify` 编码最终回答，随后生成逐条 CSV 和描述统计文件；Stata 脚本再读取汇总 CSV 绘图。

中文程序检查回答是否只出现一种预设选项文本，同时单独标记是否严格符合输出格式；英文程序只将去除首尾空白后为单个 `1`—`7` 的回答编码。无法按规则编码的回答保留为缺失，不通过人工语义判断补入量表。汇总中的同意率以成功编码的回答为分母，详细规则以对应版本源码为准。

源码包含提示词一致性校验。若要修改实验设计，需要同步检查 `prompts.yaml`、代码中的校验规则与测试，不能假定只改提示词文件就能运行。

## 如何运行

以下以 `experiment03` 为例，在仓库根目录打开 PowerShell。其他实验将目录名替换为对应名称即可。

```powershell
cd experiment03
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

编辑新建的 `.env`，填入自己的密钥：

```dotenv
DEEPSEEK_API_KEY=your_api_key_here
```

`.env` 仅保留在本地，不要提交。程序从当前实验脚本所在目录的 `.env` 读取密钥。

先生成计划，检查配置和待发送的问题；这一步不调用 API：

```powershell
.\.venv\Scripts\python.exe run_experiment.py --prepare-only --output ./results/new_run
```

确认计划后，使用同一输出目录开始调用 API：

```powershell
.\.venv\Scripts\python.exe run_experiment.py --output ./results/new_run
```

请为不同的新运行使用不同目录名，保留附带的历史结果。若某次新运行中断，在配置不变且完整日志仍在的情况下，重新执行同一命令即可恢复。对完整的新运行，可以使用 `--summarize-only` 重新汇总；**不要对本仓库附带的 `results` 直接续跑或执行 `--summarize-only`**，因为发布版省略了恢复和汇总所需的原始日志。

在该实验目录下运行自动化测试，无需调用真实 API：

```powershell
.\.venv\Scripts\python.exe -B -m unittest discover -s tests -v
```

如需重新绘制已发布数据的图表，将 Stata 工作目录设为相应实验目录，再执行：

```stata
do charts/plot_gender.do results
```

绘图读取 `results/summary.csv`。`experiment01` 的脚本输出到 `results/charts/`，其余目录的脚本输出到 `results/`。绘制新运行时，将参数 `results` 换成该次运行目录，例如 `results/new_run`。

## 许可证状态与建议

**当前尚未正式指定许可证。以下是待项目作者确认的建议，不构成已经生效的授权声明。**

- **代码：建议采用 [MIT License](https://choosealicense.com/licenses/mit/)**。允许使用、修改和分发，包括商业用途，要求保留版权及许可声明，并提供免责条款。
- **Report、说明文档、原创图表及可由作者授权的数据整理成果：建议采用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.zh-hans)**。允许分享、改编及商业使用，要求适当署名、提供许可证链接，并说明修改。署名可使用作者选定的公开名称或项目名称，无需在 README 中公开真实姓名或邮箱。

模型生成内容及引用的第三方材料，其权利范围不能仅靠本仓库的许可证确定；正式授权应限于作者有权许可的部分。确认方案后，应补充许可证文件，并明确代码与非代码内容各自适用的范围。

仓库公开不等于已经授予通用的修改、再分发许可；可参考 [GitHub 关于未指定许可证的说明](https://choosealicense.com/no-permission/)。

## 作者与 AI 使用声明

本项目代码由 **GPT6-Astra** 根据项目作者的要求编写，本 README 也由 **GPT6-Astra** 编写。

**Report《LLM与执剑人》由项目作者本人撰写，非 AI 撰写。**
