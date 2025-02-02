defineModule(sim, list(
  name = "Biomass_speciesParameters",
  description = paste("For estimating LANDIS-II species traits based on growth curves derived",
                      "from Permanent Sample Plot (PSP) and Temporary Sample Plot (TSP) data"),
  keywords = NA, # c("insert key words here"),
  authors = c(person(c("Ian"), "Eddy", email = "ian.eddy@nrcan-rncan.gc.ca", role = c("aut", "cre")),
              person(c("Eliot"), "McIntire", email = "eliot.mcintire@nrcan-rncan.gc.ca", role = c("aut")),
              person(c("Ceres"), "Barros", email = "ceres.barros@ubc.ca", role = c("ctb"))),
  childModules = character(0),
  version = list(Biomass_speciesParameters = "2.0.2"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("README.txt", "Biomass_speciesParameters.Rmd"),
  loadOrder = list(after = c("Biomass_speciesFactorial", "Biomass_borealDataPrep"),
                   before = c("Biomass_core")),
  reqdPkgs = list("crayon", "data.table", "disk.frame", "fpCompare", "ggplot2", "gridExtra",
                  "magrittr", "mgcv", "nlme", "purrr", "robustbase", "sf",
                  "reproducible (>= 2.1.0)", "SpaDES.core (>= 2.1.4)",
                  "PredictiveEcology/LandR (>= 1.1.0.9077)",
                  "PredictiveEcology/pemisc@development (>= 0.0.3.9002)",
                  "ianmseddy/PSPclean@development (>= 0.1.4.9005)"),
  parameters = rbind(
    defineParameter("biomassModel", "character", "Lambert2005", NA, NA,
                    desc =  paste("The model used to calculate biomass from DBH. Can be either 'Lambert2005' or 'Ung2008'.")),
    defineParameter("maxBInFactorial", "integer", 5000L, NA, NA,
                    desc = paste("The arbitrary maximum biomass for the factorial simulations.",
                                 "This is a per-species maximum within a pixel")),
    defineParameter("minimumPlots", "numeric", 50, 10, NA,
                    desc = paste("Minimum number of PSP plots per species")),
    defineParameter("minDBH", "integer", 0L, 0L, NA,
                    desc = paste("Minimum diameter at breast height (DBH) in cm used to filter PSP data.",
                                 "Defaults to 0 cm, i.e. all tree measurements are used.")),
    defineParameter("PSPdataTypes", "character", "all", NA, NA,
                    desc = paste("Which PSP datasets to source, defaulting to all. Other available options include",
                                 "'BC', 'AB', 'SK', 'ON', 'NB', 'NFI', and 'dummy'.",
                                 "'dummy' should be used for unauthorized users.")),
    defineParameter("PSPperiod", "numeric", c(1920, 2019), NA, NA,
                    desc = paste("The years by which to subset sample plot data, if desired. Must be a vector of length 2")),
    defineParameter("quantileAgeSubset", "numeric", 95, 1, 100,
                    desc = paste("Quantile by which to subset PSP data. As older stands are sparsely represented",
                                 "the oldest measurements become vastly more influential. This parameter accepts",
                                 "both a single value and a list of vectors, named according to `sppEquivCol`.")),
    defineParameter("speciesFittingApproach", "character", "focal", NA, NA,
                    desc =  paste("Either 'all', 'pairwise', 'focal' or 'single', indicating whether to pool ",
                                  "all species into one fit, do pairwise species (for multiple cohort situations), do",
                                  "pairwise species, but using a focal species approach where all other species are ",
                                  "pooled into 'other' or do one species at a time. If 'all', all species will have",
                                  "identical species-level traits")),
    defineParameter("sppEquivCol", "character", "Boreal", NA, NA,
                    paste("The column in `sim$sppEquiv` data.table that defines individual species.",
                          "The names should match those in the species table.")),
    defineParameter("standAgesForFitting", "integer", c(21L, 91L), NA, NA,
                    desc = paste("The minimum and maximum ages of the biomass-by-age curves used in fitting.",
                                 "It is generally recommended to keep this param under 200, given the low data",
                                 "availability of stands aged 200+, with some exceptions.",
                                 "For a closed interval, end with a 1, e.g. `c(31, 101)`.")),
    defineParameter("useHeight", "logical", TRUE, NA, NA,
                    desc = paste("Should height be used to calculate biomass (in addition to DBH).",
                                 "DBH is used by itself when height is missing.")),
    defineParameter(".plots", "character", "screen", NA, NA,
                    desc = "Used by Plots function, which can be optionally used here"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    desc = "This describes the simulation time at which the first plot event should occur"),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    desc = "This describes the simulation time interval between plot events"),
    defineParameter(".saveInitialTime", "numeric", NA, NA, NA,
                    desc = "This describes the simulation time at which the first save event should occur"),
    defineParameter(".saveInterval", "numeric", NA, NA, NA,
                    desc = "This describes the simulation time interval between save events"),
    defineParameter(".studyAreaName", "character", NA, NA, NA,
                    desc = paste("Human-readable name for the growth curve filename.",
                                 "If `NA`, a hash of sppEquiv[[sppEquivCol]] will be used.")),
    defineParameter(".useCache", "character", c(".inputObjects", "init"), NA, NA,
                    desc = paste("Should this entire module be run with caching activated?",
                                 "This is generally intended for data-type modules, where stochasticity and time are not relevant"))
  ),
  inputObjects = bindrows(
    expectsInput(objectName = "speciesTableFactorial", objectClass = "data.table",
                 desc = paste("A large species table (**sensu** `Biomass_core`) with all columns used by",
                              "Biomass_core, e.g., `longevity`, `growthcurve`, `mortalityshape`, etc., when",
                              "it was used to generate `cohortDataFactorial`.",
                              "See `PredictiveEcology/Biomass_factorial` for futher information.",
                              "It will be written to `disk.frame` following sim completion, to preserve RAM."),
                 sourceURL = "https://drive.google.com/file/d/1NH7OpAnWtLyO8JVnhwdMJakOyapBnuBH/"),
    expectsInput(objectName = "cohortDataFactorial", objectClass = "data.table",
                 desc = paste("A large `cohortData` table (**sensu** `Biomass_core`) with columns `age`, `B`, and `speciesCode`",
                              "that joins with `speciesTableFactorial`. See `PredictiveEcology/Biomass_factorial`",
                              "for further information. It will be written to `disk.frame` following sim",
                              "completion, to preserve RAM."),
                 sourceURL = "https://drive.google.com/file/d/1NH7OpAnWtLyO8JVnhwdMJakOyapBnuBH/"),
    expectsInput(objectName = "PSPmeasure_sppParams", objectClass = "data.table",
                 desc = paste("Merged PSP and TSP individual tree measurements. Must include the following columns:",
                              "`MeasureID`, `OrigPlotID1`, `MeasureYear`, `TreeNumber`, `Species`, `DBH` and `newSpeciesName`,",
                              "the latter corresponding to species names in `LandR::sppEquivalencies_CA$PSP`.",
                              "Defaults to randomized PSP data stripped of real `plotID`s"),
                 sourceURL = "https://drive.google.com/file/d/1LmOaEtCZ6EBeIlAm6ttfLqBqQnQu4Ca7/view?usp=sharing"),
    expectsInput(objectName = "PSPplot_sppParams", objectClass = "data.table",
                 desc = paste("Merged PSP and TSP plot data. Defaults to randomized PSP data stripped of real `plotID`s.",
                              "Must contain columns `MeasureID`, `MeasureYear`, `OrigPlotID1`, and `baseSA`,",
                              "the latter being stand age at year of first measurement"),
                 sourceURL = "https://drive.google.com/file/d/1LmOaEtCZ6EBeIlAm6ttfLqBqQnQu4Ca7/view?usp=sharing"),
    expectsInput(objectName = "PSPgis_sppParams", objectClass = "sf",
                 desc = paste("Plot location `sf` object. Defaults to PSP data stripped of real `plotID`s/location.",
                              "Must include field `OrigPlotID1` for joining to `PSPplot` object"),
                 sourceURL = "https://drive.google.com/file/d/1LmOaEtCZ6EBeIlAm6ttfLqBqQnQu4Ca7/view?usp=sharing"),
    expectsInput(objectName = "species", objectClass = "data.table",
                 desc = paste("A table of invariant species traits with the following trait colums:",
                              "'species', 'Area', 'longevity', 'sexualmature', 'shadetolerance',",
                              "'firetolerance', 'seeddistance_eff', 'seeddistance_max', 'resproutprob',",
                              "'mortalityshape', 'growthcurve', 'resproutage_min', 'resproutage_max',",
                              "'postfireregen', 'wooddecayrate', 'leaflongevity' 'leafLignin', and 'hardsoft'.",
                              "Only 'growthcurve', 'hardsoft',  and 'mortalityshape' are used in this module.",
                              "Default is from Dominic Cyr and Yan Boulanger's applications of LANDIS-II"),
                 sourceURL = "https://raw.githubusercontent.com/dcyr/LANDIS-II_IA_generalUseFiles/master/speciesTraits.csv"),
    expectsInput(objectName = "speciesEcoregion", objectClass = "data.table",
                 desc = paste("Table of spatially-varying species traits ('maxB', 'maxANPP',",
                              "'establishprob'), defined by species and 'ecoregionGroup')",
                              "Defaults to a dummy table based on dummy data os biomass, age, ecoregion and land cover class")),
    expectsInput(objectName = "sppEquiv", objectClass = "data.table",
                 desc = "Table of species equivalencies. See `?LandR::sppEquivalencies_CA`."),
    expectsInput(objectName = "studyAreaANPP", objectClass = "sf",
                 desc = paste("Optional study area used to crop PSP data before building growth curves.",
                              "If supplied, an ecoregion-scale object is recommended, at a minimum."))
  ),
  outputObjects = bindrows(
    createsOutput(objectName = "cohortDataFactorial", objectClass = "disk.frame",
                  desc = "This object is converted to a `disk.frame` to save memory. Read using `as.data.table()`."),
    createsOutput("species", "data.table",
                  desc = "The updated invariant species traits table (see description for this object in inputs)"),
    createsOutput(objectName = "speciesEcoregion", "data.table",
                  desc = paste("The updated spatially-varying species traits table",
                               "(see description for this object in inputs)")),
    createsOutput(objectName = "speciesGrowthCurves", "list",
                  desc = "list containing each species non-linear model, model data, and the unfiltered PSP data"),
    createsOutput(objectName = "speciesTableFactorial", objectClass = "disk.frame",
                  desc = "This object is converted to a `disk.frame` to save memory. Read using `as.data.table()`.")
  )
))

