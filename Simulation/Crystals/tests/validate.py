"""Independent AC diagnostic for the four-port XL2OI-111-8M BVD model."""
import ctypes as C
from hashlib import sha256
import json
import math
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL = HERE.parent / 'MY_LIB_XTAL_BVD.ckt'
MODEL_ID = 'MY_LIB_XTAL_BVD'
CATALOG_VALUES = 'FnomMHz=8 CLpF=12 RmOhm=150 C0pF=2 CmfF=5'
BIN = Path('C:/Program Files/KiCad/9.0/bin')
dll_directory = os.add_dll_directory(str(BIN))
dll = C.CDLL(str(BIN / 'ngspice.dll'))
log = []
report = {
    'engine': 'ngspice DLL shipped with KiCad 9.0, not MixedSim',
    'native_mixedsim': 'NOT_AVAILABLE',
    'scope': 'Small-signal checks for documented BVD scenarios, not part measurement or startup validation',
    'catalog_instance_parameters': CATALOG_VALUES,
    'model_sha256': sha256(MODEL.read_bytes()).hexdigest(),
    'checks': [],
}

Callback = C.CFUNCTYPE(C.c_int, C.c_char_p, C.c_int, C.c_void_p)
@Callback
def collect(message, _ident, _udata):
    log.append(message.decode('utf-8', 'replace'))
    return 0


class Complex(C.Structure):
    _fields_ = [('real', C.c_double), ('imag', C.c_double)]


class Vector(C.Structure):
    _fields_ = [('name', C.c_char_p), ('type', C.c_int), ('flags', C.c_short),
                ('real', C.POINTER(C.c_double)), ('complex', C.POINTER(Complex)),
                ('length', C.c_int)]


dll.ngSpice_Init.argtypes = [C.c_void_p] * 7
dll.ngSpice_Command.argtypes = [C.c_char_p]
dll.ngSpice_Circ.argtypes = [C.POINTER(C.c_char_p)]
dll.ngGet_Vec_Info.argtypes = [C.c_char_p]
dll.ngGet_Vec_Info.restype = C.POINTER(Vector)
assert dll.ngSpice_Init(collect, collect, None, None, None, None, None) == 0


def check(name, ok, **values):
    report['checks'].append(dict(name=name, status='PASS' if ok else 'FAIL', **values))


def vector(name):
    data = dll.ngGet_Vec_Info(name.encode())
    if not data or not data.contents.length:
        raise ValueError(f'Missing or empty ngspice vector {name}')
    values = data.contents
    if values.complex:
        return [complex(z.real, z.imag) for z in values.complex[:values.length]]
    return list(values.real[:values.length])


def sweep(label, elements, count, start, stop, vectors):
    dll.ngSpice_Command(b'destroy all')
    log.append(f'=== {label} ===')
    lines = [
        f'XL2OI-111-8M {label}',
        f'.include "{MODEL.as_posix()}"',
        '.options tnom=25',
        '.temp 25',
        *elements, f'.ac lin {count} {start} {stop}', '.end',
    ]
    fixture_lines = lines.copy()
    fixture_lines[1] = f'.include "../{MODEL.name}"'
    (HERE / f'{label}.cir').write_text('\n'.join(fixture_lines) + '\n', encoding='ascii')
    deck = (C.c_char_p * (len(lines) + 1))(*(line.encode() for line in lines), None)
    assert dll.ngSpice_Circ(deck) == 0, label
    assert dll.ngSpice_Command(b'run') == 0, label
    results = [vector(name) for name in ('frequency', *vectors)]
    assert all(len(v) == count for v in results), (label, [len(v) for v in results])
    return results


def crossing(frequency, response):
    hits = []
    for a, b, y, z in zip(frequency, frequency[1:], response, response[1:]):
        if y < 0 <= z:
            hits.append(a.real + (b.real - a.real) * -y / (z - y))
    return hits


