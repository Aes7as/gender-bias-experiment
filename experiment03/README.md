# experiment03

英文七档量表；对应报告表4。

来源：`experiment_english/experiment03/results/experiment03`。发布目录编号不改写历史数据中的原始运行标识。每次提问是独立 API 调用，无对话上下文；本批600条记录。

## 已有结果

- [描述统计](results/summary.md)
- [汇总CSV](results/summary.csv)
- [逐条回答](results/trials.csv)
- [请求顺序和提示词](results/schedule.csv)
- [01_agreement_rate.png](results/01_agreement_rate.png)
- [02_response_distribution.png](results/02_response_distribution.png)
- [03_mean_score.png](results/03_mean_score.png)

本发布包沿用首次发布范围：逐条最终回答和汇总数据，不含完整 API 响应、思考内容、token 用量、manifest 或请求原始日志。不能对附带 results 目录续跑或执行 --summarize-only。config.yaml 与 prompts.yaml 复制自该次运行的配置快照。

## 新运行

在本目录打开终端，安装 requirements.txt 中的依赖，将 .env.example 复制为 .env 并填入自己的密钥。使用独立目录：

```powershell
python run_experiment.py --prepare-only --output ./results/new_run
python run_experiment.py --output ./results/new_run
```

第二条命令会调用 API 并产生费用；新运行不保证复现完全相同的随机回答。

## 绘图

在本目录作为工作目录的 Stata 中执行：

```stata
do charts/plot_gender.do results
```

脚本读取 results/summary.csv 并在 results 中输出图表；不调用 API。本机使用 StataNow/SE 18.5。
