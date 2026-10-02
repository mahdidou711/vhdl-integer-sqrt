# Integer Square Root Core in VHDL

> **Quick overview** — VHDL · iterative arithmetic architecture · fixed latency · exhaustive GHDL simulation over **65,536** inputs · Terasic DE1 port preparation

A small digital-design and FPGA portfolio project implementing a synthesizable unsigned 16-bit integer square-root core. It computes `floor(sqrt(X))` as an 8-bit result using an iterative binary digit-by-digit architecture. The repository includes exhaustive simulation of all 65,536 input values and a prepared Terasic DE1 wrapper.

## Core architecture

The core uses a restoring, shift-and-subtract datapath controlled by a small state machine. Its interface is:

| Port | Direction | Description |
| --- | --- | --- |
| `clk` | input | System clock |
| `reset` | input | Asynchronous active-low reset |
| `start` | input | Starts a calculation when accepted in the idle state |
| `X_in[15:0]` | input | Unsigned radicand |
| `R_out[7:0]` | output | Unsigned integer square root |
| `done` | output | One-clock completion pulse |

When `start` is accepted, the core captures `X_in`; later changes to the input do not affect the active calculation. Eight compute iterations determine one root bit per cycle, from most significant to least significant.

The transaction protocol is deliberately simple:

- An accepted `start` at `t0` produces the result and asserts `done` at `t0 + 9` clock periods.
- `done` remains asserted for one clock period.
- A `start` asserted during computation is ignored.
- If `start` is held high at the core interface, it is accepted again after the core returns to the idle state.
- The DE1 wrapper avoids repeated board-level launches by converting a rising transition on `SW9` into a one-shot pulse.

## Algorithm

The implementation is a binary digit-by-digit integer square root in restoring, shift-and-subtract style. Each iteration forms a trial value for the next root bit and tests a candidate subtraction. If the candidate is accepted, the updated remainder is kept; otherwise, the previous remainder is retained. Repeating this from the most significant root bit to the least significant produces the integer floor of the square root.

## Latency

The timing is fixed by the architecture:

| Event | Time |
| --- | --- |
| Input captured and start accepted | `t0` |
| Eight compute iterations | following eight clock periods |
| Result valid and `done` asserted | `t0 + 9` clock periods |

At the DE1's 50 MHz clock rate, nine clock periods correspond to **180 ns**. This is architectural latency, not measured timing performance, timing closure, or a verified maximum clock frequency.

## Verification

The permanent automated test suite uses VHDL-93 and GHDL. It checks:

- directed boundary and representative arithmetic cases;
- exact result and completion latency;
- asynchronous reset and reset during computation;
- input capture at an accepted start;
- ignored starts during computation;
- held-high start behavior at the core interface;
- successive transactions and output stability;
- protection against meta-values at the checked interfaces; and
- every possible 16-bit input: 65,536 cases with 0 mismatches.

The exhaustive reference model uses integer binary search. It is independent of the DUT's restoring recurrence, reducing the risk that implementation and oracle share the same arithmetic mistake. Mutation sanity checks were also used during development to confirm that the suite detects intentional faults; they are not part of the permanent test run.

## FPGA port preparation

The board project targets a Terasic DE1 with an Intel Cyclone II `EP2C20F484C7` device and a 50 MHz `CLOCK_50` input.

| Board control | Function |
| --- | --- |
| `SW7:0` | Byte value |
| `SW8` | Selects the low or high input byte |
| `SW9` | Launch control |
| `KEY0` | Active-low reset |
| `LEDR0` | Latched completion indicator |
| `HEX0`–`HEX2` | Decimal result |
| `HEX3` | Blank |

To enter and calculate a value:

1. Set `SW8` low and enter the low byte on `SW7:0`.
2. Set `SW8` high and enter the high byte on `SW7:0`.
3. Toggle `SW9` from low to high.
4. Wait for `LEDR0` to illuminate.
5. Read the decimal result on `HEX2` through `HEX0`.

`SW9` is synchronized and edge-detected, but the wrapper does not implement a full mechanical debounce circuit. The completion LED is latched because the core's `done` signal lasts only one clock period.

## Validation status

### Automatically verified locally with GHDL

- VHDL-93 analysis;
- directed and protocol-focused core tests;
- exhaustive arithmetic verification;
- wrapper analysis and elaboration; and
- wrapper synthesis check through GHDL.

### Statically reviewed

- project and settings file structure;
- correct top-level entity, Cyclone II family, and `EP2C20F484C7` device;
- all 41 used physical pins traced to the DE1 configuration, with no duplicate assignments;
- source paths and unused-pin policy; and
- a 20 ns `CLOCK_50` constraint in the timing constraints file.

The 20 ns constraint specifies the intended 50 MHz clock requirement. It is **not** evidence of timing closure, and no verified Fmax is claimed.

### Hardware status & coursework experience

- The historical core ran on a physical Terasic DE1 board during university coursework (Quartus Analysis & Synthesis and Fitter completed, programming files generated).
- That historical core is byte-identical to the pinned core in this repository.
- The historical wrapper differs from the current public wrapper, which is prepared for Quartus and statically reviewed but not board-tested.
- No verified maximum clock frequency (Fmax) or timing closure is claimed.

## Project structure

```text
rtl/                    Synthesizable square-root core
tb/                     Directed, protocol, and exhaustive testbenches
sim/ghdl/               Local verification entry point and work area
fpga/de1/                DE1 wrapper, project settings, pins, and constraints
.github/workflows/       Continuous-integration workflow
README.md                Project documentation
```

## Running the tests

Requirements:

- GHDL with VHDL-93 support; and
- GHDL synthesis support.

From the repository root, run:

```sh
./sim/ghdl/run_tests.sh
```

The suite was validated locally with GHDL 4.1.0. Other GHDL versions supporting the required VHDL-93 analysis, simulation, and synthesis features may also be compatible.

## Deliberate scope

This compact implementation does not include pipelining, floating-point square root, signed inputs, a parameterized operand width, an AXI or Wishbone interface, or a full mechanical switch debounce circuit.
