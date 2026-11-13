# ESKD Altium Libraries

[Русская версия](README.ru.md)

Component library for **Altium Designer 24** with ESKD and IEC schematic symbols. Two linked database libraries let you choose the symbol style when placing a component.

| Standard | Connection file | Catalog | Catalog language |
|---|---|---|---|
| ESKD | `MY_LIB.DbLib` | `MY_LIB.xlsx` | Russian |
| IEC | `MY_LIB_IEC.DbLib` | `MY_LIB_IEC.xlsx` | English |

Both catalogs use the same catalog IDs and manufacturer part numbers (MPNs). Each database has its own symbols and shares footprints, STEP/3D models, and SPICE models with the other.

## Library contents

As of November 13, 2026, each catalog contains **1,549 components**, of which **1,186 have a SPICE model linked**. The table counts each component once.

| Category | Components | SPICE coverage | Representative parts and series |
|---|---:|---:|---|
| Resistors | 582 | 582 / 582 (100%) | YAGEO RC |
| Capacitors | 276 | 276 / 276 (100%) | YAGEO CC X7R |
| Diodes | 235 | 235 / 235 (100%) | Vishay, Nexperia, Diotec, Yangjie |
| Connectors | 358 | 0 / 358 (0%) | GCT, CONNFLY, JST PH/XH |
| Ferrite beads | 78 | 78 / 78 (100%) | TDK, Murata |
| LEDs | 10 | 10 / 10 (100%) | Oasistek |
| ICs | 5 | 4 / 5 (80%) | CP2102N, ISOW1432, USBLC6-2SC6, CDSOT23-SM712, 74HC1G08GW |
| Transistors | 1 | 1 / 1 (100%) | Youtai (UMW) 2N7002 |
| Switches | 1 | 0 / 1 (0%) | CONNFLY DS1040-01RT |
| Test points | 3 | 0 / 3 (0%) | Pads with diameters of 1, 1.5, and 2 mm |

Both workbooks contain component parameters. Local datasheets are in `Datasheets/`.

## Installation

1. Install Git, Altium Designer 24, Microsoft Excel, and a Microsoft ACE OLE DB provider that matches Altium's bitness. For ESKD symbols, also install the **Altium GOST Type A** font.
2. Clone the repository and enter its directory.

   ```sh
   git clone --branch dev https://github.com/nomatin/ESKD-altium-libraries.git
   cd ESKD-altium-libraries
   ```

3. Open the workbook in Excel, press **Ctrl+Alt+F9**, then save and close it. Set `Data Source` in the corresponding DbLib to the workbook path. Install the DbLib via **Preferences → Data Management → File-based Libraries**. Install both DbLib files to access both symbol styles.
4. In the **Components** panel, select a table from the database you want and find the part by ID or MPN.

Keep the directory structure intact. Symbol, footprint, and SPICE model paths are relative to the DbLib file. If you move the library, update absolute paths to local datasheets. See the [setup guide](ALTIUM_SETUP.md) for details.

## Updating

Close Excel and any library files open in Altium before updating. Run this command from the repository directory.

```sh
git pull --ff-only
```

Reopen the installed DbLib files after updating. The two-catalog version is available on the `dev` branch.

## SPICE

Both databases use the same models for all cataloged resistors, capacitors, diodes, LEDs, and ferrite beads, as well as the 2N7002 transistor and four ICs. The [74HC1G08GW](Simulation/Logic/MY_LIB_74HC1G08_DS.ckt) uses a simplified behavioral AND gate model at 25 °C. The ISOW1432DFMR uses a simplified functional model of its DC/DC converter, RS-485 interface, and GPIO.

Test results are documented for each group. Some models have standalone MixedSim results. The TDK AT000 and Murata ferrite bead models were also compared with manufacturer models in ngspice. These tests cover simulation. Placement through the DbLib interface is outside their scope.

Model documentation and results are available for [resistors](Simulation/Resistors/README.md), [capacitors](Simulation/Capacitors/README.md), [diodes](Simulation/Diodes/README.md), [LEDs](Simulation/LEDs/README.md), [ISOW1432DFMR](Simulation/ISOW1432DFMR/README.md), [USBLC6-2SC6](Simulation/USBLC6-2SC6/README.md), [CDSOT23-SM712](Simulation/CDSOT23-SM712/README.md), and [TDK](Simulation/Ferrites/TDK/README.md) and [Murata](Simulation/Ferrites/Murata/README.md) ferrite beads. See also the [simulation assumptions](SIMULATION_ASSUMPTIONS.md). Tests and reports are stored alongside the models in `Tests/` (`tests/` for the ISOW1432DFMR) and `Results/`.

## License

Original materials are available under [CC BY-NC 4.0](LICENSE), which permits noncommercial use with attribution. Commercial use requires separate permission. Datasheets and third-party CAD materials remain subject to their respective rights holders' terms. See the [third-party notices](THIRD_PARTY_NOTICES.md).
