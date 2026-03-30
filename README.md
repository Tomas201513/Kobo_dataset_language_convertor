# KoBoToolbox Dataset Language Converter

A Shiny web application that converts a KoBoToolbox dataset from one language
to another by using the label columns defined in the XLS form.

---

## Features

- Upload a **KoBoToolbox XLS / XLSX form** (must contain a `survey` sheet and
  optionally a `choices` sheet).
- Upload the **exported dataset** in **CSV or XLSX** format.
- Automatically detects all languages present in the form (columns named
  `label::English`, `label::French`, `label::Arabic`, etc.).
- Select the **target language** – the app will:
  - Rename each column header from the internal variable name to the
    human-readable label in the target language.
  - Translate choice values (e.g. `male` → `Male` / `Masculin` / `ذكر`)
    for every `select_one` and `select_multiple` question.
- Preview the **original** and **converted** datasets side-by-side.
- Inspect the **survey** and **choices** sheets from the uploaded form.
- **Download** the converted dataset as an XLSX file.

---

## Prerequisites

Install R (≥ 4.1) and the following packages:

```r
install.packages(c("shiny", "readxl", "dplyr", "DT", "writexl", "stringr"))
```

---

## Running the app

```r
# From the repository root
shiny::runApp("app.R")
```

Or open `app.R` in RStudio and click **Run App**.

---

## Sample data

The `sample_data/` folder contains:

| File | Description |
|------|-------------|
| `kobo_form_sample.xlsx` | Sample KoBoToolbox form with English, French, and Arabic labels |
| `kobo_dataset_sample.csv` | Matching dataset exported from KoBoToolbox |

Upload these two files in the app to try a conversion right away.

---

## How it works

### KoBoToolbox form structure

KoBoToolbox forms are Excel files with (at minimum) a **`survey`** sheet:

| type | name | label::English | label::French | … |
|------|------|----------------|---------------|---|
| text | respondent_name | Respondent Name | Nom du répondant | … |
| select_one gender | gender | Gender | Genre | … |

And a **`choices`** sheet for categorical variables:

| list_name | name | label::English | label::French | … |
|-----------|------|----------------|---------------|---|
| gender | male | Male | Masculin | … |
| gender | female | Female | Féminin | … |

### Conversion logic

1. The app reads the `survey` sheet and builds a mapping:
   `variable name → label in target language`.
2. For every `select_one` / `select_multiple` column the app reads the
   `choices` sheet and builds a mapping:
   `choice name → choice label in target language`.
3. Cell values in choice columns are translated first; then column headers are
   renamed.
4. Columns whose names are not found in the form are left unchanged.

---

## Repository structure

```
.
├── app.R                          # Shiny application
├── README.md
└── sample_data/
    ├── kobo_form_sample.xlsx      # Sample KoBoToolbox XLS form
    ├── kobo_dataset_sample.csv    # Sample dataset (CSV)
    └── create_sample_files.R      # Script to regenerate the sample files
```
