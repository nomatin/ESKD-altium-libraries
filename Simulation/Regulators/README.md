# TLV75533PDBVR datasheet model

Independent behavioral model for typical 25 °C operation. Source [TI SBVS320D, Rev. D](https://www.ti.com/lit/ds/symlink/tlv755p.pdf), §5.5 and §6.3–6.4. Intended for the 3.3 V DBV variant. TI's supplied SPICE implementation was not used.

| Subcircuit port | Name | Physical pin |
|---:|---|---:|
| 1 | IN | 1 |
| 2 | GND | 2 |
| 3 | EN | 3 |
| 4 | OUT | 5 |

Physical pin 4 is NC. Use the external input and output capacitors called for by the datasheet.

The model implements nominal regulation, typical DBV load regulation (60 mV/A), typical dropout (150 mV at 500 mA) represented by an equivalent 0.30 Ω headroom term, input pass current, typical no-load ground currents (25 µA enabled and 0.1 µA disabled), and 120 Ω output discharge. EN leakage is approximated by 550 MΩ. A 1 GΩ output resistor provides a numerical DC path at no load. Current limiting interpolates between the typical 355 mA at 0 V and 720 mA at 2.97 V. The linear interpolation and dropout extrapolation are model assumptions. Startup is a one-pole approximation reaching 90% in about 550 µs at light load with adequate headroom. UVLO is centered at the typical 1.30 V and EN at an assumed 0.65 V between the two specified logic levels. Each threshold uses a 20 mV linear transition for numerical convergence.

No UVLO/EN hysteresis, temperature dependence, thermal shutdown, self-heating, process corners, PSRR, noise, loop stability, reverse current, reverse protection, or calibrated line/load transient response. Operation below the supply range is simplified. The foldback approximation describes static endpoints, not recovery dynamics or all load-dependent start conditions.


## Verification

Tests are in Tests/, saved reports and native NSX/SDF are in Results/. Run python Tests/test_datasheet.py with KiCad 9 ngspice installed. The 13 ngspice checks are diagnostic, with automatic source stepping for the initial operating point. Both Spice Sifter OP tests read U0007 through the installed ESKD and IEC DbLib and measured 3.285067872 V at VIN=4.3 V and 13.2 ohm load. Reports retain their original artifact paths, and local copies of the NSX/SDF are provided alongside them. Native tests used the 1200 mil symbol before its subsequent reduction to 1000 mil. The model was unchanged.

---

# LDK220 / LDK320 datasheet model

Independent behavioural model of the STMicroelectronics LDK220 and LDK320
200 mA low-dropout regulators, written from the datasheets only. ST publishes
no SPICE netlist for either part, so nothing was copied or translated.

Sources:

| Part | Document | Used for |
|---|---|---|
| LDK220 | ST DS10219 Rev 7, November 2021 | Tables 6 and 7; Figure 14 (VEN threshold); Figure 23 (start-up) |
| LDK320 | ST DS11321 Rev 13, June 2025 | Tables 6 and 7; Figure 13 (VEN threshold); Figure 22 (SOA current limit) |

File: `MY_LIB_LDK_REGULATORS_DS.ckt`, 247 lines.
SHA-256: `6EF3A57C7429D8C5DBBB02FA0FD7DC3FA30F33EB8601BDAEFE12DEA3E103B32`.

## Dialect

Only `E` and `G` sources with `VALUE={...}` expressions built from `MIN`,
`MAX` and arithmetic. There is no ternary operator, no `ternary_fcn`, no
`IF()`, no `TABLE` and no `.param`. This is the same construct set as
`MY_LIB_TLV75533P_DS.ckt`, which runs in both KiCad 9 ngspice and Altium
MixedSim, so the file is intended to be portable between them.

Subcircuit parameters appear inside `VALUE={...}` braces. Brace substitution
of subcircuit parameters is already used and natively verified in this library
in `MY_LIB_R_TCR.ckt` (`.MODEL RTCR R (TC1={TC1value} ...)`).

## Subcircuits

| Subcircuit | Ports in `.SUBCKT` order | Parameters |
|---|---|---|
| `MY_LIB_LDK220_FIXED_DS` | `IN GND EN OUT` | `VNOM=3.3` |
| `MY_LIB_LDK220_ADJ_DS` | `IN GND EN ADJ OUT` | `VREF=1.185` |
| `MY_LIB_LDK220_SOT89_DS` | `OUT GND IN` | `VNOM=3.3` |
| `MY_LIB_LDK320_FIXED_DS` | `IN GND EN OUT` | `VNOM=3.3` |
| `MY_LIB_LDK320_ADJ_DS` | `IN GND EN ADJ OUT` | `VREF=1.185` |
| `MY_LIB_LDK320_SOT89_STD_DS` | `OUT GND IN` | `VNOM=3.3` |
| `MY_LIB_LDK320_SOT89_D_DS` | `GND IN OUT` | `VNOM=3.3` |

### Port index to physical pin

The port order follows the physical package pin order. The SchLib pin number
and the `.SUBCKT` port index are two different things; the Sim Port Map in
Excel/DbLib is what joins them.

| Subcircuit | Port 1 | Port 2 | Port 3 | Port 4 | Port 5 | Sim Port Map |
|---|---|---|---|---|---|---|
| `MY_LIB_LDK220_FIXED_DS` | IN (pin 1) | GND (pin 2) | EN (pin 3) | OUT (**pin 5**) | — | `(1:1),(2:2),(3:3),(5:4)` |
| `MY_LIB_LDK220_ADJ_DS` | IN (pin 1) | GND (pin 2) | EN (pin 3) | ADJ (pin 4) | OUT (pin 5) | `(1:1),(2:2),(3:3),(4:4),(5:5)` |
| `MY_LIB_LDK220_SOT89_DS` | OUT (pin 1) | GND (pin 2/TAB) | IN (pin 3) | — | — | `(1:1),(2:2),(3:3)` |
| `MY_LIB_LDK320_FIXED_DS` | IN (pin 1) | GND (pin 2) | EN (pin 3) | OUT (**pin 5**) | — | `(1:1),(2:2),(3:3),(5:4)` |
| `MY_LIB_LDK320_ADJ_DS` | IN (pin 1) | GND (pin 2) | EN (pin 3) | ADJ (pin 4) | OUT (pin 5) | `(1:1),(2:2),(3:3),(4:4),(5:5)` |
| `MY_LIB_LDK320_SOT89_STD_DS` | OUT (pin 1) | GND (pin 2/TAB) | IN (pin 3) | — | — | `(1:1),(2:2),(3:3)` |
| `MY_LIB_LDK320_SOT89_D_DS` | GND (pin 1) | IN (pin 2/TAB) | OUT (pin 3) | — | — | `(1:1),(2:2),(3:3)` |

SOT23-5L pin 4 is NC on the fixed versions and is not a model port. The pad
stays in the footprint without a net.

Suggested netlist lines, matching `input/spec.json`:

```
@DESIGNATOR %1 %2 %3 %4 @MODEL PARAMS: VNOM=<nominal>
@DESIGNATOR %1 %2 %3 %4 %5 @MODEL PARAMS: VREF=<1.185|1.2>
@DESIGNATOR %1 %2 %3 @MODEL PARAMS: VNOM=<nominal>
```

Relative model path for the DbLib binding:
`Simulation\Regulators\MY_LIB_LDK_REGULATORS_DS.ckt`.

Every instance needs the external `CIN` and `COUT` the datasheet requires
(1 uF to 22 uF). The model has no internal output capacitor.

## Implemented behaviour

Typical values at TJ = 25 °C. Nothing here is a guaranteed limit.

### Enable and UVLO

- EN threshold is a 20 mV linear transition between 0 and 1. Centred on
  0.67 V for LDK220 (`(VEN-0.66)/0.02`) and 0.68 V for LDK320
  (`(VEN-0.67)/0.02`), both between the specified 0.4 V maximum low and
  1.2 V minimum high levels.
- Input UVLO is a 0.2 V linear ramp from 2.0 V to 2.2 V, so the part is fully
  enabled at the 2.5 V minimum operating input and fully off below 2.0 V.
- `VEN` is ANDed with the UVLO term.
- EN leakage is `REN EN GND 50G`, i.e. 0.1 nA at VEN = 5 V.
- The SOT-89 variants have no EN pin, so only the UVLO term drives the enable
  state: the part is active whenever VIN is above UVLO.

### Start-up

Single-pole ramp with tau = 87 us, so 90 % is reached 200 us after the enable
edge (Figure 23). Implemented as a conductance into a 1 uF state capacitor;
with that capacitor the numeric divisor in the expression is the time constant
in microseconds (`/87` gives 87 us, `/1` gives the 1 us reset).

### Regulation

- Fixed versions: the pass source delivers
  `(VNOM*Soft - VOUT) / RREG`, so the static load slope is `RREG` ohm.
  `RREG = 0.01*VNOM` ohm reproduces the specified 0.001 %/mA
  (0.033 ohm at 3.3 V, 0.6 mV over 1..200 mA at 3.3 V).
- LDK320 fixed below 2 V: the datasheet switches to a flat 10 mV over
  1..200 mA, i.e. 0.050 ohm. The two branches are blended over
  VNOM = 2.00..2.05 V inside the expression, so the 1.5 V and 1.8 V variants
  use 0.050 ohm and the 2.5 V and higher variants use `0.01*VNOM`.
- Adjustable versions: the error amplifier is a transconductance of
  `1/0.0024` S comparing `V(ADJ)` with `VREF*Soft`. At 200 mA the ADJ pin sits
  0.48 mV below VREF, which is the specified 0.0002 %/mA.
  With R1 from OUT to ADJ and R2 from ADJ to GND, `VOUT = VREF*(1+R1/R2)`.
  `VREF = 1.185 V` for LDK220M-R and LDK320M-R, `1.200 V` for LDK320AM-R.
  ADJ bias current is `RADJ ADJ GND 120MEG`, about 10 nA; the datasheet
  maximum is 1 uA.

### Dropout

A 1.0 ohm equivalent pass resistance, which gives the specified 100 mV at
100 mA and 200 mV at 200 mA. The pass current is limited by
`V(IN,OUT)/1.0`.

### Current limit

- LDK220: flat 0.400 A typical.
- LDK320: follows Table 6 and Figure 22 of the SOA curve,
  `0.330 - 0.130*MIN(MAX((V(IN,OUT)-10)/2,0),1)`, i.e. 330 mA while the
  input-to-output differential is at or below 10 V, falling linearly to
  200 mA at 12 V and above.

### Quiescent current

| Part | 0 mA | 200 mA | off mode |
|---|---|---|---|
| LDK220 all variants | 55 uA | 60 uA | 0.1 uA |
| LDK320 fixed | 60 uA | 70 uA | 0.2 uA |
| LDK320 adjustable | 50 uA | 60 uA | 0.2 uA |

The load-dependent part is `2.5e-5 * Iload` (LDK220) and `5e-5 * Iload`
(LDK320), sensed as the voltage across a 1 mohm input resistor and re-injected
as a ground current. The `MIN(MAX(V(IN)/2.0,0),1)` factor keeps the sink off
on an unpowered VIN node.

### Active output discharge

LDK220 only, 18 ohm typical, active when the part is disabled:
`(1-Enabled)*V(OUT)/18`. LDK320 has no discharge (its Figure 1/2 and
Table 6/7 do not include one), so no discharge element is present in the
LDK320 subcircuits.

## Numerical aids

These are model constructs, not datasheet behaviour. They are documented
because they are visible in a netlist review.

1. **1 uA negative floor on the pass source** (`MAX(-1u, ...)`). With a hard
   `MAX(0, ...)` the pass current is clamped flat at zero whenever the output
   is at or above its target, and an unloaded output then has no defined
   operating point.
2. **100 kohm internal load** (`RNoLoad OUT GND 100k`). An ideal pass current
   source leaves the output node under-determined at no load; without a
   defined conductance the DC operating point can fail to converge. ngspice 44
   needs roughly 1 uS of output conductance here. `GIqComp IN GND
   VALUE={-1e-5*V(OUT,GND)}` cancels that load current at the IN terminal, so
   the terminal quiescent current still matches the datasheet: measured IQ is
   55.0 uA with no load and 55.0 uA into a 1 Mohm load.
3. **1 Gohm on the soft-start node** (`RSoft Soft GND 1G`). Only gives that
   node a DC path in every analysis type; it moves the settled value by less
   than 0.1 uV of output.
4. **1 mohm input sense resistor** (`RSns IN IN_S 1m`). Adds 1 mohm to the
   input path, 0.1 % of the 1 ohm dropout resistance.

The pass source is a current source, so the model's line-to-output AC gain is
zero by construction. That is the ideal-regulator limit (infinite PSRR), not a
measurement. See NOT_MODELED.

## NOT_MODELED

- PSRR (the AC gain from IN to OUT is zero, i.e. PSRR is infinite), output
  noise, and any frequency-dependent supply rejection.
- Loop stability, phase margin and load-transient shape. The regulation loop
  is a memoryless transconductance with the external COUT as its only pole;
  the model cannot predict oscillation or the transient overshoot of a real
  board.
- Temperature dependence of any parameter, thermal shutdown (160 °C typical,
  20 °C hysteresis), self-heating and Rth.
- Output accuracy spread and tolerance corners: only typical values are
  modelled, so the ±2 % / ±3 % (or ±0.5 % / ±1.5 % for the A grade) limits
  are not represented.
- Reverse current, reverse polarity protection, and behaviour with VOUT
  forced above VIN. The 1 uA floor lets the pass source sink up to 1 uA when
  the output is driven above nominal.
- Line regulation: the 0.001 %/V typical figure is not modelled, because an
  ideal current-source pass element already gives zero line-to-output gain.
- Absolute maximum ratings, ESD, inrush into COUT, and behaviour above the
  specified VIN range.
- The internal load of item 2 above is a numerical aid; it is not the real
  internal feedback divider and it is invisible at the terminals only because
  `GIqComp` cancels it exactly.

## Verification status

The author of a model does not approve its acceptance tests (TZ v1.1
section 6.3). The acceptance tests are written and run by the independent
SPICE Test Agent.

What was done here is a developer sanity check only, with
`_dev_sanity.py` / `_dev_sanity.json` / `_dev_sanity.log` in this directory:
ngspice-44 from the KiCad 9 DLL, `.op`, `.dc`, `.ac` and `.tran`, all seven
subcircuits, 67 recorded measurements (23 of them with a datasheet-derived
target band), all on target, no convergence warnings and no singular-matrix
messages. Representative results (diagnostic, not acceptance criteria):

| Check | Result |
|---|---|
| LDK220 fixed VOUT, no load | 3.299999 V |
| LDK220 fixed VOUT at 200 mA | 3.293412 V (0.033 ohm slope) |
| LDK220 fixed IQ, no load / 200 mA / off | 55.00 / 59.99 / 0.100 uA |
| LDK220 fixed ISC | 400.07 mA |
| LDK220 fixed dropout resistance at VIN = 3.0 V | 1.0002 ohm |
| LDK220 fixed EN turn-on threshold | 0.68 V |
| LDK220 fixed t90 from the EN edge | 201.0 us |
| LDK220 fixed VOUT after disable, 1 uF COUT | 3.273 V at +1 us, 1.960 V at +10 us, 0.211 V at +50 us |
| LDK220 ADJ VOUT, R1 = R2 = 10 k | 2.369409 V, V(ADJ) = 1.184655 V |
| LDK220 ADJ VOUT, R1 = 10 k, R2 = 1.65 k | 8.3655 V (nominal 8.3668 V) |
| LDK320 fixed IQ, no load / 200 mA / off | 60.00 / 69.98 / 0.200 uA |
| LDK320 fixed ISC at VIN = 5 / 11 / 12 / 16 V | 330.08 / 265.09 / 200.08 / 200.07 mA |
| LDK320 fixed VOUT 1.8 V at 200 mA | 1.790054 V (0.050 ohm slope) |
| LDK320 fixed VOUT 12 V at 200 mA | 11.97603 V |
| LDK320 ADJ VOUT, VREF = 1.2, R1 = R2 = 10 k | 2.399401 V |
| SOT-89 variants, 200 mA / no load | 3.293412 / 3.299999 V |

Not verified here:

- Altium MixedSim / Spice Sifter was not run for this model. The construct
  set matches `MY_LIB_TLV75533P_DS.ckt`, but native acceptance of
  `PARAMS:` values inside `VALUE={...}` for these subcircuits still has to be
  confirmed by the Test Agent.
- DbLib binding, Sim Port Map and the Excel rows are outside this file.
- No native Altium display of the symbol or footprint was involved.

## Notes for integration

- The model is shared by both the ESKD and the IEC catalogue; only one file is
  needed and it is referenced relatively.
- `VNOM` must be set per fixed variant (1.5, 1.8, 2.5, 3.0, 3.3, 3.6, 5.0,
  12.0 V as listed in `input/spec.json`) and `VREF` per adjustable variant
  (1.185 V or 1.2 V).
- The adjustable subcircuits expect an external divider. With ADJ left open
  the internal 120 Mohm pulls the pin to ground and the output runs to the
  current limit, exactly as an open-feedback regulator would.
- `_dev_sanity.py` is a developer diagnostic, not a test suite. Do not use it
  as evidence of acceptance.
