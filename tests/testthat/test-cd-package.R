test_that("%||% comes from rlang, so cd runs on R < 4.4 (#130)", {
  # Base R exports %||% only from 4.4.0 and DESCRIPTION allows 4.1, so on a
  # newer R a missing import goes unnoticed: base's copy answers instead.
  # One list entry per importFrom() line, all named "rlang", so read them all.
  imports <- getNamespaceImports("cd")
  expect_true("%||%" %in% unlist(imports[names(imports) == "rlang"]))
})
