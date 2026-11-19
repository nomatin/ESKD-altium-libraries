"""Thin wrapper around the ngspice-44 shared library shipped with KiCad 9.

Only the engine plumbing lives here; every acceptance threshold, every
measurement and every pass/fail decision lives in the caller.

A failed ``ngSpice_Circ()`` leaves the DLL in an unrecoverable state
("ngspice.dll cannot recover and awaits to be reset or detached"), therefore
each deck runs in a short-lived child process that re-executes this file as
``--worker``.

Engine: ``C:/Program Files/KiCad/9.0/bin/ngspice.dll`` (ngspice-44).  No
``ngspice.exe`` is installed on this machine, so the CDLL bridge is used.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

KICAD_BIN = Path("C:/Program Files/KiCad/9.0/bin")
DLL = KICAD_BIN / "ngspice.dll"


# --------------------------------------------------------------------------- #
# worker side
# --------------------------------------------------------------------------- #
def _worker(job_path: Path, out_path: Path) -> int:
    import ctypes as C

    job = json.loads(job_path.read_text(encoding="utf8"))
    os.add_dll_directory(str(KICAD_BIN))
    lib = C.CDLL(str(DLL))

    log: list[str] = []
    send_t = C.CFUNCTYPE(C.c_int, C.c_char_p, C.c_int, C.c_void_p)

    @send_t
    def send(text, ident, user):
        log.append(text.decode("utf8", "replace"))
        return 0

    lib.ngSpice_Init.argtypes = [C.c_void_p] * 7
    lib.ngSpice_Init(send, send, None, None, None, None, None)
    lib.ngSpice_Circ.argtypes = [C.POINTER(C.c_char_p)]
    lib.ngSpice_Command.argtypes = [C.c_char_p]

    class Vec(C.Structure):
        _fields_ = [
            ("name", C.c_char_p),
            ("type", C.c_int),
            ("flags", C.c_short),
            ("real", C.POINTER(C.c_double)),
            ("complex", C.POINTER(C.c_double)),
            ("length", C.c_int),
        ]

    lib.ngGet_Vec_Info.argtypes = [C.c_char_p]
    lib.ngGet_Vec_Info.restype = C.POINTER(Vec)

    deck = job["deck"]
    argv = (C.c_char_p * (len(deck) + 1))(*[s.encode() for s in deck], None)
    rc = lib.ngSpice_Circ(argv)

    analyses = []
    vectors: dict[str, list] = {}
    if rc == 0:
        for cmd in job["commands"]:
            parts = cmd.split(None, 1)
            if parts[0] in ("op", "ac", "tran", "dc", "noise"):
                analyses.append(cmd)
            err = lib.ngSpice_Command(cmd.encode())
            if err:
                analyses.append("FAILED: " + cmd)
        for name in job["vectors"]:
            ptr = lib.ngGet_Vec_Info(name.encode())
            if not ptr or not ptr.contents.length:
                vectors[name] = None
                continue
            v = ptr.contents
            n = v.length
            if v.complex:
                vectors[name] = {
                    "kind": "complex",
                    "re": [v.complex[2 * i] for i in range(n)],
                    "im": [v.complex[2 * i + 1] for i in range(n)],
                }
            else:
                vectors[name] = {
                    "kind": "real",
                    "re": [v.real[i] for i in range(n)],
                    "im": [0.0] * n,
                }

    out_path.write_text(json.dumps({"rc": rc, "log": log,
                                    "analyses": analyses,
                                    "vectors": vectors}), encoding="utf8")
    return 0


# --------------------------------------------------------------------------- #
# caller side
# --------------------------------------------------------------------------- #
class SimError(RuntimeError):
    pass


def simulate(deck, commands, vectors, timeout=180, title="ldk"):
    """Run one SPICE deck.

    deck      -- list of netlist lines; '.end' is appended automatically
    commands  -- analyses, e.g. ["op"], ["tran 1u 5m"]
    vectors   -- names to read back, e.g. ["out", "i(vin)"]
    """
    if not DLL.is_file():
        raise SimError("ngspice.dll not found: %s" % DLL)
    deck = [title] + [l for l in deck if l.strip().lower() != ".end"] + [".end"]
    with tempfile.TemporaryDirectory(prefix="ldk_ngb_") as tmp:
        job = Path(tmp) / "job.json"
        out = Path(tmp) / "out.json"
        job.write_text(json.dumps({"deck": deck, "commands": commands,
                                   "vectors": vectors}), encoding="utf8")
        proc = subprocess.run(
            [sys.executable, "-u", str(Path(__file__).resolve()),
             "--worker", str(job), str(out)],
            capture_output=True, text=True, timeout=timeout,
        )
        if not out.is_file():
            raise SimError(
                "ngspice worker produced no result (exit %s)\nSTDOUT:\n%s\nSTDERR:\n%s"
                % (proc.returncode, proc.stdout[-4000:], proc.stderr[-4000:]))
        return json.loads(out.read_text(encoding="utf8"))


def real(res, name):
    v = res["vectors"].get(name)
    if not v:
        raise SimError("vector missing: %s\n%s"
                       % (name, "\n".join(res["log"][-20:])))
    return v["re"][0]


def trace(res, name):
    v = res["vectors"].get(name)
    if not v:
        raise SimError("vector missing: %s" % name)
    return v["re"]


def errors(res):
    """Simulator messages that indicate a real problem (not warnings)."""
    bad = []
    for line in res["log"]:
        low = line.lower()
        if ("error" in low or "singular matrix" in low or "no convergence" in low
                or "fatal" in low):
            bad.append(line.strip())
    bad.extend(a for a in res["analyses"] if a.startswith("FAILED"))
    return bad


def require(res, what=""):
    if res["rc"] != 0:
        raise SimError("netlist rejected (%s):\n%s"
                       % (what, "\n".join(res["log"][-25:])))
    errs = errors(res)
    if errs:
        raise SimError("simulation errors (%s):\n%s"
                       % (what, "\n".join(errs[:10])))
    return res


if __name__ == "__main__" and "--worker" in sys.argv:
    i = sys.argv.index("--worker")
    raise SystemExit(_worker(Path(sys.argv[i + 1]), Path(sys.argv[i + 2])))
