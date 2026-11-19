"""TZ v1.1 section 6.3 -- independent ngspice acceptance suite for the
STMicroelectronics LDK220 / LDK320 datasheet model.

Test subject
------------
``../MY_LIB_LDK_REGULATORS_DS.ckt``

Stimuli and acceptance criteria are derived *independently* from
``ldk_spec.json`` and from the two ST datasheets:

    LDK220  DS10219 Rev 7 (November 2021)  Tables 6 / 7, Figures 14 and 23
    LDK320  DS11321 Rev 13 (June 2025)     Tables 6 / 7, Figures 13 and 22

The developer sanity check ``_dev_sanity.py`` / ``_dev_sanity.json`` in
``spice/work`` was NOT read or reused; every threshold below is either the
datasheet number itself or a documented engineering window around a datasheet
*typical* value (those are flagged ``basis="engineering"``).

Engine
------
ngspice-44 from the KiCad 9.0 shared library (no ngspice.exe on this machine),
driven through ``ngspice_bridge.py`` (one child process per deck).

Test bench
----------
Every instance sits between a local "board" ground ``ret`` and the model's own
ground pin, which is tied to node 0 through the 0 V source ``VG``::

    VG  ret 0  0          <- carries exactly the DUT ground current
    VIN vin ret <VIN>
    RL  out ret <RLOAD>
    X1  vin 0 en out <model> PARAMS: VNOM=...

With that topology ``IQ = -I(VG)`` is exact and independent of the load type,
which makes the quiescent-current checks independent of the model's internal
numerical aids (the 100 kOhm load and its compensating source cancel at the
terminals).

One measurement point per deck.  Mixing a short-circuit instance (VOUT = 4 mV)
with a 12 V instance in one .op deck makes ngspice-44 fall back to its
transient operating point and return non-physical values, so every point is
simulated on its own.  Any deck that still needs that fallback is flagged.

Loads are resistors, not ideal current sinks.  A stiff current sink drives the
LDK320 fixed subcircuits into a non-converging operating point (reported as a
finding); resistors converge everywhere.  The load current is read back from
V(OUT)/R, so the load-regulation limit is scaled by the *measured* current
step.

Dropout is measured the way the datasheet defines it: VIN is swept with
``.dc`` and VDROP is ``VIN - VOUT`` at the point where VOUT is exactly 100 mV
below nominal, with the load resistor sized so that the output current at that
point is the datasheet test current.

Outputs
-------
``../Results/ngspice_ldk_acceptance.json``   every measurement and verdict
``../Results/ngspice_ldk_acceptance.log``    ngspice log of every deck
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
SPICE = HERE.parent
MODEL = SPICE / "MY_LIB_LDK_REGULATORS_DS.ckt"
SPEC = HERE / "ldk_spec.json"
RESULTS = SPICE / "Results"

sys.path.insert(0, str(HERE))
import ngspice_bridge as B  # noqa: E402

SUBCKTS = [
    "MY_LIB_LDK220_FIXED_DS",
    "MY_LIB_LDK220_ADJ_DS",
    "MY_LIB_LDK220_SOT89_DS",
    "MY_LIB_LDK320_FIXED_DS",
    "MY_LIB_LDK320_ADJ_DS",
    "MY_LIB_LDK320_SOT89_STD_DS",
    "MY_LIB_LDK320_SOT89_D_DS",
]

PORTS = {
    "MY_LIB_LDK220_FIXED_DS": ["IN", "GND", "EN", "OUT"],
    "MY_LIB_LDK220_ADJ_DS": ["IN", "GND", "EN", "ADJ", "OUT"],
    "MY_LIB_LDK220_SOT89_DS": ["OUT", "GND", "IN"],
    "MY_LIB_LDK320_FIXED_DS": ["IN", "GND", "EN", "OUT"],
    "MY_LIB_LDK320_ADJ_DS": ["IN", "GND", "EN", "ADJ", "OUT"],
    "MY_LIB_LDK320_SOT89_STD_DS": ["OUT", "GND", "IN"],
    "MY_LIB_LDK320_SOT89_D_DS": ["GND", "IN", "OUT"],
}

HAS_EN = {"MY_LIB_LDK220_FIXED_DS", "MY_LIB_LDK220_ADJ_DS",
          "MY_LIB_LDK320_FIXED_DS", "MY_LIB_LDK320_ADJ_DS"}

CHECKS: list[dict] = []
LOG: list[str] = []
FALLBACKS: list[dict] = []


# --------------------------------------------------------------------------- #
# bookkeeping
# --------------------------------------------------------------------------- #
def record(check_id, variant, group, value, low, high, unit, source,
           basis="datasheet", note=None):
    ok = value is not None and low <= value <= high
    CHECKS.append({
        "id": check_id, "variant": variant, "group": group,
        "value": None if value is None else float("%.12g" % value),
        "min": low, "max": high, "unit": unit, "pass": ok,
        "reason": None if ok else ("measurement missing" if value is None
                                   else "outside window"),
        "source": source, "basis": basis, "note": note,
    })
    return ok


def g(x):
    return "%.10g" % x


def model_lines():
    return [l for l in MODEL.read_text(encoding="utf-8").splitlines()
            if l.strip().upper() != ".END"]


def simulate(deck, commands, vectors, label):
    res = B.simulate(list(deck) + model_lines(), commands, vectors)
    LOG.append("### %s\n%s\n" % (label, "\n".join(res["log"])))
    if any("optran" in l.lower() for l in res["log"]):
        FALLBACKS.append({"deck": label, "note": "ngspice used its transient "
                          "operating-point fallback (gmin and source stepping "
                          "failed)"})
    return res


def get(res, name):
    try:
        return B.real(res, name)
    except B.SimError:
        return None


# --------------------------------------------------------------------------- #
# bench construction
# --------------------------------------------------------------------------- #
def build(tag, sub, vin, ven=None, rload=None, iinj=None, r1=None, r2=None,
          vnom=None, vref=None):
    """One DUT instance between the local board ground ``ret`` and node 0."""
    n = {k: "%s_%s" % (k, tag) for k in ("vin", "en", "out", "adj")}
    deck = ["* --- %s ---" % tag,
            "VG_%s ret_%s 0 0" % (tag, tag),
            "VIN_%s %s ret_%s %s" % (tag, n["vin"], tag, g(vin)),
            "CIN_%s %s ret_%s 1u" % (tag, n["vin"], tag),
            "COUT_%s %s ret_%s 1u" % (tag, n["out"], tag)]
    if sub in HAS_EN:
        deck.append("VEN_%s %s ret_%s %s"
                    % (tag, n["en"], tag, g(5.0 if ven is None else ven)))
    if r1 is not None:
        deck.append("R1_%s %s %s %s" % (tag, n["out"], n["adj"], g(r1)))
    if r2 is not None:
        deck.append("R2_%s %s ret_%s %s" % (tag, n["adj"], tag, g(r2)))
    if rload is not None:
        deck.append("RL_%s %s ret_%s %s" % (tag, n["out"], tag, g(rload)))
    if iinj is not None:
        deck.append("IINJ_%s ret_%s %s %s" % (tag, tag, n["out"], g(iinj)))

    nodes = [{"IN": n["vin"], "GND": "0", "EN": n["en"],
              "ADJ": n["adj"], "OUT": n["out"]}[p] for p in PORTS[sub]]
    call = "X%s %s %s" % (tag, " ".join(nodes), sub)
    params = []
    if vnom is not None:
        params.append("VNOM=%s" % g(vnom))
    if vref is not None:
        params.append("VREF=%s" % g(vref))
    if params:
        call += " PARAMS: " + " ".join(params)
    deck.append(call)
    return deck, n


def point(label, sub, vectors, **kwargs):
    """Run one .op measurement point and return the requested vectors."""
    deck, n = build("p", sub, **kwargs)
    res = simulate(deck, ["op"], ["%s_p" % v for v in vectors]
                   + ["i(vg_p)", "p.soft"], label)
    if res["rc"] != 0:
        return None
    out = {v: get(res, "%s_p" % v) for v in vectors}
    out["iq"] = get(res, "i(vg_p)")
    out["soft"] = get(res, "p.soft")
    return out


# --------------------------------------------------------------------------- #
# spec derived limits
# --------------------------------------------------------------------------- #
def is_adj(v):
    return v["vout_type"] == "adjustable"


def accuracy_pct(v):
    return float(v["accuracy_25c_pct"])


def target_out(v):
    if is_adj(v):
        return float(v["vadj_nom_v"]) * 2.8
    return float(v["vout_nom_v"])


def vin_nom(v):
    return max(target_out(v) + 1.0, 2.5)


def load_reg_max_pct_per_ma(v):
    if v["series"] == "LDK220":
        return 0.003
    return 0.004 if v["package_short"] == "SOT-89" else 0.003


def load_reg_typ_pct_per_ma(v):
    return 0.0002 if is_adj(v) else 0.001


def load_reg_max_mv(v):
    return 25.0 if v["package_short"] == "SOT-89" else 15.0


# --------------------------------------------------------------------------- #
# static operating points
# --------------------------------------------------------------------------- #
def op_block(v):
    cid = v["id"]
    sub = v["spice_model"]
    adj = is_adj(v)
    vref = float(v["vadj_nom_v"]) if adj else None
    fixed = None if adj else float(v["vout_nom_v"])
    acc = accuracy_pct(v)
    target = target_out(v)
    vin = vin_nom(v)
    base = dict(vnom=fixed, vref=vref)
    div = dict(r1=18e3, r2=10e3) if adj else {}

    out = {"id": cid, "mpn": v["mpn"], "subckt": sub,
           "package": v["package_short"], "vout_type": v["vout_type"],
           "measurements": {}}
    before = len(CHECKS)
    label = "%s %s" % (cid, v["mpn"])

    def add(suffix, group, value, low, high, unit, source, basis="datasheet",
            note=None):
        ok = record("%s:%s" % (cid, suffix), cid, group, value, low, high,
                    unit, source, basis, note)
        out["measurements"][suffix] = {
            "value": None if value is None else float("%.12g" % value),
            "min": low, "max": high, "unit": unit, "pass": ok}
        return ok

    # A. output accuracy at IOUT = 1 mA -------------------------------------
    p = point(label + " nom", sub, ["out"], vin=vin, rload=target / 1e-3,
              **div, **base)
    v1 = None if p is None else p["out"]
    if adj:
        src = ("LDK220/320 Table 7, VADJ accuracy %.1f %% at TJ = 25 C; "
               "VOUT = VREF*(1+R1/R2) with R1 = 18k, R2 = 10k" % acc)
    else:
        src = ("Table 6, VOUT accuracy %.1f %% at TJ = 25 C, VIN = VOUT+1 V, "
               "IOUT = 1 mA" % acc)
    add("A_vout_1ma", "accuracy", v1, target * (1 - acc / 100),
        target * (1 + acc / 100), "V", src,
        note="nominal %.6f V at VIN = %.3f V" % (target, vin))

    if adj:
        p = point(label + " vref", sub, ["out"], vin=max(vref + 1.0, 2.5),
                  rload=vref / 1e-3, r1=1e-3, **base)
        add("A_vref_open_divider", "accuracy", None if p is None else p["out"],
            vref * (1 - acc / 100), vref * (1 + acc / 100), "V",
            "Table 7, VADJ accuracy %.1f %%; R1 = 0, R2 open -> VOUT = VREF"
            % acc, note="VREF nominal %.4f V" % vref)

    # B. load regulation 1 mA -> 200 mA -------------------------------------
    p2 = point(label + " ld200", sub, ["out"], vin=vin, rload=target / 0.2,
               **div, **base)
    v2 = None if p2 is None else p2["out"]
    if v1 is not None and v2 is not None:
        r1, r2 = target / 1e-3, target / 0.2
        i1, i2 = v1 / r1, v2 / r2
        di_ma = (i2 - i1) * 1e3
        d = v1 - v2
        if not adj and target <= 2.0:
            lim = load_reg_max_mv(v)
            add("B_load_reg", "load_regulation", d * 1e3, 0.0, lim, "mV",
                "LDK320 Table 6, static load regulation, VOUT <= 2 V: %.0f mV "
                "max over IOUT = 1..200 mA" % lim,
                note="measured current step %.2f mA" % di_ma)
        else:
            lim = load_reg_max_pct_per_ma(v) * di_ma * target / 100.0
            typ = load_reg_typ_pct_per_ma(v) * di_ma * target / 100.0
            add("B_load_reg", "load_regulation", d, 0.0, lim, "V",
                "Table 6/7, static load regulation %.4f %%/mA max over the "
                "measured %.1f mA step (= %.3f mV); typical %.4f %%/mA "
                "(= %.3f mV)"
                % (load_reg_max_pct_per_ma(v), di_ma, lim * 1e3,
                   load_reg_typ_pct_per_ma(v), typ * 1e3),
                note="measured current step %.2f mA; a typical part would show "
                     "%.3f mV" % (di_ma, typ * 1e3))
            out["measurements"]["B_load_reg_vs_typ"] = {
                "typical_mv": typ * 1e3, "deviation_mv": (d - typ) * 1e3}
    else:
        add("B_load_reg", "load_regulation", None, 0.0, 1.0, "V",
            "Table 6/7, static load regulation")

    # C. dropout -------------------------------------------------------------
    if not adj and target in (3.3, 5.0):
        for suffix, iout, lo, hi in (("C_drop_100ma", 0.1, 0.060, 0.140),
                                     ("C_drop_200ma", 0.2, 0.150, 0.350)):
            vd = dropout(v, iout)
            add(suffix, "dropout", vd, lo, hi, "V",
                "Table 6/7, VDROP at IOUT = %d mA (VOUT = 3.3 V): 100 mV typ "
                "for 100 mA, 200 mV typ and 350 mV max for 200 mA"
                % int(iout * 1e3),
                basis="datasheet (lower bound engineering)" if iout < 0.2
                else "datasheet",
                note="VDROP = VIN - VOUT at the point where VOUT is exactly "
                     "100 mV below nominal (.dc sweep of VIN; the load "
                     "resistor is sized so the current there is %d mA)"
                     % int(iout * 1e3))

    # D. quiescent current ---------------------------------------------------
    for suffix, tag, rload, loaded in (
            ("D_iq_0ma", "iq0", None, False),
            ("D_iq_200ma", "iq200", target / 0.2, True)):
        p = point(label + " " + tag, sub, [], vin=vin, rload=rload, **div,
                  **base)
        q = None if p is None or p["iq"] is None else -p["iq"]
        typ = float(v["iq_200ma_typ_ua"] if loaded else v["iq_0ma_typ_ua"])
        mx = 100.0 if loaded else 90.0
        add(suffix, "quiescent", None if q is None else q * 1e6,
            0.80 * typ, min(1.20 * typ, mx), "uA",
            "Table 6/7, IQ at IOUT = %s: %.0f uA typ, %.0f uA max"
            % ("200 mA" if loaded else "0 mA", typ, mx),
            note="IQ = -I(VG), the current into the DUT ground pin; the window "
                 "is 0.8..1.2 x typical, additionally capped by the datasheet "
                 "maximum")

    # E. enable logic, off mode, active discharge ---------------------------
    if sub in HAS_EN:
        p = point(label + " off", sub, [], vin=vin, ven=0.0, **div, **base)
        q = None if p is None or p["iq"] is None else -p["iq"]
        typ_off = float(v["iq_off_typ_ua"])
        add("E_iq_off", "quiescent", None if q is None else q * 1e6,
            0.5 * typ_off, 1.0, "uA",
            "Table 6/7, VIN input current in off mode (VEN = GND): %.1f uA "
            "typ, 1.0 uA max" % typ_off,
            note="the lower bound 0.5 x typical is engineering; the upper "
                 "bound is the datasheet maximum")

        p = point(label + " enlo", sub, ["out"], vin=vin, ven=0.4,
                  rload=target / 1e-3, **div, **base)
        add("E_ven_0p4_off", "enable", None if p is None else p["out"],
            -0.05, max(0.05, 0.02 * target), "V",
            "Table 6/7, VEN logic low <= 0.4 V: regulator off",
            basis="datasheet (window engineering)",
            note="VOUT must collapse; the window (<= 2 % of nominal) is inside "
                 "the datasheet accuracy band")

        p = point(label + " enhi", sub, ["out"], vin=vin, ven=1.2,
                  rload=target / 1e-3, **div, **base)
        add("E_ven_1p2_on", "enable", None if p is None else p["out"],
            target * (1 - acc / 100), target * (1 + acc / 100), "V",
            "Table 6/7, VEN logic high >= 1.2 V: regulator on and inside the "
            "accuracy band")

        # no external divider here: it would dominate the 10 uA injection and
        # hide the 18 ohm discharge resistance
        p = point(label + " dis", sub, ["out"], vin=vin, ven=0.0, iinj=10e-6,
                  **base)
        vd = None if p is None else p["out"]
        rdis = None if vd is None else vd / 10e-6
        if v["series"] == "LDK220":
            add("F_rdis", "discharge", rdis, 14.0, 22.0, "ohm",
                "LDK220 Table 6/7, Rdis = 18 ohm typ at VEN = 0",
                basis="datasheet (window engineering)",
                note="Rdis = VOUT / 10 uA injected into OUT with VEN = 0")
        else:
            add("F_no_active_discharge", "discharge", rdis, 20e3, 1e12, "ohm",
                "LDK320 Table 6/7 contain no Rdis; the LDK320 has no active "
                "output discharge",
                basis="datasheet (absence)",
                note="equivalent resistance seen by a 10 uA injection with "
                     "VEN = 0; it must stay high (no 18 ohm pulldown)")

    # G. short circuit current ----------------------------------------------
    p = point(label + " isc", sub, ["out"], vin=4.3, rload=0.01, **div, **base)
    i_isc = None if p is None or p["out"] is None else p["out"] / 0.01
    if v["series"] == "LDK220":
        add("G_isc", "current_limit", None if i_isc is None else i_isc * 1e3,
            360.0, 440.0, "mA",
            "LDK220 Table 6/7, ISC (RL = 0): 400 mA typ",
            basis="datasheet (window engineering)",
            note="RL = 0.01 ohm, VIN = 4.3 V")
    else:
        add("G_isc_low_drop", "current_limit",
            None if i_isc is None else i_isc * 1e3, 300.0, 360.0, "mA",
            "LDK320 Table 6/7, ISC (RL = 0): 330 mA typ; VIN = 4.3 V is inside "
            "the flat part of the Figure 22 SOA curve",
            basis="datasheet (window engineering)", note="RL = 0.01 ohm")
        p = point(label + " isc16", sub, ["out"], vin=16.0, rload=0.01,
                  **div, **base)
        i16 = None if p is None or p["out"] is None else p["out"] / 0.01
        add("G_isc_vin16", "current_limit", None if i16 is None else i16 * 1e3,
            180.0, 220.0, "mA",
            "LDK320 Table 6/7, ISC at VIN = 16 V: 200 mA typ; Figure 22 SOA "
            "foldback", basis="datasheet (window engineering)",
            note="RL = 0.01 ohm, VIN = 16 V (inside the 18 V LDK320 operating "
                 "range)")

    out["checks"] = [c["id"] for c in CHECKS[before:]]
    out["status"] = "PASS" if all(c["pass"] for c in CHECKS[before:]) else "FAIL"
    return out


# --------------------------------------------------------------------------- #
# dropout by the datasheet definition
# --------------------------------------------------------------------------- #
def dropout(v, iout):
    sub = v["spice_model"]
    vnom = float(v["vout_nom_v"])
    limit = vnom - 0.1
    rload = limit / iout
    start, stop, step = vnom - 0.6, vnom + 0.4, 0.005
    deck, n = build("d", sub, 0.0, rload=rload, vnom=vnom)
    deck = [l for l in deck if not l.startswith("VIN_d ")]
    deck.insert(1, "VIN_d vin_d ret_d 0")
    res = simulate(deck, ["dc vin_d %s %s %s" % (g(start), g(stop), g(step))],
                   ["vin_d", "out_d"],
                   "%s %s dropout %d mA"
                   % (v["id"], v["mpn"], int(iout * 1e3)))
    if res["rc"] != 0:
        return None
    vin = B.trace(res, "vin_d")
    out = B.trace(res, "out_d")
    for i in range(1, len(out)):
        if out[i - 1] < limit <= out[i]:
            frac = (limit - out[i - 1]) / (out[i] - out[i - 1])
            vx = vin[i - 1] + frac * (vin[i] - vin[i - 1])
            return vx - limit
    return None


# --------------------------------------------------------------------------- #
# enable threshold sweep
# --------------------------------------------------------------------------- #
def enable_threshold(v):
    cid = v["id"]
    sub = v["spice_model"]
    vnom = float(v["vout_nom_v"])
    deck, n = build("e", sub, vin_nom(v), ven=0.0, rload=vnom / 1e-3,
                    vnom=vnom)
    res = simulate(deck, ["dc ven_e 0 2 0.002"], ["en_e", "out_e"],
                   "%s %s VEN sweep" % (cid, v["mpn"]))
    th = None
    if res["rc"] == 0:
        en = B.trace(res, "en_e")
        out = B.trace(res, "out_e")
        half = 0.5 * vnom
        for i in range(1, len(en)):
            if out[i - 1] < half <= out[i]:
                frac = (half - out[i - 1]) / (out[i] - out[i - 1])
                th = en[i - 1] + frac * (en[i] - en[i - 1])
                break
    record("%s:ven_threshold" % cid, cid, "enable", th, 0.4, 1.2, "V",
           "Table 6/7, VEN logic low <= 0.4 V and logic high >= 1.2 V; Figure "
           "14 (LDK220) / Figure 13 (LDK320) place the actual threshold "
           "between those limits",
           note="VEN at which VOUT crosses 50 % of nominal (dc sweep, 2 mV "
                "step)")
    return th


# --------------------------------------------------------------------------- #
# start-up transient
# --------------------------------------------------------------------------- #
def startup(v):
    cid = v["id"]
    sub = v["spice_model"]
    adj = is_adj(v)
    vref = float(v["vadj_nom_v"]) if adj else None
    vnom = None if adj else float(v["vout_nom_v"])
    target = target_out(v)
    vin = vin_nom(v)
    deck, n = build("s", sub, vin, rload=target / 1e-3,
                    r1=18e3 if adj else None, r2=10e3 if adj else None,
                    vnom=vnom, vref=vref)
    if sub in HAS_EN:
        deck = [l for l in deck if not l.startswith("VEN_s ")]
        deck.append("VEN_s en_s ret_s PULSE(0 %s 1m 1u 1u 100m 200m)" % g(vin))
    else:
        deck = [l for l in deck if not l.startswith("VIN_s ")]
        deck.append("VIN_s vin_s ret_s PWL(0 0 1m 0 1.001m %s 10m %s)"
                    % (g(vin), g(vin)))
    res = simulate(deck, ["tran 1u 3m"], ["time", "out_s", "en_s", "vin_s"],
                   "%s %s start-up" % (cid, v["mpn"]))
    if res["rc"] != 0:
        record("%s:ton90" % cid, cid, "startup", None, 0.0, 1e9, "us",
               "start-up transient")
        return None
    t = B.trace(res, "time")
    o = B.trace(res, "out_s")

    t0 = None
    if sub in HAS_EN:
        e = B.trace(res, "en_s")
        for i in range(1, len(e)):
            if e[i - 1] < 0.5 <= e[i]:
                frac = (0.5 - e[i - 1]) / (e[i] - e[i - 1])
                t0 = t[i - 1] + frac * (t[i] - t[i - 1])
                break
    else:
        vi = B.trace(res, "vin_s")
        for i in range(1, len(vi)):
            if vi[i - 1] < 2.2 <= vi[i]:
                frac = (2.2 - vi[i - 1]) / (vi[i] - vi[i - 1])
                t0 = t[i - 1] + frac * (t[i] - t[i - 1])
                break

    level = 0.9 * target
    t90 = None
    for i in range(len(o)):
        if o[i] >= level and (t0 is None or t[i] >= t0 - 1e-12):
            t90 = t[i]
            break
    dt = None if (t90 is None or t0 is None) else (t90 - t0) * 1e6

    if v["series"] == "LDK220":
        record("%s:ton90" % cid, cid, "startup", dt, 100.0, 400.0, "us",
               "LDK220 Figure 23, start-up with enable: Ton = 200 us to 90 % "
               "of VOUT with COUT = 1 uF",
               basis="datasheet (window engineering)",
               note="window 100..400 us around the 200 us typical of Figure "
                    "23; the datasheet states no minimum or maximum")
    else:
        record("%s:ton90" % cid, cid, "startup", dt, 50.0, 1000.0, "us",
               "LDK320 Figures 27/29 show start-up with enable but state no "
               "numeric Ton", basis="engineering",
               note="presence and order of magnitude of a soft start only; "
                    "this is not a datasheet limit")

    record("%s:startup_settled" % cid, cid, "startup", o[-1],
           target * (1 - accuracy_pct(v) / 100),
           target * (1 + accuracy_pct(v) / 100), "V",
           "Table 6/7, VOUT accuracy after start-up with IOUT = 1 mA")
    return dt


# --------------------------------------------------------------------------- #
# structural and portability checks
# --------------------------------------------------------------------------- #
def structure_checks(text):
    # SPICE comment lines start with '*'; the model header documents the
    # forbidden constructs ("no ternary_fcn", "no IF", ...), so counting the
    # raw file would flag the documentation instead of the netlist.
    code = "\n".join(l for l in text.splitlines()
                     if not l.lstrip().startswith("*"))
    upper = code.upper()
    record("S:subcircuits", "model", "structure",
           float(sum(1 for s in SUBCKTS if (".SUBCKT " + s) in upper)), 7, 7,
           "count", "all seven subcircuits named in input/spec.json must exist")
    record("S:no_end", "model", "structure",
           float(sum(1 for l in code.splitlines()
                     if l.strip().upper() == ".END")), 0, 0, "count",
           "an included model must not contain .END")
    record("S:params_defaults", "model", "structure",
           float(upper.count("PARAMS:")), 7, 7, "count",
           "every subcircuit must declare a VNOM/VREF default")
    record("S:portable_constructs", "model", "structure",
           float(sum(upper.count(t)
                     for t in ("TERNARY_FCN", "IF(", "TABLE(", ".PARAM"))),
           0, 0, "count",
           "the declared portable construct set forbids ternary/IF/TABLE/"
           ".param (SPICE comment lines are excluded)")


def convergence_finding():
    """LDK320 fixed + ideal current sink: non-converging operating point."""
    sub = "MY_LIB_LDK320_FIXED_DS"
    deck, n = build("s", sub, 6.0, vnom=3.3)
    deck = [l for l in deck if not l.startswith("RL_s ")]
    deck.append("ISINK_s out_s ret_s 100m")
    res = simulate(deck, ["op"], ["out_s", "s.soft"],
                   "probe: LDK320 fixed + ideal 100 mA current sink")
    soft = get(res, "s.soft")
    outv = get(res, "out_s")
    msgs = [l.strip() for l in res["log"]
            if "fail" in l.lower() or "optran" in l.lower()]
    bad = bool(msgs) and (outv is None or outv < 0
                          or (soft is not None and soft < 0.99))
    return {"deck": "LDK320 fixed, VIN = 6 V, VNOM = 3.3, 100 mA ideal sink",
            "vout_v": outv, "soft_node_v": soft,
            "converged_to_physical_point": not bad, "messages": msgs}


def gnd_port_probe():
    deck = ["* GND port-name collision probe",
            "V1 a 0 1", "V2 g 0 2", "R1 a b 1k",
            "X1 a g b SUB_GND", "X2 a g b SUB_VSS",
            ".subckt SUB_GND P GND Q", "Rin P GND 1k", "Rout Q GND 1k", ".ends",
            ".subckt SUB_VSS P VSS Q", "Rin P VSS 1k", "Rout Q VSS 1k", ".ends"]
    res = B.simulate(deck, ["op"], ["b"])
    b = get(res, "b")
    return {"node_voltage_v": b,
            "expected_with_real_reference_v": 1.5,
            "expected_if_port_forced_to_node_0_v": 0.5,
            "collision_confirmed": b is not None and abs(b - 0.5) < 0.05}


# --------------------------------------------------------------------------- #
def main() -> int:
    started = time.time()
    RESULTS.mkdir(parents=True, exist_ok=True)
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    variants = spec["family"]["variants"]
    text = MODEL.read_text(encoding="utf-8")
    sha = hashlib.sha256(MODEL.read_bytes()).hexdigest()

    structure_checks(text)

    results = []
    for v in variants:
        print("... op   %s %-14s %s"
              % (v["id"], v["mpn"], v["spice_model"]), flush=True)
        results.append(op_block(v))

    reps = {}
    for v in variants:
        if not is_adj(v) and v["spice_model"] in HAS_EN:
            reps.setdefault((v["series"], v["spice_model"]), v)
    thresholds = {}
    for (series, sub), v in reps.items():
        print("... ven  %s" % v["id"], flush=True)
        thresholds["%s/%s" % (series, sub)] = enable_threshold(v)

    for v in variants:
        print("... tran %s" % v["id"], flush=True)
        startup(v)

    findings = []
    probe = gnd_port_probe()
    if probe["collision_confirmed"]:
        findings.append({
            "id": "GND_PORT_NAME_COLLISION",
            "severity": "WARNING",
            "title": "The subcircuit ground port is named GND, which ngspice "
                     "aliases to the global ground node 0",
            "detail": (
                "ngspice maps the node names 'GND'/'gnd' to node 0.  All seven "
                "subcircuits declare their ground port as GND "
                "(MY_LIB_LDK*_FIXED_DS and MY_LIB_LDK*_ADJ_DS: port 2; "
                "MY_LIB_LDK220_SOT89_DS and MY_LIB_LDK320_SOT89_STD_DS: port 2; "
                "MY_LIB_LDK320_SOT89_D_DS: port 1).  The net connected to that "
                "pin is therefore ignored and the model always references "
                "node 0."),
            "impact": (
                "No effect when the catalogue pin is wired to the SPICE ground "
                "reference, which is the normal case and the case used by every "
                "acceptance test here.  Wrong results if the pin is wired to a "
                "separate analogue ground, to a ground carrying a sense "
                "resistor, or to any offset node."),
            "probe": probe,
            "recommendation": (
                "Rename the port (GNDP / VSS / COM) in the seven .SUBCKT "
                "headers and bodies, or state in README.md that the port must "
                "be the SPICE ground net."),
        })

    conv = convergence_finding()
    if not conv["converged_to_physical_point"]:
        findings.append({
            "id": "LDK320_STIFF_LOAD_CONVERGENCE",
            "severity": "WARNING",
            "title": "LDK320 fixed subcircuits do not converge in .op with an "
                     "ideal current-sink load",
            "detail": (
                "With an ideal 100 mA current sink on OUT, ngspice-44 fails "
                "dynamic gmin stepping, true gmin stepping and source stepping, "
                "then falls back to its transient operating point and returns "
                "V(OUT) = %s V with the internal soft-start node at %s instead "
                "of 1.0.  The same circuit with a resistor load, or with a "
                ".nodeset on the output node, converges to the correct 3.2967 V. "
                "The LDK220 subcircuits converge with either load."
                % (conv["vout_v"], conv["soft_node_v"])),
            "impact": (
                "A real load is rarely an ideal current sink, so this does not "
                "affect normal use, but a .op with an ideal current source load "
                "can silently return a non-physical operating point.  This "
                "acceptance suite therefore uses resistor loads everywhere."),
            "probe": conv,
            "recommendation": (
                "Optional robustness aid for the model author: add a small "
                "parallel conductance on OUT, or accept and document the "
                "behaviour in README.md."),
        })

    passed = sum(1 for c in CHECKS if c["pass"])
    payload = {
        "schema_version": "1.0",
        "kind": "ldk_ngspice_acceptance",
        "run_id": spec["run_id"],
        "stage": "TZ v1.1 s.6.3 independent SPICE acceptance test",
        "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "engine": "ngspice-44 (KiCad 9.0 ngspice.dll via CDLL, one child "
                  "process per deck)",
        "model_file": str(MODEL),
        "model_sha256": sha,
        "spec_file": str(SPEC),
        "status": "PASS" if passed == len(CHECKS) else "FAIL",
        "summary": {"checks": len(CHECKS), "passed": passed,
                    "failed": len(CHECKS) - passed,
                    "variants": len(variants), "subcircuits": len(SUBCKTS),
                    "checks_per_group": {
                        grp: sum(1 for c in CHECKS if c["group"] == grp)
                        for grp in sorted({c["group"] for c in CHECKS})}},
        "criteria_note": (
            "Every threshold is the datasheet number.  Where the datasheet "
            "publishes only a typical value (dropout, ISC, Rdis, Ton) the "
            "window is an engineering band around it and is marked accordingly. "
            "The model has no temperature dependence or tolerance spread, so "
            "only TJ = 25 C typical behaviour can be checked."),
        "checks": CHECKS,
        "variants": results,
        "ven_thresholds": thresholds,
        "findings": findings,
        "convergence_fallbacks": FALLBACKS,
        "duration_s": round(time.time() - started, 1),
    }
    (RESULTS / "ngspice_ldk_acceptance.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    (RESULTS / "ngspice_ldk_acceptance.log").write_text("\n".join(LOG),
                                                       encoding="utf-8")

    fails = [c for c in CHECKS if not c["pass"]]
    print("\n%d/%d checks PASS, %d FAIL  (%.1f s)"
          % (passed, len(CHECKS), len(fails), time.time() - started))
    for c in fails:
        print("  FAIL %-32s value=%s window=[%s, %s] %s"
              % (c["id"], c["value"], c["min"], c["max"], c["unit"]))
    for f in findings:
        print("  FINDING %s (%s)" % (f["id"], f["severity"]))
    if FALLBACKS:
        print("  %d deck(s) used the ngspice transient OP fallback"
              % len(FALLBACKS))
        for f in FALLBACKS:
            print("    - %s" % f["deck"])
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
