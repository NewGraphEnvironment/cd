# /// script
# dependencies = ["jsonschema", "requests"]
# ///
"""Check that new catalog/manifest differ from the old only by the #128 rename.

Usage: uv run compare_128.py OLD_CATALOG NEW_CATALOG OLD_MANIFEST NEW_MANIFEST
"""
import json
import re
import sys

import jsonschema
import requests

old_cat, new_cat, old_mf, new_mf = (json.load(open(p)) for p in sys.argv[1:5])
problems = []
RUN = "https://github.com/NewGraphEnvironment/cd/actions/runs/"


def prov_ok(where, old, new):
    """Old cd:* keys map exactly onto the new processing:* keys."""
    if new.get("processing:version") != old.get("cd:version"):
        problems.append(f"{where}: version {new.get('processing:version')} != {old.get('cd:version')}")
    if new.get("processing:software") != {"cd": old.get("cd:sha")}:
        problems.append(f"{where}: software {new.get('processing:software')} != cd:sha {old.get('cd:sha')}")
    if new.get("processing:datetime") != old.get("cd:run_time"):
        problems.append(f"{where}: datetime {new.get('processing:datetime')!r} != {old.get('cd:run_time')!r}")
    left = [k for k in new if k.startswith("cd:") and k not in ("cd:variable", "cd:period")]
    if left:
        problems.append(f"{where}: old keys remain {left}")


def link_ok(where, run_id, links):
    want = [{"rel": "processing-execution", "href": RUN + run_id, "type": "text/html"}] \
        if run_id and re.fullmatch(r"[0-9]+", run_id) else []
    if (links or []) != want:
        problems.append(f"{where}: links {links} != {want}")


# -- catalog ------------------------------------------------------------------
old_items = {i["id"]: i for i in old_cat["items"]}
new_items = {i["id"]: i for i in new_cat["items"]}
if set(old_items) != set(new_items):
    problems.append(f"catalog item sets differ: {set(old_items) ^ set(new_items)}")
for k in sorted(set(old_items) & set(new_items)):
    o, n = old_items[k], new_items[k]
    if o["assets"] != n["assets"]:
        problems.append(f"{k}: assets differ")
    if o["bbox"] != n["bbox"]:
        problems.append(f"{k}: bbox differs")
    for f in ("cd:variable", "cd:period", "start_datetime", "end_datetime", "datetime"):
        if o["properties"].get(f) != n["properties"].get(f):
            problems.append(f"{k}: {f} differs")
    prov_ok(k, o["properties"], n["properties"])
    link_ok(k, o["properties"].get("cd:run_id"), n["links"])

schemas = {u: requests.get(u, timeout=30).json() for u in (
    "https://stac-extensions.github.io/processing/v1.2.0/schema.json",
    "https://stac-extensions.github.io/file/v2.1.0/schema.json",
)}
for k, n in new_items.items():
    for u, s in schemas.items():
        if u not in n["stac_extensions"]:
            problems.append(f"{k}: does not declare {u}")
            continue
        try:
            jsonschema.validate(n, s)
        except jsonschema.ValidationError as e:
            problems.append(f"{k}: {u.split('/')[3]} schema: {e.message}")

# -- manifest -----------------------------------------------------------------
of, nf = old_mf["files"], new_mf["files"]
if list(of) != list(nf):
    problems.append("manifest file lists differ (or reorder)")
for k in sorted(set(of) & set(nf)):
    o, n = of[k], nf[k]
    for f in ("file:checksum", "file:size"):
        if o.get(f) != n.get(f):
            problems.append(f"{k}: {f} differs")
    prov_ok(k, o, n)
    link_ok(k, o.get("cd:run_id"), n.get("links"))
    extra = set(n) - {"file:checksum", "file:size", "processing:version",
                      "processing:software", "processing:datetime", "links"}
    if extra:
        problems.append(f"{k}: unexpected keys {extra}")

print(f"catalog: {len(new_items)} items; manifest: {len(nf)} entries")
print(f"{len(problems)} problem(s)")
for p in problems[:20]:
    print("  -", p)
sys.exit(1 if problems else 0)
