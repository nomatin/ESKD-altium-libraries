"""Independent transient checks, based on TI SBVS320D sections 5.3, 5.5, 6.3."""
import ctypes as c
import hashlib
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
MODEL = ROOT.parent / "MY_LIB_TLV75533P_DS.ckt"
KICAD = Path("C:/Program Files/KiCad/9.0/bin")
dll_dir = os.add_dll_directory(str(KICAD))
spice = c.CDLL(str(KICAD / "ngspice.dll"))
callback = c.CFUNCTYPE(c.c_int, c.c_char_p, c.c_int, c.c_void_p)
log = []


@callback
def collect(line, ident, user):
    log.append(line.decode(errors="replace"))
    return 0


spice.ngSpice_Init.argtypes = [c.c_void_p] * 7
spice.ngSpice_Init(collect, collect, None, None, None, None, None)
spice.ngSpice_Command.argtypes = [c.c_char_p]
spice.ngSpice_Circ.argtypes = [c.POINTER(c.c_char_p)]

deck = """TLV75533PDBVR independent verification at 25 C
.temp 25
V1 in1 0 5
C1 in1 0 1u
Ve en 0 PULSE(0 5 1m 5u 5u 2m 10m)
Xstartup in1 0 en startup MY_LIB_TLV75533P_DS
Cstartup startup 0 1u
Rstartup startup 0 33
V2 in2 0 4.3
C2 in2 0 1u
Xload in2 0 in2 loaded MY_LIB_TLV75533P_DS
Cloaded loaded 0 1u
Iload loaded 0 PWL(0 1m 2m 1m 2.01m 500m)
V3 in3 0 PWL(0 4.3 1.5m 4.3 1.6m 3.3 3m 3.3 3.1m 4.3)
C3 in3 0 1u
Xdrop in3 0 in3 drop MY_LIB_TLV75533P_DS
Cdrop drop 0 1u
Idrop drop 0 PWL(0 1m 1m 1m 1.1m 500m)
V4 in4 0 3.8
C4 in4 0 1u
Xlimit in4 0 in4 ocout MY_LIB_TLV75533P_DS
Climit ocout 0 1u
Vlimit ocout 0 2.97
V5 in5 0 3.8
C5 in5 0 1u
Xshort in5 0 in5 short MY_LIB_TLV75533P_DS
Cshort short 0 1u
Vshort short 0 0
V6 in6 0 1.2
C6 in6 0 1u
Xuvlo in6 0 in6 uvlo MY_LIB_TLV75533P_DS
Ruvlo uvlo 0 3300
Cuvlo uvlo 0 1u
V7 in7 0 5.5
C7 in7 0 1u
Xdischarge in7 0 en disch MY_LIB_TLV75533P_DS
Cdischarge disch 0 1u
Rdischarge disch 0 1meg
V8 in8 0 3.8
Xopen in8 0 in8 unloaded MY_LIB_TLV75533P_DS
Copen unloaded 0 1u
"""
# Typical-only timing and short-circuit limits use deliberately broad
# engineering windows. They are model checks, not extra datasheet guarantees.
checks = {
    "unloaded": ("FIND v(unloaded) AT=3.5m", 3.267, 3.333),
    "off_before": ("FIND v(startup) AT=0.9m", -0.01, 0.01),
    "startup_90": ("TRIG v(en) VAL=1 RISE=1 TARG v(startup) VAL=2.97 RISE=1", 0.0002, 0.001),
    "on_100ma": ("FIND v(startup) AT=2.5m", 3.267, 3.333),
    "off_after": ("FIND v(startup) AT=3.9m", -0.01, 0.01),
    "out_1ma": ("FIND v(loaded) AT=1.8m", 3.267, 3.333),
    "out_500ma": ("FIND v(loaded) AT=3.5m", 3.24, 3.333),
    "dropout_out": ("FIND v(drop) AT=2.8m", 3.085, 3.2),
    "dropout_recovery": ("FIND v(drop) AT=3.9m", 3.24, 3.333),
    "current_limit": ("FIND i(Vlimit) AT=3.5m", 0.560, 0.865),
    "short_limit": ("FIND i(Vshort) AT=3.5m", 0.30, 0.42),
    "below_uvlo": ("FIND v(uvlo) AT=3.5m", -0.01, 0.01),
    "discharge_1e": ("TRIG v(en) VAL=0.3 FALL=1 TARG v(disch) VAL=1.214 FALL=1", 0.00008, 0.00017),
}

model = MODEL.read_bytes()
circuit = deck.encode().splitlines() + model.splitlines() + [b".end"]
lines = (c.c_char_p * (len(circuit) + 1))(*circuit, None)
spice.ngSpice_Circ(lines)
spice.ngSpice_Command(b"tran 0.5u 4m 0 0.5u")
results = {}
for name, (expression, lower, upper) in checks.items():
    start = len(log)
    spice.ngSpice_Command(f"meas tran {name} {expression}".encode())
    match = re.search(rf"\b{name}\s*=\s*([-+0-9.eE]+)", "\n".join(log[start:]))
    value = float(match[1]) if match else None
    results[name] = {"value": value, "min": lower, "max": upper, "pass": value is not None and lower <= value <= upper}

output = {"source": "TI SBVS320D, sections 5.3, 5.5, 6.3", "model_sha256": hashlib.sha256(model).hexdigest(),
          "engine": "ngspice 44 (KiCad 9, diagnostic)", "results": results}
(ROOT / "test_fixture.cir").write_text(deck + '.include "../MY_LIB_TLV75533P_DS.ckt"\n.tran 0.5u 4m 0 0.5u\n'
    + "".join(f".meas tran {name} {expression}\n" for name, (expression, _, _) in checks.items()) + ".end\n")
(ROOT.parent / "Results/ngspice.log").write_text("\n".join(log))
(ROOT.parent / "Results/ngspice_result.json").write_text(json.dumps(output, indent=2))
print(json.dumps(output, indent=2))
raise SystemExit(0 if all(check["pass"] for check in results.values()) else 1)



