library(shiny)
library(readxl)
library(dplyr)
library(DT)
library(writexl)
library(stringr)

# ---- helpers ---------------------------------------------------------------

#' Read and parse the survey and choices sheets from a KoBoToolbox XLS form.
#' Returns a list: $survey (tibble), $choices (tibble), $languages (character).
parse_kobo_form <- function(path) {
  sheets <- excel_sheets(path)

  # Survey sheet
  survey_sheet <- sheets[tolower(sheets) == "survey"][1]
  if (is.na(survey_sheet)) stop("No 'survey' sheet found in the uploaded form.")
  survey <- read_excel(path, sheet = survey_sheet)
  names(survey) <- trimws(names(survey))

  # Choices sheet
  choices_sheet <- sheets[tolower(sheets) == "choices"][1]
  choices <- if (!is.na(choices_sheet)) {
    ch <- read_excel(path, sheet = choices_sheet)
    names(ch) <- trimws(names(ch))
    ch
  } else {
    NULL
  }

  # Detect languages: columns of the form  label::Language  or  label:Language
  label_cols <- grep("^label(::?)", names(survey), value = TRUE)
  languages  <- str_match(label_cols, "^label::?(.+)$")[, 2]
  languages  <- languages[!is.na(languages)]

  list(survey = survey, choices = choices, languages = languages)
}

#' Build a name→label lookup table for a given language.
#' Handles survey rows and, for select questions, also choice rows.
build_lookups <- function(form, language) {
  lang_col <- paste0("label::", language)

  # --- survey lookup: variable name → column label ---
  survey <- form$survey
  if (!lang_col %in% names(survey)) {
    # Try single-colon fallback
    lang_col_alt <- paste0("label:", language)
    lang_col <- if (lang_col_alt %in% names(survey)) lang_col_alt else NA_character_
  }

  survey_lookup <- if (!is.na(lang_col)) {
    survey %>%
      filter(!is.na(name), !is.na(.data[[lang_col]])) %>%
      select(name, label = all_of(lang_col)) %>%
      distinct(name, .keep_all = TRUE)
  } else {
    tibble(name = character(), label = character())
  }

  # --- choices lookup: list_name + choice name → choice label ---
  choices_lookup <- NULL
  if (!is.null(form$choices)) {
    choices <- form$choices
    if (lang_col %in% names(choices)) {
      choices_lookup <- choices %>%
        filter(!is.na(name), !is.na(.data[[lang_col]])) %>%
        select(list_name, name, label = all_of(lang_col)) %>%
        distinct(list_name, name, .keep_all = TRUE)
    }
  }

  list(survey = survey_lookup, choices = choices_lookup)
}

#' Map each survey variable to its associated choice list (if any).
get_choice_lists <- function(form) {
  survey <- form$survey
  # Rows where type is select_one/select_multiple carry the list name
  choice_map <- survey %>%
    filter(str_detect(type, "^select_(one|multiple)")) %>%
    mutate(list_name = str_extract(type, "(?<=select_(one|multiple) )\\S+")) %>%
    filter(!is.na(list_name), !is.na(name)) %>%
    select(variable = name, list_name) %>%
    distinct()
  choice_map
}

#' Convert a dataset using the form lookups.
#' @param dataset  data.frame / tibble – the raw KoBoToolbox export
#' @param form     parsed form (output of parse_kobo_form)
#' @param target   target language string, e.g. "English"
#' @return converted tibble
convert_dataset <- function(dataset, form, target) {
  lookups     <- build_lookups(form, target)
  survey_lkp  <- lookups$survey      # name → label
  choices_lkp <- lookups$choices     # list_name + name → label
  choice_map  <- get_choice_lists(form)

  # 1. Translate cell values for select columns (before renaming headers)
  if (!is.null(choices_lkp) && nrow(choices_lkp) > 0 && nrow(choice_map) > 0) {
    for (i in seq_len(nrow(choice_map))) {
      var       <- choice_map$variable[i]
      list_nm   <- choice_map$list_name[i]
      if (!var %in% names(dataset)) next

      cl <- choices_lkp %>% filter(list_name == list_nm)
      if (nrow(cl) == 0) next

      lkp_vec         <- setNames(cl$label, cl$name)
      dataset[[var]]  <- recode(as.character(dataset[[var]]), !!!lkp_vec)
    }
  }

  # 2. Rename column headers
  if (nrow(survey_lkp) > 0) {
    lkp_vec  <- setNames(survey_lkp$label, survey_lkp$name)
    new_nms  <- names(dataset)
    matched  <- new_nms %in% names(lkp_vec)
    new_nms[matched] <- lkp_vec[new_nms[matched]]
    names(dataset) <- new_nms
  }

  dataset
}

