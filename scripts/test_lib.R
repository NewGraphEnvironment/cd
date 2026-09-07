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
d0   <- edh_diagnosis(0L)
d401 <- edh_diagnosis(401L)
d403 <- edh_diagnosis(403L)
d404 <- edh_diagnosis(404L)
# Status 0 belongs in the distinctness set: it is the connection-failure path
# (pipeline_update_edh.R sets edh_status <- 0L when the request returns NULL),
# and it is the status most likely to fire in CI. Left out, a diagnosis that
# collided with 401's would send an operator to rotate a healthy secret on a
# DNS timeout -- the precise regression this file exists to prevent.
check(length(unique(c(d0, d401, d403, d404))) == 4L,
      "0, 401, 403 and 404 give four distinct diagnoses")
check(grepl("reach the host", d0, fixed = TRUE), "0 says the host was unreachable")

check(grepl("Rotate", d401, fixed = TRUE), "401 says to rotate the secret")
check(grepl("NOT a bad token", d403, fixed = TRUE), "403 says it is not the token")
check(!grepl("Rotate the EDH_TOKEN secret", d403, fixed = TRUE),
      "403 does not carry 401's rotate-the-secret instruction")
check(grepl("quota", d403, fixed = TRUE), "403 names the quota as a candidate")
check(grepl("moved", d404, fixed = TRUE), "404 points at the endpoint")
check(grepl("server error", edh_diagnosis(500L), fixed = TRUE), "500 blames EDH (boundary)")
check(grepl("server error", edh_diagnosis(503L), fixed = TRUE), "5xx blames EDH")
check(nzchar(edh_diagnosis(418L)), "an unmapped status still says something")

cat(sprintf("\n%d/%d passed\n", checks - failures, checks))
quit(status = if (failures > 0L) 1L else 0L)
