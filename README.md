# CRS Aggregator for DAC Table 1b (Swiss version)

This repository contains a modular R pipeline for generating Switzerland’s reporting table **DAC1b** to the OECD, based on **CRS+ data** and a flexible **rule-based system**. The output is an Excel file that mirrors the official DAC table template and fills in all values automatically based on project data and defined classification logic.

---

## 🔧 Overview of Functionality

The pipeline:

1. Loads CRS+ project-level data and channel information.
2. Applies a rule table to allocate data to DAC1b rows and columns.
3. Applies Swiss-specific post-processing logic.
4. Exports the results to an Excel template in **local currency (e.g. CHF)** and **converted USD**.

---

## 📁 Folder Structure

```text
.
├── data/                  # Contains raw input data
│   ├── CRS_data.csv
│   ├── Channel_DAC.csv
│   └── Rules2024.xlsx
│
├── output/                # Stores generated output
│   ├── result.csv
│   └── 2024_Table_DAC1b_filled.xlsx
│
├── R/                     # Script logic organized into modules
│   ├── utils.R
│   ├── process_data.R
│   ├── apply_rules.R
│   ├── post_processing.R
│   └── fill_template.R
│
├── template/              # Excel template to fill
│   └── 2024_Table_DAC1b.xlsx
│
├── run_pipeline.R         # Main script to run the pipeline
└── README.md              # This file
```

---

## 🚀 How to Run

1. Adjust **paths and parameters** in `run_pipeline.R` (this is the *only* place where changes are needed for regular use).
2. Run `run_pipeline.R` in R or RStudio.
3. The output will be saved as:
   - `output/result.csv`: Aggregated intermediate table.
   - `output/2024_Table_DAC1b_filled.xlsx`: Final Excel file, filled in both CHF and USD.

---

## 📌 Key Files and What They Do

### `run_pipeline.R` (MAIN SCRIPT)

- Central place to configure:
  - Input file paths
  - Column name mappings
  - Placeholders
  - Output destinations
  - Exchange rate
- All relevant parameters are defined **at the top** for easy editing.

---

### `data/Rules2024.xlsx`

- Contains classification logic to map CRS data to DAC1b rows/columns.
- If reporting rules change, **this is where to adjust**.
- Sheet used: `"DAC1b_input"`
- The sheet is based on the information published by the OECD and adjusted to allow easy automation.

---

### `data/Channel_DAC.csv`

- Contains mapping between CRS `Channel_Code` and `Channel_Parent_Category`.
- Must be updated if channel classification changes.

---

### `R/post_processing.R`

- Contains neccessary processing steps such as custom summary rows (for ID 1030, 207, and 3102) as well as calculations for row ID 420 and 425
- Contains Swiss-specific logic: **Step 3: Handling MDRI (ID 2902)** is hard-coded based on Swiss methodology and likely needs to be adapted or commented out for other users.
- Place to add other country specific processing steps

---

## 🧠 How It Works

### Rule-Based Classification

The script applies rules row-by-row to the CRS data:
- Each rule contains filters on columns like "Type of flow", "Purpose code", etc.
- The script uses these to sum values into predefined DAC1b row/column cells.

### Purpose Code Splitting

- Rows with multiple purpose codes like `12240:70|14030:30` are:
  - Split into two rows.
  - Values are split proportionally across all relevant amounts.

---

## 🛠️ Customization

### To update for a new reporting year:
- Replace `CRS_data.csv` and if needed `Channel_DAC.csv` in the `data/` folder.
- Update `Rules2024.xlsx` to reflect new rules or DAC structure.
- Adjust parameters in `run_pipeline.R` (e.g., `exchange_rate`, template path).

---

## ❗ Important Notes

- This script was developed and tested using **Swiss CRS data** and Swiss reporting conventions. While it may work for other DAC members, **some logic is specific to Swiss needs**, especially in:
  - The **post-processing logic**
- Bugs or unexpected results may occur if used with unfamiliar data structures.

---

## 📚 Dependencies

You will need the following R packages:

```r
install.packages(c("dplyr", "stringr", "tidyr", "readxl", "openxlsx"))
```

---

## 📥 Output

The final Excel file (`2024_Table_DAC1b_filled.xlsx`) contains:
- Sheet 1: `DAC1b_E_1000_CHF` — amounts in 1'000 CHF
- Sheet 2: `DAC1b_E_Mio_USD` — amounts in million USD (converted)

The output is structured to match the official OECD template.

---

## 👩‍💻 Contributors

Developed by the Statistics for Development Finance Team at SDC 🇨🇭, with a focus on:
- Transparent methodology
- Maintainability
- Reusability by others

---

## 🧪 Disclaimer

This script is a **work in progress**. It was tested with Swiss CRS data and tailored to Swiss reporting logic. Other users may encounter issues when using unfamiliar formats, classifications, or rules. We welcome contributions or suggestions for improvement.
For any questions and/or comments, reach out to: stats.sdc@eda.admin.ch
---
