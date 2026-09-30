# Plan review (#101) — Plan agent, 2026-09-30

Delivered as reply text (Plan agents cannot write files); recorded here.

No blockers. Tests confirmed failing on HEAD and passing with the fix.

1. **Assumption — factor input returns character.** `character()` template makes vctrs
   combine chr + factor to chr; HEAD kept factors (expand.grid keeps them). Fix: build
   the template from `combos$variable[0]`, `combos$period[0]`. **Probed: confirmed.**
2. **Assumption — `slope`/`intercept` named on non-empty rows only** (`"yr"`,
   `"Intercept"` from `zyp.sen`). Predates #101, but blocks a ptype-identity test.
   Fix: `unname()`. **Probed: confirmed (`Named num`).**
3. **Gap — `trend_start = NULL` gives 0 x 7 with no `trend_start` column**, breaking
   the `@return` "same columns" promise. **Probed: confirmed.**
4. **Gap — no test pins that empty and non-empty share one ptype.**
5. **Gap — two new cd_trend tests lack `skip_if_not_installed("Kendall"/"zyp")`**,
   which every test since #92 carries.

Consumers: nothing in R/, vignettes/, data-raw/, scripts/ relies on the 0x0 shape;
vignette loops filter then check `nrow(sub) == 0`, which works on both shapes.