def run():
    fixture = [
        'Vsignal drive 0 dc 0 ac 1',
        'VterminalReturn ret 0 dc 0',
        'Vcase2 case2 0 dc 0',
        'Vcase4 case4 0 dc 0',
        f'Xquartz drive case2 ret case4 {MODEL_ID} {CATALOG_VALUES}',
    ]
    f, through = sweep('series_resonance', fixture, 401, 7_998_400, 7_998_800, ['vsignal#branch'])
    # With a parallel ideal capacitor, Re(Y) peaks exactly at the motional series frequency.
    current = [-value for value in through]
    index = max(range(len(current)), key=lambda n: current[n].real)
    series = f[index].real
    apparent_esr = 1 / current[index].real
    check('Motional ESR scenario at series resonance',
          abs(apparent_esr - 150) < 0.01 and 7_998_500 < series < 7_998_700,
          calculated_esr_ohm=apparent_esr, series_frequency_hz=series,
          datasheet_esr_limit_ohm=150)
    check('Positive real admittance across series sweep',
          min(value.real for value in current) > 0,
          minimum_conductance_siemens=min(value.real for value in current))

    resonances = {}
    for load_pf in (0, 8, 12, 18):
        test = fixture + ([f'Cload drive ret {load_pf}p'] if load_pf else [])
        f, through = sweep(f'load_{load_pf}pF', test, 3501, 7_999_000, 8_010_000, ['vsignal#branch'])
        hits = crossing(f, [-value.imag for value in through])
        check(f'Unique high-impedance phase crossing at CL={load_pf} pF', len(hits) == 1,
              crossing_count=len(hits), phase_crossings_hz=hits)
        if len(hits) == 1:
            resonances[load_pf] = hits[0]
    if len(resonances) == 4:
        check('8 MHz phase crossing at specified 12 pF', abs(resonances[12] - 8_000_000) < 2,
              frequency_hz=resonances[12], numerical_tolerance_hz=2)
        check('Load pulling sign and resonance ordering',
              series < resonances[18] < resonances[12] < resonances[8] < resonances[0],
              series_hz=series, phase_crossings_hz=resonances)

    f, through = sweep('low_frequency_c0', fixture, 11, 10_000, 20_000, ['vsignal#branch'])
    # At this frequency the motional branch adds approximately the chosen 5 fF.
    c_eff_pf = -through[0].imag / (2 * math.pi * f[0].real) * 1e12
    check('Low-frequency effective capacitance C0 + Cm', abs(c_eff_pf - 2.005) < 0.0001,
          effective_pf=c_eff_pf, selected_c0_pf=2, assumed_cm_pf=0.005)

    isolated_case = [
        'Vsignal drive 0 dc 0 ac 1',
        'VterminalReturn ret 0 dc 0',
        'Vcase2 case2 0 dc 0 ac 1',
        'Vcase4 case4 0 dc 0 ac 2',
        f'Xquartz drive case2 ret case4 {MODEL_ID} {CATALOG_VALUES}',
    ]
    _, case2, case4, signal = sweep('case_isolation', isolated_case, 11, 7_995_000, 8_005_000,
                                     ['vcase2#branch', 'vcase4#branch', 'vsignal#branch'])
    peak_case = max(abs(value) for value in case2 + case4)
    check('Ground pads have no modeled branch or coupling', peak_case < 1e-15,
          peak_case_current_amp=peak_case)
    reverse = fixture[:-1] + [f'Xquartz ret case2 drive case4 {MODEL_ID} {CATALOG_VALUES}']
    _, reversed_signal = sweep('terminal_reversal', reverse, 11, 7_995_000, 8_005_000,
                               ['vsignal#branch'])
    reciprocity = max(abs(a - b) for a, b in zip(signal, reversed_signal))
    check('Electrodes 1 and 3 are reciprocal and insensitive to case excitation',
          reciprocity < 1e-12, max_admittance_difference_siemens=reciprocity)

    # Non-default values in all five formal parameters. This is a synthetic case.
    parameter_override = 'FnomMHz=10 CLpF=20 RmOhm=80 C0pF=3 CmfF=9'
    changed = fixture[:-1] + [f'Xquartz drive case2 ret case4 {MODEL_ID} {parameter_override}']
    f, through = sweep('override_load_resonance', changed + ['Cload drive ret 20p'],
                       2001, 9_999_000, 10_001_000, ['vsignal#branch'])
    hits = crossing(f, [-value.imag for value in through])
    check('Non-default FnomMHz and CLpF recalculate loaded resonance',
          len(hits) == 1 and abs(hits[0] - 10_000_000) < 2,
          parameters=parameter_override, phase_crossings_hz=hits)

    f, through = sweep('override_motional_resistance', changed, 3001, 9_997_000, 10_000_000,
                       ['vsignal#branch'])
    index = max(range(len(through)), key=lambda n: -through[n].real)
    resistance = -1 / through[index].real
    check('Non-default RmOhm changes motional ESR',
          abs(resistance - 80) < 0.01,
          parameters=parameter_override, extracted_resistance_ohm=resistance,
          series_peak_hz=f[index].real)

    f, through = sweep('override_capacitances', changed, 11, 10_000, 20_000, ['vsignal#branch'])
    effective_pf = -through[0].imag / (2 * math.pi * f[0].real) * 1e12
    check('Non-default C0pF and CmfF change low-frequency capacitance',
          abs(effective_pf - 3.009) < 0.0001,
          parameters=parameter_override, capacitance_pf=effective_pf)


try:
    run()
except Exception as error:
    check('Test execution', False, error=repr(error))
    raise
finally:
    report['status'] = 'PASS' if all(c['status'] == 'PASS' for c in report['checks']) else 'FAIL'
    (HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    (HERE / 'ngspice.log').write_text('\n'.join(log) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))

raise SystemExit(report['status'] != 'PASS')
