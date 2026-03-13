# EIS Automatic Analysis Workflow for Battery Systems

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
Battery Materials Research

---

# Future Improvements

Planned upgrades:

- automatic arc detection
- automatic Warburg identification
- Kramers-Kronig validation
- uncertainty estimation
- GUI interface








