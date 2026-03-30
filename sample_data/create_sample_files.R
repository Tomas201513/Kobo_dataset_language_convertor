## Run this script once to generate the sample XLS form and CSV dataset.
## Requires: writexl, readr

library(writexl)
library(readr)

# ---- KoBoToolbox XLS form --------------------------------------------------

survey <- data.frame(
  type    = c("text", "integer", "select_one gender", "select_one yn",
              "select_one region", "note"),
  name    = c("respondent_name", "age", "gender", "owns_phone",
              "region", "end_note"),
  `label::English`  = c("Respondent Name", "Age", "Gender",
                         "Does the respondent own a phone?",
                         "Region", "End of survey"),
  `label::French`   = c("Nom du répondant", "Âge", "Genre",
                         "Le répondant possède-t-il un téléphone?",
                         "Région", "Fin du questionnaire"),
  `label::Arabic`   = c("اسم المستجيب", "العمر", "الجنس",
                         "هل يمتلك المستجيب هاتفاً؟",
                         "المنطقة", "نهاية الاستطلاع"),
  required = c("yes", "yes", "yes", "yes", "no", NA),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

choices <- data.frame(
  list_name = c("gender", "gender", "yn", "yn",
                "region", "region", "region"),
  name      = c("male", "female", "yes", "no",
                "north", "south", "east"),
  `label::English` = c("Male", "Female", "Yes", "No",
                        "North", "South", "East"),
  `label::French`  = c("Masculin", "Féminin", "Oui", "Non",
                        "Nord", "Sud", "Est"),
  `label::Arabic`  = c("ذكر", "أنثى", "نعم", "لا",
                        "شمال", "جنوب", "شرق"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write_xlsx(
  list(survey = survey, choices = choices),
  path = "sample_data/kobo_form_sample.xlsx"
)
cat("Wrote sample_data/kobo_form_sample.xlsx\n")

# ---- Sample dataset (as exported by KoBoToolbox) ---------------------------

dataset <- data.frame(
  `_id`            = 1:6,
  respondent_name  = c("Alice", "Bob", "Chloé", "David", "Eve", "Frank"),
  age              = c(28, 35, 22, 45, 31, 40),
  gender           = c("female", "male", "female", "male", "female", "male"),
  owns_phone       = c("yes", "no", "yes", "yes", "no", "yes"),
  region           = c("north", "south", "east", "north", "south", "east"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write_csv(dataset, "sample_data/kobo_dataset_sample.csv")
cat("Wrote sample_data/kobo_dataset_sample.csv\n")
