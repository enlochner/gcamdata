# A utility script to find all the data system R scripts in a directory
# tree, parse them one by one, and fill in a template form to generate
# one chunk per script. We write these to files in the outputs/ dir

library(tibble)

PATTERNFILE <- "chunk-generator/sample-pattern.R"

DOMAIN_MAP <- c("AGLU" = "aglu/",
                "ENERGY" = "energy/",
                "EMISSIONS" = "emissions/",
                "SOCIO" = "socioeconomics/",
                "GCAMUSA" = "gcam-usa/",
                "WATER" = "water/")

XMLBATCH_LIST <- list()

stopifnot(length(list.files("chunk-generator/outputs/", pattern = "*.R")) == 0)

# Workhorse function to read, parse, construct new strings/code, and substitute
make_substitutions <- function(fn, patternfile = PATTERNFILE) {
  pattern <- readLines(patternfile)

  print(basename(fn))
  filecode <- readLines(fn, warn = FALSE)

  # Isolate the module and level information from the filename
  fn <- gsub("//", "/", fn, fixed = TRUE)
  x <- strsplit(fn, "/")[[1]]
  level <- x[length(x) - 1]
  module <- gsub("-processing-code", "", x[length(x) - 2], fixed = TRUE)

  # Replace file info
  pattern <- gsub(pattern = "ORIGINALFILE_PATTERN",
                  replacement = basename(fn),
                  pattern,
                  fixed = TRUE)
  pattern <- gsub(pattern = "MODULE_PATTERN",
                  replacement = module,
                  pattern,
                  fixed = TRUE)
  pattern <- gsub(pattern = "LEVEL_PATTERN",
                  replacement = level,
                  pattern,
                  fixed = TRUE)

  # Warnings (advice to coders)
  warnstring <- "#"
  if(any(grepl("merge", filecode))) {
    warnstring <- c(warnstring, "# NOTE: there are `merge` calls in this code. Be careful!",
                    "# For more information, see https://github.com/JGCRI/gcamdata/wiki/Name-That-Function")
  }
  if(any(grepl("(merge|match)", filecode))) {
    warnstring <- c(warnstring, "# NOTE: there are 'match' calls in this code. You probably want to use left_join_error_no_match",
                    "# For more information, see https://github.com/JGCRI/gcamdata/wiki/Name-That-Function")
  }
  if(any(grepl("translate_to_full_table", filecode))) {
    warnstring <- c(warnstring, "# NOTE: This code uses translate_to_full_table",
                    "# This function can be removed; see https://github.com/JGCRI/gcamdata/wiki/Name-That-Function")
  }
  if(any(grepl("vecpaste", filecode))) {
    warnstring <- c(warnstring, "# NOTE: This code uses vecpaste",
                    "# This function can be removed; see https://github.com/JGCRI/gcamdata/wiki/Name-That-Function")
  }
  if(any(grepl("repeat_and_add_vector", filecode))) {
    warnstring <- c(warnstring, "# NOTE: This code uses repeat_and_add_vector",
                    "# This function can be removed; see https://github.com/JGCRI/gcamdata/wiki/Name-That-Function")
  }
  if(any(grepl("conv_[0-9]{4}_[0-4]{4}_USD", filecode))) {
    warnstring <- c(warnstring, "# NOTE: This code converts gdp using a conv_xxxx_xxxx_USD constant",
                    "# Use the `gdp_deflator(year, base_year)` function instead")
  }
  pattern <- gsub("WARNING_PATTERN", paste(warnstring, collapse = "\n"), pattern, fixed = TRUE)

  # Replace CHUNK_NAME with file name (minus .R)
  # Use make.names to ensure syntactically valid
  chunkname <- make.names(paste("module", module, gsub("\\.R$", "", basename(fn)), sep = "_"))
  pattern <- gsub(pattern = "CHUNK_NAME", replacement = chunkname, pattern, fixed = TRUE)

  # General function to pull info out of code function calls
  extract_argument <- function(pattern, filecode, stringpos = 2) {
    newinputstring <- ""
    filecode <- filecode[grep("^(\\s)*#", filecode, invert = TRUE)]  # remove comments
    inputlines <- grep(pattern, filecode, fixed = TRUE)
    newinputs <- NULL
    if(length(inputlines)) {
      for(il in inputlines) {
        xsplit <- strsplit(filecode[il], ",")[[1]]
        x <- xsplit[stringpos]
        x <- gsub(pattern, "", x, fixed = TRUE)
        x <- gsub("\"", "", x)
        x <- gsub(")", "", x)
        x <- gsub("IDstring=", "", x)
        x <- gsub("batch_XML_file=", "", x)
        x <- trimws(x)

        if(grepl("COMMON_MAPPINGS", filecode[il])) {
          domain <- "common/"
        } else if (grepl("LEVEL1_DATA", filecode[il])) {
          domain <- ""
        } else if (grepl("(MAPPINGS|ASSUMPTIONS|LEVEL0)", filecode[il])) {
          # Chunks might load mapping/assumption data from their own domain (module),
          # or from somewhere else. Find and parse the string to figure it out
          domaininfo <- regexpr("[A-Z]*_(MAPPINGS|ASSUMPTIONS|LEVEL0)", filecode[il])
          domain <- substr(filecode[il], domaininfo, domaininfo + attr(domaininfo, "match.length") - 1)
          domain <- strsplit(domain, "_")[[1]][1]
          domain <- DOMAIN_MAP[domain]
        } else {
          domain <- ""
        }
        newinputs <- c(newinputs, paste0(domain, x))
      }
    }
    newinputs
  }


  # Find readdata lines
  readdata_string <- extract_argument("readdata(", filecode)
  no_inputs <- is.null(readdata_string)
  if(no_inputs) {
    warning("No inputs for ", basename(fn))
    replacement <- "NULL"
  } else {
    readdata_string_q <- paste0("\"", readdata_string, "\"")
    fileinputs <- grep("/", readdata_string, fixed = TRUE)
    fileprefix <- rep("", length(readdata_string))
    fileprefix[fileinputs] <- "FILE ="
    replacement <- paste0("c(", paste(paste(fileprefix, readdata_string_q), collapse = ",\n"), ")")
  }

  # Replace INPUTS_PATTERN, marking "FILE =" as necessary
  pattern <- gsub(pattern = "INPUTS_PATTERN",
                  replacement = replacement,
                  pattern,
                  fixed = TRUE)

  # Replace LOAD_PATTERN
  if(no_inputs) {
    load_string <- ""
  } else {
    load_string <- paste0("  ", basename(readdata_string), " <- get_data(all_data, ", readdata_string_q, ")")
  }

  pattern <- gsub(pattern = "LOAD_PATTERN",
                  replacement = paste(load_string, collapse = "\n"),
                  pattern,
                  fixed = TRUE)

  # Find output lines
  writedata_string <- extract_argument("writedata(", filecode, stringpos = 1)
  midata_arr <- extract_argument("write_mi_data(", filecode, stringpos = c(1, 2, 6))
  batchxml_arr <- extract_argument("insert_file_into_batchxml(", filecode, stringpos = c(2, 3, 4))
  node_rename_arr <- extract_argument("write_mi_data(", filecode, stringpos = c(6, 7))

  midata_string <- c()
  i <- 1
  while(i < length(midata_arr)) {
    midata <- midata_arr[i]
    miheader <- midata_arr[i+1]
    mibatch <- midata_arr[i+2]
    mibatch <- sub('.xml$', '_xml', mibatch)
    i <- i + 3
    if(is.null(XMLBATCH_LIST[[mibatch]])) {
      XMLBATCH_LIST[[mibatch]] <<- list(data=c(), header=c(), xml="", module="", node_rename=F)
    }
    XMLBATCH_LIST[[mibatch]]$data <<- c(XMLBATCH_LIST[[mibatch]]$data, midata)
    XMLBATCH_LIST[[mibatch]]$header <<- c(XMLBATCH_LIST[[mibatch]]$header, miheader)
    midata_string <- c(midata_string, midata)
  }

  i <- 1
  while(i < length(batchxml_arr)) {
    mibatch <- batchxml_arr[i]
    mibatch <- sub('.xml$', '_xml', mibatch)
    mimodule <- tolower(gsub("_XML_FINAL", "", batchxml_arr[i+1]))
    mixml <- batchxml_arr[i+2]
    i <- i + 3
    if(is.null(XMLBATCH_LIST[[mibatch]])) {
      XMLBATCH_LIST[[mibatch]] <<- list(data=c(), header=c(), xml="", module="", node_rename=F)
    }
    XMLBATCH_LIST[[mibatch]]$xml <<- mixml
    XMLBATCH_LIST[[mibatch]]$module <<- mimodule
  }

  i <- 1
  while(i < length(node_rename_arr)) {
    mibatch <- node_rename_arr[i]
    mibatch <- sub('.xml$', '_xml', mibatch)
    has_node_rename <- grepl('node_rename=T', node_rename_arr[i+1])
    i <- i + 2
    if(is.null(XMLBATCH_LIST[[mibatch]])) {
      XMLBATCH_LIST[[mibatch]] <<- list(data=c(), header=c(), xml="", module="", node_rename=F)
    }
    if(has_node_rename) {
      XMLBATCH_LIST[[mibatch]]$node_rename <<- has_node_rename
    }
  }

  writedata_string <- basename(c(writedata_string, midata_string))
  no_outputs <- is.null(writedata_string)

  if(no_outputs) {
    warning("No outputs for ", basename(fn))
    replacement <- "NULL"
  } else {
    writedata_string_q <- paste0("\"", writedata_string, "\"")
    replacement <- paste0("c(", paste(writedata_string_q, collapse = ",\n"), ")")
  }

  # Replace OUTPUTS_PATTERN
  pattern <- gsub(pattern = "OUTPUTS_PATTERN",
                  replacement = replacement,
                  pattern,
                  fixed = TRUE)

  # Replace DOCOUT_PATTERN
  if(no_outputs) {
    writedata_string_doc <- "(none)"
  } else {
    writedata_string_doc <- paste0("\\code{", writedata_string, "}")
  }
  pattern <- gsub(pattern = "DOCOUT_PATTERN",
                  replacement = paste(writedata_string_doc, collapse = ", "),
                  pattern,
                  fixed = TRUE)

  # Replace MAKEOUT_PATTERN
  if(no_outputs) {
    makeoutputs_string <- ""
  } else {
    makeoutputs_string <- rep(NA, length(writedata_string))
    for(i in seq_along(writedata_string)) {
      txt1 <- paste0('add_title("descriptive title of data") %>%\n',
                     ' add_units("units") %>%\n',
                     ' add_comments("comments describing how data generated") %>%\n',
                     ' add_comments("can be multiple lines") %>%\n',
                     ' add_legacy_name("', writedata_string[i], '") %>%\n',
                     ' add_precursors("precursor1", "precursor2", "etc") %>%\n',
                     ' # typical flags, but there are others--see `constants.R` \n')
      makeoutputs_string[i] <- paste("tibble() %>%\n  ", txt1, "->\n  ", writedata_string[i])
    }
    makeoutputs_string <- paste(makeoutputs_string, collapse = "\n")
  }


  pattern <- gsub(pattern = "MAKEOUT_PATTERN",
                  replacement = makeoutputs_string,
                  pattern,
                  fixed = TRUE)

  # Replace RETURNOUT_PATTERN
  pattern <- gsub(pattern = "RETURNOUT_PATTERN",
                  replacement = paste(writedata_string, collapse = ", "),
                  pattern,
                  fixed = TRUE)

  pattern
}

