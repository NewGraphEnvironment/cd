# Package setup tracking
# Run these interactively — they are NOT idempotent

# 1. Package scaffold (already done if DESCRIPTION exists)
# usethis::create_package(".")

# 2. License
usethis::use_mit_license("New Graph Environment Ltd.")

# 3. Testing
usethis::use_testthat(edition = 3)

# 4. Documentation site
usethis::use_pkgdown()
usethis::use_github_action("pkgdown")

# 5. Directories
usethis::use_directory("dev")
usethis::use_directory("data-raw")
usethis::use_directory("inst/extdata")
usethis::use_directory("planning/active")
usethis::use_directory("planning/completed")

# 6. Dependencies — Imports
usethis::use_package("dplyr")
usethis::use_package("jsonlite")
usethis::use_package("rappdirs")
usethis::use_package("rlang")
usethis::use_package("sf")
usethis::use_package("terra")
usethis::use_package("tibble")

# 6b. Dependencies — Suggests
usethis::use_package("aws.s3", type = "Suggests")
usethis::use_package("ecmwfr", type = "Suggests")
usethis::use_package("ggplot2", type = "Suggests")
usethis::use_package("gt", type = "Suggests")
usethis::use_package("Kendall", type = "Suggests")
usethis::use_package("knitr", type = "Suggests")
usethis::use_package("rmarkdown", type = "Suggests")
usethis::use_package("bookdown", type = "Suggests")
usethis::use_package("testthat", type = "Suggests", min_version = "3.0.0")
usethis::use_package("zyp", type = "Suggests")

# 7. Hex sticker
# source("data-raw/make_hexsticker.R")

# 8. Build
devtools::document()
devtools::test()
devtools::check()
