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