batch_substitutions <- function(mibatch, patternfile = PATTERNFILE) {
  pattern <- readLines(patternfile)
  batchdata <- XMLBATCH_LIST[[mibatch]]

  fn <- paste0(mibatch, ".R")
  print(basename(fn))

  # Replace file info
  pattern <- gsub(pattern = "ORIGINALFILE_PATTERN",
                  replacement = basename(fn),
                  pattern,
                  fixed = TRUE)
  pattern <- gsub(pattern = "MODULE_PATTERN",
                  replacement = batchdata$module,
                  pattern,
                  fixed = TRUE)
  pattern <- gsub(pattern = "LEVEL_PATTERN",
                  replacement = "XML",
                  pattern,
                  fixed = TRUE)

  # Replace CHUNK_NAME with file name (minus .R)
  # Use make.names to ensure syntactically valid
  chunkname <- make.names(paste("module", batchdata$module, gsub("\\.R$", "", basename(fn)), sep = "_"))
  pattern <- gsub(pattern = "CHUNK_NAME", replacement = chunkname, pattern, fixed = TRUE)

  # Find readdata lines
  readdata_string <- batchdata$data
  no_inputs <- is.null(readdata_string)
  if(no_inputs) {
    stop("No inputs for ", basename(fn))
  } else {
    readdata_string_q <- paste0("\"", readdata_string, "\"")
    fileinputs <- grep("/", readdata_string, fixed = TRUE)
    fileprefix <- rep("", length(readdata_string))
    fileprefix[fileinputs] <- "FILE ="
    replacement <- paste0("c(", paste(paste(fileprefix, readdata_string_q), collapse = ",\n"), ")")
  }

  # Replace INPUTS_PATTERN, marking "FILE =" as necessary
  pattern <- gsub(pattern = "INPUTS_PATTERN",
                  replacement = replacement,
                  pattern,
                  fixed = TRUE)

  # Replace LOAD_PATTERN
  if(no_inputs) {
    load_string <- ""
  } else {
    load_string <- paste0("  ", basename(readdata_string), " <- get_data(all_data, ", readdata_string_q, ")")
  }

  pattern <- gsub(pattern = "LOAD_PATTERN",
                  replacement = paste(load_string, collapse = "\n"),
                  pattern,
                  fixed = TRUE)

  # Remove @details to @import lines as they are not applicable for batch XML chunks.
  fl <- grep("@details", pattern)
  ll <- grep("@export", pattern)
  pattern <- pattern[-fl:-ll]

  # Insert main chunk description in place of "Briefly describe..." text
  fl <- grep("Briefly describe", pattern)
  pattern[fl] <- paste0("#' Construct XML data structure for \\code{", batchdata$xml, "}.")

  # Remove TRANSLATED PROCESSING CODE GOES HERE comment up to WARNING_PATTERN
  # as they are not applicable for batch XML chunks.
  fl <- grep("TRANSLATED PROCESSING CODE GOES HERE", pattern)
  ll <- grep("WARNING_PATTERN", pattern)
  pattern <- pattern[-fl:-(ll+1)]

  # Find output lines

  if(batchdata$xml == "") {
    stop("No outputs for ", basename(fn))
  } else {
    replacement <- paste0("c(XML = \"", batchdata$xml, "\")")
  }

  # Replace OUTPUTS_PATTERN
  pattern <- gsub(pattern = "OUTPUTS_PATTERN",
                  replacement = replacement,
                  pattern,
                  fixed = TRUE)

  # Replace DOCOUT_PATTERN
  if(batchdata$xml == "") {
    writedata_string_doc <- "(none)"
  } else {
    writedata_string_doc <- paste0("\\code{", batchdata$xml, "}")
  }
  pattern <- gsub(pattern = "DOCOUT_PATTERN",
                  replacement = paste(writedata_string_doc, collapse = ", "),
                  pattern,
                  fixed = TRUE)

  # Replace MAKEOUT_PATTERN

  # Batch XML chunks will generate precursors so we can remove the comments
  # asking the users to add them.
  fl <- grep("Temporary code below sends back empty data frames marked", pattern)
  ll <- grep("If no precursors", pattern)
  pattern <- pattern[-fl:-ll]

  if(no_inputs) {
    makeoutputs_string <- ""
  } else {
    header_quote <- paste0('"', batchdata$header, '"')
    create_xml_string <- paste0("create_xml(\"", batchdata$xml, "\")")
    add_data_string <- paste0("add_xml_data(", paste(batchdata$data, header_quote, sep=","), ")")
    precursors_string <- paste0("add_precursors(",
                                paste(paste0('"', batchdata$data, '"'), collapse=", "),
                                ") ->\n", batchdata$xml)
    # add rename if this batch file needs it
    if(batchdata$node_rename) {
      add_data_string <- c(add_data_string, "add_rename_landnode_xml()")
    }
    # the EQUIV_TABLE is a special kind of table and we must ensure no column
    # name checking occurs since we will not even know how many columns it has
    add_data_string <- gsub('"EQUIV_TABLE"', '"EQUIV_TABLE", column_order_lookup=NULL', add_data_string)

    makeoutputs_string <- paste(c(create_xml_string, add_data_string, precursors_string), collapse = " %>%\n")
  }


  pattern <- gsub(pattern = "MAKEOUT_PATTERN",
                  replacement = makeoutputs_string,
                  pattern,
                  fixed = TRUE)

  # Replace RETURNOUT_PATTERN
  pattern <- gsub(pattern = "RETURNOUT_PATTERN",
                  replacement = batchdata$xml,
                  pattern,
                  fixed = TRUE)

  pattern
}