## event types
#   - type `init` is required for initialization

doEvent.Biomass_speciesParameters = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      # build growth curves if applicable
      sim <- Init(sim)
      #update tables
      sim <- updateSpeciesTables(sim)

      sim <- useDiskFrame(sim)
    },
    warning(paste("Undefined event type: '", current(sim)[1, "eventType", with = FALSE],
                  "' in module '", current(sim)[1, "moduleName", with = FALSE], "'", sep = ""))
  )
  return(invisible(sim))
}

## event functions
#   - keep event functions short and clean, modularize by calling subroutines from section below.

### template initialization
Init <- function(sim) {
  origDTthreads <- data.table::getDTthreads()
  if (getDTthreads() > 4) {
    data.table::setDTthreads(4)
  }
  on.exit(data.table::setDTthreads(origDTthreads))

  ## if no PSP data supplied, simList returned unchanged

  if (all(P(sim)$PSPdataTypes != "none")) {
    if (is.na(P(sim)$sppEquivCol)) {
      stop("Please supply 'sppEquivCol' in parameters of Biomass_speciesParameters.")
    }

    paramCheckOtherMods(sim, "maxBInFactorial")
    paramCheckOtherMods(sim, paramToCheck = "sppEquivCol", ifSetButDifferent = "error")

    ## find the max biomass achieved by each species when growing with no competition
    tempMaxB <- sim$cohortDataFactorial[age == 1, .N, .(pixelGroup)]
    ## take the pixelGroups with only 1 species at start of factorial
    tempMaxB <- tempMaxB[N == 1,]
    tempMaxB <- sim$cohortDataFactorial[pixelGroup %in% tempMaxB$pixelGroup,
                                        .(inflationFactor = P(sim)$maxBInFactorial/max(B)),
                                        , .(pixelGroup, speciesCode)]
    ## in some cases the speciesTableFactorial doesn't have "species" column; just "speciesCode"
    if (!("species" %in% colnames(sim$speciesTableFactorial))) { # TODO this is a work around -- the speciesTableFactorial should be stable
      setnames(sim$speciesTableFactorial, old = "speciesCode", new = "species")
    }
    tempMaxB <- sim$speciesTableFactorial[tempMaxB, on = c("species" = "speciesCode", "pixelGroup")]
    ## pair-wise species will be matched with traits, as the species code won't match
    tempMaxB <- tempMaxB[, .(species, longevity, growthcurve, mortalityshape, mANPPproportion, inflationFactor)]
    gc()
    ## prepare PSPdata
    sim$speciesGrowthCurves <- Cache(
      buildGrowthCurves_Wrapper,
      studyAreaANPP = sim$studyAreaANPP,
      PSPperiod = P(sim)$PSPperiod,
      PSPgis = sim$PSPgis_sppParams,
      PSPmeasure = sim$PSPmeasure_sppParams,
      PSPplot = sim$PSPplot_sppParams,
      useHeight = P(sim)$useHeight,
      biomassModel = P(sim)$biomassModel,
      speciesCol = P(sim)$sppEquivCol,
      sppEquiv = sim$sppEquiv,
      minimumSampleSize = P(sim)$minimumPlots,
      quantileAgeSubset = P(sim)$quantileAgeSubset,
      minDBH = P(sim)$minDBH,
      speciesFittingApproach = P(sim)$speciesFittingApproach,
      userTags = c(currentModule(sim), "buildGrowthCurves_Wrapper"))

    classes <- lapply(sim$speciesGrowthCurves, FUN = "class")

    noDataSpp <- vapply(sim$speciesGrowthCurves[classes == "character"], FUN = function(x) {
      x == "insufficient data"
    }, FUN.VALUE = logical(1))

    if (any(noDataSpp)) {
      message(crayon::yellow("Insufficient data to estimate species parameters for",
                             paste(names(noDataSpp), collapse = ", "),
                             "- will keep original user-supplied parameters"))
    }

    cacheExtra <- .robustDigest(list(
      sim$speciesGrowthCurves[!names(sim$speciesGrowthCurves) %in% names(noDataSpp)],
      setDT(sim$speciesTableFactorial),
      setDT(sim$cohortDataFactorial)
      ))
    modifiedSpeciesTables <- Cache(
      modifySpeciesTable,
      GCs = sim$speciesGrowthCurves[!names(sim$speciesGrowthCurves) %in% names(noDataSpp)],
      speciesTable = sim$species,
      factorialTraits = setDT(sim$speciesTableFactorial),
      # setDT to deal with reload from Cache (no effect otherwise)
      factorialBiomass = setDT(sim$cohortDataFactorial),
      # setDT to deal with reload from Cache (no effect otherwise)
      sppEquiv = sim$sppEquiv,
      approach = P(sim)$speciesFittingApproach,
      sppEquivCol = P(sim)$sppEquivCol,
      maxBInFactorial = P(sim)$maxBInFactorial,
      inflationFactorKey = tempMaxB,
      standAgesForFitting = P(sim)$standAgesForFitting,
      omitArgs = c("GCs", "factorialTraits", "factorialBiomass"),
      .cacheExtra = cacheExtra,
      userTags = c(currentModule(sim), "modifiedSpeciesTables")
    )

    gg <- modifiedSpeciesTables$gg
    Plots(gg, usePlot = FALSE, fn = print, ggsaveArgs = list(width = 10, height = 7),
          filename = paste("LandR_VS_NLM_growthCurves"))
    sim$species <- modifiedSpeciesTables$best
  } else {
    message("P(sim)$PSPdataTypes is 'none' -- bypassing species traits estimation from PSP data.")
  }
  return(sim)
}

