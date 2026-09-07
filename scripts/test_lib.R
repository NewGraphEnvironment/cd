#!/usr/bin/env Rscript
#
# Offline tests for scripts/_lib.R. No network, no EDH token — every case is a
# plain function call, so this is safe to run anywhere.
#
# Usage:
#   Rscript scripts/test_lib.R

source("scripts/_lib.R")

failures <- 0L
checks <- 0L
check <- function(ok, what) {
  checks <<- checks + 1L
  failures <<- failures + as.integer(!ok)
  cat(sprintf("  %s  %s\n", if (ok) "ok  " else "FAIL", what))
}

# -- edh_retryable -------------------------------------------------------------
# Both answers, and the two that must be FALSE are the ones that matter: a
# retried 401 just delays a report, and a retried 404 hammers a dead URL.
for (s in c(0L, 403L, 408L, 429L, 500L, 503L)) {
  check(edh_retryable(s), sprintf("retryable(%d) is TRUE", s))
}
for (s in c(200L, 400L, 401L, 404L)) {
  check(!edh_retryable(s), sprintf("retryable(%d) is FALSE", s))
}

# -- edh_diagnosis -------------------------------------------------------------
# The point of #83 is that these three must not read the same. Asserting each
# message separately would still pass if all three were identical, so assert
# the distinctness itself.
d401 <- edh_diagnosis(401L)
d403 <- edh_diagnosis(403L)
d404 <- edh_diagnosis(404L)
check(length(unique(c(d401, d403, d404))) == 3L,
      "401, 403 and 404 give three distinct diagnoses")

check(grepl("Rotate", d401, fixed = TRUE), "401 says to rotate the secret")
check(grepl("NOT a bad token", d403, fixed = TRUE), "403 says it is not the token")
check(!grepl("[Rr]otate", d403), "403 does NOT send the reader to rotate")
check(grepl("quota", d403, fixed = TRUE), "403 names the quota as a candidate")
check(grepl("moved", d404, fixed = TRUE), "404 points at the endpoint")
check(grepl("server error", edh_diagnosis(503L), fixed = TRUE), "5xx blames EDH")
check(nzchar(edh_diagnosis(418L)), "an unmapped status still says something")

cat(sprintf("\n%d/%d passed\n", checks - failures, checks))
quit(status = if (failures > 0L) 1L else 0L)