# ---- UI --------------------------------------------------------------------

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { font-family: 'Segoe UI', Arial, sans-serif; background: #f5f7fa; }
      .well { background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
      h2 { color: #2b5fd9; }
      .btn-primary { background-color: #2b5fd9; border-color: #2348b0; }
      .btn-success { background-color: #1d9a6c; border-color: #157a55; }
    "))
  ),

  titlePanel(
    div(
      img(src = "https://www.kobotoolbox.org/static/img/logo.svg",
          height = "36px", style = "margin-right:10px; vertical-align:middle;",
          onerror = "this.style.display='none'"),
      "KoBoToolbox Dataset Language Converter"
    )
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,

      h4("1. Upload KoBoToolbox Form"),
      fileInput("form_file", NULL,
                accept  = c(".xlsx", ".xls"),
                placeholder = "Choose XLS/XLSX form…"),

      h4("2. Upload Dataset"),
      fileInput("data_file", NULL,
                accept  = c(".csv", ".xlsx", ".xls"),
                placeholder = "Choose CSV or XLSX dataset…"),

      hr(),

      h4("3. Language Settings"),
      uiOutput("lang_ui"),

      hr(),

      actionButton("convert_btn", "Convert", icon = icon("language"),
                   class = "btn-primary btn-block"),

      br(),

      downloadButton("download_btn", "Download Converted Dataset",
                     class = "btn-success btn-block"),

      hr(),
      helpText(
        "Upload a KoBoToolbox XLS form and its matching exported dataset.",
        "The app will rename column headers and translate choice values",
        "to the selected target language."
      )
    ),

    mainPanel(
      width = 9,

      tabsetPanel(
        tabPanel("Converted Data",
                 br(),
                 uiOutput("conversion_status"),
                 br(),
                 DTOutput("converted_table")
        ),
        tabPanel("Original Data",
                 br(),
                 DTOutput("original_table")
        ),
        tabPanel("Form — Survey",
                 br(),
                 DTOutput("survey_table")
        ),
        tabPanel("Form — Choices",
                 br(),
                 DTOutput("choices_table")
        )
      )
    )
  )
)

# ---- Server ----------------------------------------------------------------

server <- function(input, output, session) {

  # Parse the uploaded form
  form_data <- reactive({
    req(input$form_file)
    tryCatch(
      parse_kobo_form(input$form_file$datapath),
      error = function(e) {
        showNotification(paste("Error reading form:", e$message), type = "error", duration = 8)
        NULL
      }
    )
  })

  # Read the uploaded dataset
  raw_dataset <- reactive({
    req(input$data_file)
    path <- input$data_file$datapath
    ext  <- tools::file_ext(input$data_file$name)
    tryCatch({
      if (tolower(ext) == "csv") {
        read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
      } else {
        as.data.frame(read_excel(path))
      }
    }, error = function(e) {
      showNotification(paste("Error reading dataset:", e$message), type = "error", duration = 8)
      NULL
    })
  })

  # Dynamically render language selectors once the form is loaded
  output$lang_ui <- renderUI({
    fd <- form_data()
    if (is.null(fd) || length(fd$languages) == 0) {
      return(helpText("Upload a KoBoToolbox form to see available languages."))
    }
    langs <- fd$languages
    tagList(
      selectInput("target_lang", "Target Language",
                  choices  = langs,
                  selected = langs[1])
    )
  })

  # Perform conversion when button is clicked
  converted <- eventReactive(input$convert_btn, {
    fd  <- form_data()
    ds  <- raw_dataset()
    req(fd, ds, input$target_lang)
    tryCatch(
      convert_dataset(ds, fd, input$target_lang),
      error = function(e) {
        showNotification(paste("Conversion error:", e$message), type = "error", duration = 10)
        NULL
      }
    )
  })

  # Status message
  output$conversion_status <- renderUI({
    cv <- converted()
    if (is.null(cv)) return(NULL)
    div(
      class = "alert alert-success",
      icon("check-circle"),
      sprintf(" Converted successfully — %d rows × %d columns.", nrow(cv), ncol(cv))
    )
  })

  # Table outputs
  dt_opts <- list(scrollX = TRUE, pageLength = 15, autoWidth = TRUE)

  output$converted_table <- renderDT({
    req(converted())
    datatable(converted(), options = dt_opts, rownames = FALSE)
  })

  output$original_table <- renderDT({
    req(raw_dataset())
    datatable(raw_dataset(), options = dt_opts, rownames = FALSE)
  })

  output$survey_table <- renderDT({
    req(form_data())
    datatable(form_data()$survey, options = dt_opts, rownames = FALSE)
  })

  output$choices_table <- renderDT({
    fd <- form_data()
    req(fd)
    if (is.null(fd$choices)) return(datatable(data.frame(Message = "No choices sheet found.")))
    datatable(fd$choices, options = dt_opts, rownames = FALSE)
  })

  # Download handler
  output$download_btn <- downloadHandler(
    filename = function() {
      paste0("converted_dataset_", Sys.Date(), ".xlsx")
    },
    content = function(file) {
      cv <- converted()
      req(cv)
      write_xlsx(cv, file)
    }
  )
}

# ---- Run -------------------------------------------------------------------

shinyApp(ui, server)