updateSpeciesTables <- function(sim) {
  modifiedTables <- modifySpeciesAndSpeciesEcoregionTable(speciesEcoregion = sim$speciesEcoregion,
                                                          speciesTable = sim$species)
  sim$speciesEcoregion <- modifiedTables$newSpeciesEcoregion
  sim$species <- modifiedTables$newSpeciesTable
  return(sim)
}

useDiskFrame <- function(sim) {
  setup_disk.frame(workers = 2) ## TODO: is there a better default? should this be user-specified?

  cdRows <- nrow(sim$cohortDataFactorial)
  ## the rows of a factorial object will determine whether it is unique in 99.9% of cases
  sim$cohortDataFactorial <- as.disk.frame(sim$cohortDataFactorial, overwrite = TRUE,
                                           outdir = file.path(inputPath(sim),
                                                              paste0("cohortDataFactorial", cdRows)))
  stRows <- nrow(sim$speciesTableFactorial)
  sim$speciesTableFactorial <- as.disk.frame(sim$speciesTableFactorial, overwrite = TRUE,
                                             outdir = file.path(inputPath(sim),
                                                                paste0("speciesTableFactorial", stRows)))
  ## NOTE: disk.frame objects can be converted to data.table with as.data.table
  gc(reset = TRUE)
  return(sim)
}