# ----------------------- MAIN -----------------------

files <- list.files("../gcam-data-system-OLD/",
                    pattern = "*.R$", full.names = TRUE, recursive = TRUE)
# Limit to scripts in the processing code folders
files <- files[grepl("processing-code", files, fixed = TRUE)]

linedata <- list()

for(fn in files) {
  # Isolate the module and level information from the filename
  fn <- gsub("//", "/", fn, fixed = TRUE)
  x <- strsplit(fn, "/")[[1]]
  level <- x[length(x) - 1]
  module <- gsub("-processing-code", "", x[length(x) - 2], fixed = TRUE)
  newfn <- file.path("chunk-generator", "outputs", paste0("module-", module, "-", level, ".R"))

  out <- NULL
  try(out <- make_substitutions(fn))
  if(is.null(out)) {
    warning("Ran into error with ", basename(fn))
  } else {
    newfn <- paste0("chunk-generator/outputs/zchunk_", basename(fn))
    if(file.exists(file.path("R", basename(newfn)))) {
      cat("- already exists in ./R; skipping\n")
      next
    }
    while(file.exists(newfn)) {
      newfn <- gsub(".R", "-x.R", newfn, fixed = TRUE)
      message(newfn)
    }
    cat(out, "\n", file = newfn, sep = "\n", append = FALSE)
  }
  linedata[[newfn]] <- tibble(filename = basename(newfn),
                              lines = length(readLines(fn)))

}

linedata <- dplyr::bind_rows(linedata)
readr::write_csv(linedata, "chunk-generator/outputs/linedata.csv")

for(bf in names(XMLBATCH_LIST)) {
  newfn <- file.path("chunk-generator", "outputs", paste0("module-", XMLBATCH_LIST[[bf]]$module, "-", bf, ".R"))

  out <- NULL
  try(out <- batch_substitutions(bf))
  if(is.null(out)) {
    warning("Ran into error with ", basename(bf))
  } else {
    newfn <- paste0("chunk-generator/outputs/zchunk_", basename(bf), ".R")
    if(file.exists(file.path("R", basename(newfn)))) {
      cat("- already exists in ./R; skipping\n")
      next
    }
    cat(out, "\n", file = newfn, sep = "\n", append = FALSE)
  }
}
