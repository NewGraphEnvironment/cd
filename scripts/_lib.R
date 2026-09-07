# Shared helpers for the cd producer-side R pipeline scripts.
#
# Mirrors scripts/_lib.py on the Python side. These are producer-side
# operational concerns, not consumer API, so they live here rather than in R/.
#
# Everything here is a pure function of its arguments — no network, no I/O — so
# it can be asserted offline. See scripts/test_lib.R.

# Which EDH probe outcomes are worth another attempt.
#
# Status 0 stands for a connection-level failure (DNS, TLS, timeout).
#
# 401 is deliberately absent: retrying a rejected credential only delays the
# report. 403 IS present, which is not the textbook reading — a 403 normally
# means "and it will still be 403 next time". EDH has been observed refusing
# transiently: run 34119315556 died on a 403 at 12:00 UTC on 2026-09-07, and a
# re-dispatch on the same commit and the same secret returned 200 five hours
# later (#82). One blip should not cost a red run and an auto-filed issue.
edh_retryable <- function(status) {
  status == 0L || status %in% c(403L, 408L, 429L) || status >= 500L
}

# What a terminal status actually means.
#
# This is the substance of #83: the probe used to collapse every status >= 400
# into "EDH rejected the token", so a 403 sent the reader off to rotate a secret
# that was in perfect health. The three 4xx cases need three different actions,
# and the message is the only place that difference can be expressed.
edh_diagnosis <- function(status) {
  if (status == 0L) {
    "could not reach the host (DNS, TLS or timeout)."
  } else if (status == 401L) {
    "credential rejected. Rotate the EDH_TOKEN secret."
  } else if (status == 403L) {
    paste0("authenticated but refused — this is NOT a bad token. Check the ",
           "free-tier download quota (it resets at midnight on the 1st) before ",
           "rotating anything. This status has also been transient before, so ",
           "a re-run is worth one attempt.")
  } else if (status == 404L) {
    paste0("not found. The probe URL pins a specific .zarr/.zmetadata path on ",
           "EDH, which may have moved.")
  } else if (status >= 500L) {
    "EDH server error — their side, not ours."
  } else {
    "unexpected status."
  }
}