### template for save events
Save <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sim <- saveFiles(sim)

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

.inputObjects <- function(sim) {
  origDTthreads <- data.table::getDTthreads()
  if (origDTthreads > 4) {
    data.table::setDTthreads(4)
  }
  on.exit(data.table::setDTthreads(origDTthreads))

  cacheTags <- c(currentModule(sim), "OtherFunction:.inputObjects")
  dPath <- asPath(inputPath(sim), 1)
  message(currentModule(sim), ": using dataPath '", dPath, "'.")

  if (!suppliedElsewhere("cohortDataFactorial", sim)) {
    sim$cohortDataFactorial <- prepInputs(targetFile = "cohortDataFactorial_medium.rds",
                                          destinationPath = dPath,
                                          fun = "readRDS", overwrite = TRUE,
                                          url = extractURL("cohortDataFactorial", sim),
                                          useCache = TRUE, userTags = c(cacheTags, "factorialCohort"))
  }

  if (!suppliedElsewhere("speciesTableFactorial", sim)) {
    sim$speciesTableFactorial <- prepInputs(targetFile = "speciesTableFactorial_medium.rds",
                                            destinationPath = dPath,
                                            url = extractURL("speciesTableFactorial", sim),
                                            fun = "readRDS", overwrite = TRUE,
                                            useCache = TRUE, userTags = c(cacheTags, "factorialSpecies"))
  }

  if (!suppliedElsewhere("sppEquiv", sim)) {
    #pass a default sppEquivalencies_CA for common species in western Canada
    sppEquiv <- LandR::sppEquivalencies_CA
    sim$sppEquiv <- sppEquiv[LandR %in% c(Pice_mar = "Pice_mar", Pice_gla = "Pice_gla",
                                          Pinu_con = "Pinu_con", Popu_tre = "Popu_tre",
                                          Betu_pap = "Betu_pap", Pice_eng = "Pice_eng",
                                          Abie_bal = "Abie_bal",
                                          Pinu_ban = "Pinu_ban", Lari_lar = "Lari_lar"), ]
  }

  if (!suppliedElsewhere("speciesEcoregion", sim)) {
    warning("generating dummy speciesEcoregion data - run Biomass_borealDataPrep for table with real speciesEcoregion attributes")
    sim$speciesEcoregion <- data.table(
      speciesCode = unique(sim$sppEquiv[[P(sim)$sppEquivCol]]),
      ecoregionGroup = "x",
      establishprob = 0.5,
      maxB = P(sim)$maxBInFactorial,
      maxANPP = P(sim)$maxBInFactorial / 30,
      year = 0
    )
  }

  ## check parameter consistency across modules
  paramCheckOtherMods(sim, "sppEquivCol", ifSetButDifferent = "error")

  if (!suppliedElsewhere("species", sim)) {
    message("generating dummy species data - run Biomass_borealDataPrep for table with real species attributes")
    speciesTable <- getSpeciesTable()
    sim$species <- prepSpeciesTable(speciesTable,
                                    sppEquiv = sim$sppEquiv,
                                    sppEquivCol = P(sim)$sppEquivCol)
  }

  if (!suppliedElsewhere("PSPmeasure_sppParams", sim) |
      !suppliedElsewhere("PSPplot_sppParams", sim) |
      !suppliedElsewhere("PSPgis_sppParams", sim)) {
    message("one or more PSP objects not supplied. Generating PSP data...")

    PSPdata <- Cache(getPSP,
                     PSPdataTypes = P(sim)$PSPdataTypes,
                     destinationPath = dPath,
                     forGMCS = FALSE,
                     userTags = c(cacheTags, P(sim)$PSPdataTypes))

    sim$PSPmeasure_sppParams <- PSPdata$PSPmeasure
    sim$PSPplot_sppParams <- PSPdata$PSPplot
    sim$PSPgis_sppParams <- PSPdata$PSPgis
  }

  return(invisible(sim))
}
