"""Run the seven standalone Spice Sifter tests sequentially and archive artifacts.

The Spice Tester tool is used read-only; every file this driver writes lives in
this run's spice/results/ directory.  MixedSim runs must not overlap, so the
seven tests are executed one after another.
"""
from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
SPICE = HERE.parent
RESULTS = SPICE / "Results"
TOOL = pathlib.Path(r"C:/Users/Nomatin/projects/Spice Tester/spice_sifter.py")
TESTS = [
    "sifter_ldk220_fixed.json",
    "sifter_ldk220_adj.json",
    "sifter_ldk220_sot89.json",
    "sifter_ldk320_fixed.json",
    "sifter_ldk320_adj.json",
    "sifter_ldk320_sot89_std.json",
    "sifter_ldk320_sot89_d.json",
]

started = time.time()
RESULTS.mkdir(parents=True, exist_ok=True)
summary = {"kind": "standalone_spice_sifter", "tool": str(TOOL),
           "simulator": "Altium MixedSim 24.4.1.13 (standalone SPICE mode)",
           "tests": [], "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

for name in TESTS:
    test = HERE / name
    stem = test.stem
    print("... sifter %s" % stem, flush=True)
    proc = subprocess.run(
        [sys.executable, str(TOOL), str(test), "--keep-files",
         "--timeout", "180", "--verbose"],
        cwd=TOOL.parent, capture_output=True, text=True, timeout=300,
    )
    try:
        report = json.loads(proc.stdout)
    except Exception:
        report = {"status": "ERROR", "error": {
            "code": "REPORT_NOT_JSON",
            "message": proc.stdout[-2000:] or proc.stderr[-2000:]}}
    (RESULTS / (stem + "_report.json")).write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    artifacts = {}
    src = report.get("artifacts")
    if isinstance(src, str) and pathlib.Path(src).is_dir():
        src_dir = pathlib.Path(src)
        for f, suffix in (("test.nsx", ".nsx"), ("test.sdf", ".sdf"),
                          ("run.log", "_run.log")):
            s = src_dir / f
            if s.is_file():
                d = RESULTS / (stem + suffix)
                shutil.copyfile(s, d)
                artifacts[suffix.strip("_")] = d.name
    checks = report.get("checks") or []
    row = {"test": name, "name": report.get("test"),
           "status": report.get("status"), "returncode": proc.returncode,
           "error": report.get("error"),
           "values": [c.get("value") for c in checks],
           "artifacts": artifacts,
           "report": stem + "_report.json"}
    summary["tests"].append(row)
    print("    %s %s rc=%s" % (row["status"], row["values"], row["returncode"]),
          flush=True)

summary["checks_total"] = sum(len((json.loads((RESULTS / r["report"]).read_text(
    encoding="utf-8")).get("checks") or [])) for r in summary["tests"])
summary["passed"] = sum(1 for r in summary["tests"] if r["status"] == "PASS")
summary["failed"] = sum(1 for r in summary["tests"] if r["status"] == "FAIL")
summary["errors"] = sum(1 for r in summary["tests"] if r["status"] == "ERROR")
summary["status"] = ("PASS" if summary["passed"] == len(TESTS)
                     else ("FAIL" if summary["failed"] else "ERROR"))
summary["duration_s"] = round(time.time() - started, 1)
(RESULTS / "sifter_ldk_summary.json").write_text(
    json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print("%d/%d Sifter tests PASS, %d FAIL, %d ERROR (%.1f s)"
      % (summary["passed"], len(TESTS), summary["failed"],
         summary["errors"], summary["duration_s"]))
sys.exit(0 if summary["status"] == "PASS" else 1)
