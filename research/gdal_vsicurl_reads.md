# Reading the published COGs over GDAL `/vsicurl/`

**Verified:** 2026-10-07 · **Issues:** #119 (spawned it), #37 (first used `CPL_VSIL_CURL_NON_CACHED`) · **Produced by:** probes during #119's code-check: local `python3 -m http.server`, terra (GDAL 3.13.0) and sf (GDAL 3.8.5), and dry runs against `s3://stac-era5-land`. Method and raw output are in `planning/archive/2026-10-issue-119-partial-sync/` (`findings.md`, `review-round2.md`, `review-round3.md`).

How GDAL behaves when the producer re-reads the bucket's own COGs within one R
process. It matters to anything that reads a COG, changes it on S3, and reads it
again, or that retries a failed read.

## Which GDAL

One R session can hold two: on the dev Mac, terra links **3.13.0** and sf links
**3.8.5**. CI (`ubuntu-latest`, 24.04) runs terra against the system **3.8.4**. A
behaviour seen through terra locally is therefore not CI's. Probe 3.8 through
`sf::gdal_utils("info", ...)`.

## The cache holds failures, and a retry sends nothing

GDAL keeps per-process state for each `/vsicurl/` URL: file properties, byte regions,
and, on **3.8**, a failed open. A second open of the same URL in the same process
answers from that state without a request:

```
server down, open a.tif:          FAIL
server up, open a.tif again:      FAIL      <- cached failure (3.8.5)
server up, open b.tif (fresh URL): ok
CPL_VSIL_CURL_NON_CACHED set, a:  ok
```

On 3.13 a refused connection is not cached, so a retry loop looks fine locally and
does nothing on CI. A 5xx that outlasts GDAL's own retries is cached on **both**
versions. Successful opens cache headers too: rewrite an object and re-read it, and
the old band list comes back (1955 instead of 1957 in the probe) until the cache is
cleared.

## `CPL_VSIL_CURL_NON_CACHED` does not do what its name says

- **On 3.8 it does not bypass the cache.** A handle on a matching URL still reads
  cached entries; the setting makes the handle *clear* that URL's entries when it
  closes. It works for an open because GDAL stats a `/vsicurl/` path before opening
  it: the stat's handle clears the stale or failed entry, and the open then goes to
  the network. A read that is not preceded by a stat would still meet the stale
  entry. This is from reading the v3.8.4 source (3.9 to 3.11 behave the same) and is
  an internal detail, not a documented contract.
- **The value is split on `:`**, so `/vsicurl/https://bucket...` becomes the prefix
  `/vsicurl/https`, which matches every https read. Set up front, it took 59 header
  reads from **20 s to 236 s**.
- So switch it on only after a read fails, and leave it on for the rest of the run
  (`pipeline_update_edh.R`, `uncache()`).

## Other measured facts

- `GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR` halved the 59 header reads, **41 s to
  20 s**. Without it GDAL probes `.aux.xml`/`.ovr` sidecars per file, and this bucket
  answers them 403 (it has no anonymous ListBucket).
- A query string on the URL (`?attempt=2`) gives a fresh cache key, and S3 serves
  the same object (same ETag). But GDAL then tries other drivers: **76 `.shx file is
  unreadable` warnings per read**, one per band. Not a usable cache-buster.
- GDAL sets no total timeout on a `/vsicurl/` request by default. `GDAL_HTTP_TIMEOUT`
  bounds each request, not the read. GDAL 3.8 also retries timeouts, so a bucket that
  stalls every request costs about 13 min per COG with `MAX_RETRY=3`.
- GDAL 3.8's own retry covers 429, 502-504 and timeouts. It does not cover 501, 505
  and above, or Linux libcurl's "Connection reset by peer".
- `curl::curl_download()` raises on 4xx/5xx and leaves no file (it writes to a
  `.curltmp` first), so a failed copy cannot leave a partial COG to be synced.
