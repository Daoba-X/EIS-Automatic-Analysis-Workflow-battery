# EIS Automatic Analysis Workflow for Battery Systems
电池体系 EIS 自动分析工作流（基于MATLAB，中文版见底部）

MATLAB-based automated workflow for **Electrochemical Impedance Spectroscopy (EIS)** analysis in battery research.

This project provides a semi-automated pipeline to process raw EIS data, perform equivalent circuit fitting, compare candidate models, and generate publication-ready plots and parameter outputs.

The workflow is designed to reduce manual work typically performed in tools like **ZView**.

---

# Features

The workflow automatically performs:

- Raw EIS data import (`.txt` / `.csv`)
- Automatic equivalent circuit fitting
- Candidate model comparison
- Model selection based on statistical criteria
- Nyquist plot overlay (experimental vs fitted)
- Bode plot
- Residual analysis
- Automatic parameter extraction

Key parameters extracted:

- Rs (solution resistance)
- Rsei / R1 (interfacial resistance)
- Rct / R2 (charge transfer resistance)
- total resistance
- model statistics

---

# Candidate Equivalent Circuit Models

The current version includes common battery EIS models:

1. Rs + (R1 || Q1)
2. Rs + (R1 || Q1) + (R2 || Q2)
3. Rs + (R1 || Q1) + Warburg
4. Rs + (R1 || Q1) + (R2 || Q2) + Warburg

Model ranking is performed using:

- SSE
- Variance
- RMSE
- AIC
- BIC

The best model is selected based primarily on **BIC**.

---

# Output Files

For each EIS dataset the workflow generates:
result/
├── candidate_models_ranking.csv
├── best_model_parameters.csv
├── summary_all_files.csv
├── Nyquist_raw_vs_fit.png
├── Bode_raw_vs_fit.png
├── Residuals.png
└── nyquist_fit_overlay_data.csv


These outputs allow both **automated evaluation** and **manual validation** of the fitting quality.

---

# Requirements

MATLAB (recommended R2019 or newer)

Required toolbox:
Optimization Toolbox

# Limitations

This workflow performs **model selection within a predefined candidate set**.

Therefore:

- the selected model is the **best statistical model among candidates**
- physical interpretation still requires expert judgment.

Always inspect:

- Nyquist overlay
- residual plot
- parameter plausibility

---

# Citation

If this tool is useful for your research, please cite the repository:
EIS Automatic Analysis Workflow for Battery Systems
https://github.com/Daoba-X/EIS-Automatic-Analysis-Workflow-battery


---

# License

MIT License

---

# Author
Daoba-X

---

# Future Improvements

Planned upgrades:

- automatic arc detection
- automatic Warburg identification
- Kramers-Kronig validation
- uncertainty estimation
- GUI interface


本项目提供一个基于 MATLAB 的自动化工作流程，用于电池研究中的 电化学阻抗谱（Electrochemical Impedance Spectroscopy, EIS） 数据分析。

该项目提供一个 半自动化的数据分析流程，能够对原始 EIS 数据进行处理、执行等效电路拟合、比较候选模型，并自动生成可用于科研论文的图像和参数输出结果。

该工作流程旨在减少通常需要在 ZView 等软件中手动完成的分析工作，从而提高 EIS 数据分析的效率与可重复性。

功能特点

该工作流程可以自动完成以下任务：

导入原始 EIS 数据（.txt / .csv）

自动进行等效电路拟合

候选模型比较

基于统计指标进行模型选择

Nyquist 图对比（实验数据与拟合结果叠加）

Bode 图生成

残差分析

自动提取电路参数

主要提取的参数包括：

Rs（溶液电阻，solution resistance）

Rsei / R1（界面电阻，interfacial resistance）

Rct / R2（电荷转移电阻，charge transfer resistance）

总电阻（total resistance）

模型统计参数

候选等效电路模型

当前版本包含几种常见的电池 EIS 等效电路模型：

Rs + (R1 || Q1)

Rs + (R1 || Q1) + (R2 || Q2)

Rs + (R1 || Q1) + Warburg

Rs + (R1 || Q1) + (R2 || Q2) + Warburg

模型优选基于以下统计指标：

SSE（残差平方和）

Variance（残差方差）

RMSE（均方根误差）

AIC（Akaike 信息准则）

BIC（贝叶斯信息准则）

最终模型主要依据 BIC（Bayesian Information Criterion） 的最小值进行选择。

输出文件

对于每个 EIS 数据集，程序会生成以下输出文件：
result/
├── candidate_models_ranking.csv
├── best_model_parameters.csv
├── summary_all_files.csv
├── Nyquist_raw_vs_fit.png
├── Bode_raw_vs_fit.png
├── Residuals.png
└── nyquist_fit_overlay_data.csv

这些输出文件既可以用于 自动化评估模型拟合效果，也可以方便研究人员 人工检查拟合质量。

运行环境

需要安装：

MATLAB（推荐版本：R2019 或更新版本）

所需工具箱：

Optimization Toolbox

该工具箱用于执行非线性最小二乘拟合。

使用限制

本工作流程是在 预定义的候选等效电路集合 内进行模型选择。

因此需要注意：

所选模型是 候选模型集合中统计意义上最优的模型

对模型的 物理意义解释仍需要研究人员进行判断

在分析结果时建议同时检查：

Nyquist 图叠加效果

残差图

拟合参数是否具有合理物理意义

引用方式

如果本工具对你的研究有所帮助，请引用该项目：

EIS Automatic Analysis Workflow for Battery Systems
https://github.com/Daoba-X/EIS-Automatic-Analysis-Workflow-battery

许可证

MIT License

作者

Daoba-X
Battery Materials Research

未来计划

未来计划增加以下功能：

自动弧数量识别（arc detection）

自动识别 Warburg 扩散元件

Kramers–Kronig 一致性验证

参数不确定度估计

图形用户界面（GUI）



