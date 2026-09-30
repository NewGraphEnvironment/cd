devtools::load_all(quiet = TRUE)
vs <- c("a", "b", "a) (b")
sfx <- function(l) as.vector(outer(l, vs, function(x, v) paste0(x, " (", v, ")")))
labs <- unique(c("Q", sfx("Q"), sfx(sfx("Q"))))
pairs <- expand.grid(v = vs, l = labs, stringsAsFactors = FALSE)
n_abort <- 0; n_bad <- 0; n <- 0; max_used <- 0
for (k in 1:4) {
  cmb <- utils::combn(nrow(pairs), k)
  for (j in seq_len(ncol(cmb))) {
    p <- pairs[cmb[, j], ]
    n <- n + 1
    out <- tryCatch(label_disambiguate(p$v, p$l), error = function(e) NULL)
    if (is.null(out)) { n_abort <- n_abort + 1; next }
    u <- unique(data.frame(v = p$v, l = out))
    if (anyDuplicated(u$l) && any(duplicated(u$l) & !duplicated(u[c("l")]) | TRUE) && any(tapply(u$v, u$l, function(z) length(unique(z))) > 1)) { n_bad <- n_bad + 1; cat("SHARED\n") }
    # rows of one variable with one label keep one label (no split)
    if (nrow(u) != nrow(unique(p))) { n_merge <- get0("n_merge", ifnotfound = 0) + 1; if (n_merge == 1) print(cbind(p, out)) }
  }
}
cat("merged-within-variable:", get0("n_merge", ifnotfound = 0), "\n"); cat("sets:", n, " labels:", length(labs), " aborts:", n_abort, " violations:", n_bad, "\n")
