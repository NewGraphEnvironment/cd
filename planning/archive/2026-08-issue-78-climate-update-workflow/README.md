## Outcome

The Monthly Climate Data Update workflow had failed on every scheduled run since
April, and the cause turned out to be four independent defects stacked on top of
each other. `setup-r-dependencies@v2` had no `extra-packages`, so cd's
dependencies installed but cd did not, and `pipeline_update_edh.R` fell through
to a `devtools::load_all()` that wasn't on the runner — the job died at package
load, before it ever checked for new data. The default `GITHUB_TOKEN` was
read-only, so the log-commit step 403'd. That step was dead code regardless:
`logs/*.log` is gitignored, so it staged nothing and only ever reached `git push`
— which 403s during `git-receive-pack` ref advertisement even with nothing to
push. Granting `contents: write` would have "repaired" a step that could never
commit anything, so it was replaced with an artifact upload and the token stayed
`contents: read`. Then the new dry-run probe found the fourth: the `EDH_TOKEN`
repo secret has been stale since 2026-04-14, exactly the date of the last green
run. Even with the first three fixed, the live run would still have died — six
hours later at the EDH fetch instead of four seconds in at the probe.

The QA layer is the durable part. `--dry-run` / `CD_DRY_RUN` runs credential
probes, reads the STAC catalog and computes the target year, then exits before
any fetch or publish. Deliberately not a no-write mode: it round-trips a sentinel
object under `_healthcheck/`, because `aws sts get-caller-identity` proves the
keys parse and says nothing about whether the bucket is writable, which is the
exact class of failure that took this workflow down. A weekly cron runs it as a
heartbeat, which also keeps GitHub from auto-disabling the schedule after 60 days
of repo inactivity. Any failure opens a tracking issue, or comments on the open
one, deduped by label — team-visible and durable, unlike watch-emails that go
only to the actor. Two acceptance dispatches confirmed the whole chain including
the dedup path, and the alarm's first real customer was Bug 4 itself.

Worth remembering: EDH's HTTP Basic auth needs `httpauth = 1L` on the curl
handle, since libcurl waits for a `WWW-Authenticate` challenge EDH never sends;
and credentials belong on the handle rather than in the URL, both because the
104-character token isn't URL-encoded and because it keeps the token out of
anything loggable.

**Left open for the repo owner:** rotate `EDH_TOKEN` (`gh secret set EDH_TOKEN`).
The sandbox refused to let the agent overwrite shared CI credential material,
correctly. Until that lands, the live publish path stays unproven — it is
unchanged by this work, but cannot be exercised. If DestinE tokens are
short-lived this will recur, and the weekly heartbeat is what catches it.

Closed by: PR for #78 (commits 62256d5, 041f16e, ca4e41e, 0f4a3cc)
