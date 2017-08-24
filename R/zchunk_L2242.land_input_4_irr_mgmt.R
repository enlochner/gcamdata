#' module_aglu_L2242.land_input_4_irr_mgmt
#'
#' Briefly describe what this chunk does.
#'
#' @param command API command to execute
#' @param ... other optional parameters, depending on command
#' @return Depends on \code{command}: either a vector of required inputs,
#' a vector of output names, or (if \code{command} is "MAKE") all
#' the generated outputs: \code{L2241.LN4_LogitTables[[ curr_table_name ]]}, \code{L2242.LN4_Logit}, \code{L2242.LN4_NodeGhostShare}, \code{L2242.LN4_NodeIsGhostShareRel}. The corresponding file in the
#' original data system was \code{L2242.land_input_4_irr_mgmt.R} (aglu level2).
#' @details Describe in detail what this chunk does.
#' @importFrom assertthat assert_that
#' @importFrom dplyr filter mutate select
#' @importFrom tidyr gather spread
#' @author YourInitials CurrentMonthName 2017
#' @export
module_aglu_L2242.land_input_4_irr_mgmt_DISABLED <- function(command, ...) {
  if(command == driver.DECLARE_INPUTS) {
    return(c( "L2241.LN4_Logit",
              "L2241.LN4_NodeGhostShare",
              "L2241.LN4_NodeIsGhostShareRel"))
  } else if(command == driver.DECLARE_OUTPUTS) {
    return(c("L2242.LN4_Logit",
             "L2242.LN4_NodeGhostShare",
             "L2242.LN4_NodeIsGhostShareRel"))
  } else if(command == driver.MAKE) {

    all_data <- list(...)[[1]]

    # Load required inputs
    L2241.LN4_Logit <- get_data(all_data, "L2241.LN4_Logit")
    L2241.LN4_NodeGhostShare <- get_data(all_data, "L2241.LN4_NodeGhostShare")
    L2241.LN4_NodeIsGhostShareRel <- get_data(all_data, "L2241.LN4_NodeIsGhostShareRel")

    # ===================================================
    # TRANSLATED PROCESSING CODE GOES HERE...
    #
    # If you find a mistake/thing to update in the old code and
    # fixing it will change the output data, causing the tests to fail,
    # (i) open an issue on GitHub, (ii) consult with colleagues, and
    # then (iii) code a fix:
    #
    # if(OLD_DATA_SYSTEM_BEHAVIOR) {
    #   ... code that replicates old, incorrect behavior
    # } else {
    #   ... new code with a fix
    # }
    #
    #
    # ===================================================

    # Produce outputs
    # Temporary code below sends back empty data frames marked "don't test"
    # Note that all precursor names (in `add_precursor`) must be in this chunk's inputs
    # There's also a `same_precursors_as(x)` you can use
    # If no precursors (very rare) don't call `add_precursor` at all
    tibble() %>%
      add_title("descriptive title of data") %>%
      add_units("units") %>%
      add_comments("comments describing how data generated") %>%
      add_comments("can be multiple lines") %>%
      add_legacy_name("L2242.LN4_Logit") %>%
      add_precursors("precursor1", "precursor2", "etc") %>%
      # typical flags, but there are others--see `constants.R`
      add_flags(FLAG_LONG_YEAR_FORM, FLAG_NO_XYEAR) ->
      L2242.LN4_Logit

    tibble() %>%
      add_title("descriptive title of data") %>%
      add_units("units") %>%
      add_comments("comments describing how data generated") %>%
      add_comments("can be multiple lines") %>%
      add_legacy_name("L2242.LN4_NodeGhostShare") %>%
      add_precursors("precursor1", "precursor2", "etc") %>%
      # typical flags, but there are others--see `constants.R`
      add_flags(FLAG_LONG_YEAR_FORM, FLAG_NO_XYEAR) ->
      L2242.LN4_NodeGhostShare

    tibble() %>%
      add_title("descriptive title of data") %>%
      add_units("units") %>%
      add_comments("comments describing how data generated") %>%
      add_comments("can be multiple lines") %>%
      add_legacy_name("L2242.LN4_NodeIsGhostShareRel") %>%
      add_precursors("precursor1", "precursor2", "etc") %>%
      # typical flags, but there are others--see `constants.R`
      add_flags(FLAG_LONG_YEAR_FORM, FLAG_NO_XYEAR) ->
      L2242.LN4_NodeIsGhostShareRel

    return_data(L2242.LN4_Logit, L2242.LN4_NodeGhostShare, L2242.LN4_NodeIsGhostShareRel)
  } else {
    stop("Unknown command")
  }
}