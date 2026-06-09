# Low-Latency FPGA Market Data Engine

A SystemVerilog FPGA-style market data processing engine that accepts simulated 32-bit market-data packets, buffers them through a FIFO, parses packet fields, updates a simple top-of-book order book, and generates a trade signal based on bid/ask spread.

This project is designed as a beginner-to-intermediate FPGA/digital design project with a low-latency trading infrastructure theme.

## Project Purpose

The goal of this project is to demonstrate a simple but complete hardware data pipeline:

```text
market-data packet
    ↓
FIFO buffer
    ↓
packet parser
    ↓
order book
    ↓
signal engine
    ↓
trade signal
```

The system measures deterministic latency from an accepted market-data update to the generated signal.

Current measured latency:

```text
3 clock cycles
```

## Packet Format

Each input packet is 32 bits:

```text
[31:28] message_type
[27:24] symbol_id
[23]    side
[22:0]  price
```

Field meanings:

| Field | Meaning |
|---|---|
| `message_type` | `1` = price update |
| `symbol_id` | Symbol number, such as 0, 1, 2, 3 |
| `side` | `0` = bid, `1` = ask |
| `price` | Integer price in cents |

Example:

```text
message_type = 1
symbol_id    = 0
side         = 0
price        = 10005
```

This represents:

```text
Symbol 0 bid = $100.05
```

## Architecture

The full engine connects the modules in this order:

```text
input packet
    ↓
FIFO
    ↓
packet parser
    ↓
order book
    ↓
signal engine
    ↓
trade signal output
```

The engine receives a price update, decodes it, stores the best bid or ask for the symbol, calculates the spread once both bid and ask exist, and outputs a trade signal if the spread is below a chosen threshold.

## Modules

| File | Purpose |
|---|---|
| `rtl/fifo.sv` | Buffers incoming packets |
| `rtl/packet_parser.sv` | Decodes 32-bit packet fields |
| `rtl/market_types_pkg.sv` | Defines shared typed market event structs and enums |
| `rtl/event_packet_parser.sv` | Decodes normalized 64-bit event packets |
| `rtl/market_data_frontend.sv` | Connects FIFO to parser |
| `rtl/order_book.sv` | Stores best bid and ask for each symbol |
| `rtl/event_order_book.sv` | Tracks bounded ADD/CANCEL/EXECUTE order events and best bid/ask quantity |
| `rtl/signal_engine.sv` | Calculates spread and generates trade signal |
| `rtl/event_signal_engine.sv` | Generates event-engine signal outputs from bid/ask snapshots |
| `rtl/event_risk_engine.sv` | Gates event-engine strategy output with basic spread and quantity risk checks |
| `rtl/market_data_engine.sv` | Top-level full pipeline |
| `rtl/event_market_data_engine.sv` | Top-level 64-bit event pipeline |
| `filelists/legacy_engine.f` | Ordered Verilator source list for the original engine |
| `filelists/event_engine.f` | Ordered Verilator source list for the event engine |

## Tests

| Testbench | Purpose |
|---|---|
| `sim/tb_smoke.sv` | Basic Verilator smoke test |
| `sim/tb_fifo.sv` | Tests FIFO push/pop behavior |
| `sim/tb_packet_parser.sv` | Tests packet decoding |
| `sim/tb_event_packet_parser.sv` | Tests normalized event packet decoding |
| `sim/tb_market_data_frontend.sv` | Tests FIFO-to-parser pipeline |
| `sim/tb_order_book.sv` | Tests bid/ask storage |
| `sim/tb_event_order_book.sv` | Tests event-based ADD/CANCEL/EXECUTE book behavior |
| `sim/tb_event_order_book_randomized.sv` | Compares event-book RTL against Python-generated golden vectors |
| `sim/tb_event_risk_engine.sv` | Tests event risk gating and reject codes |
| `sim/tb_signal_engine.sv` | Tests spread calculation and signal generation |
| `sim/tb_market_data_engine.sv` | Tests full end-to-end engine |
| `sim/tb_event_market_data_engine.sv` | Tests the integrated event parser/book/signal pipeline |
| `sim/tb_event_market_data_engine_risk.sv` | Tests integrated event risk accept/reject behavior |
| `sim/tb_latency.sv` | Measures end-to-end signal latency |
| `sim/tb_event_latency.sv` | Measures event-engine packet-to-signal latency |
| `sim/tb_event_streaming_stress.sv` | Measures continuous event-stream throughput and stalls |
| `sim/engine_live_main.cpp` | Simple C++ harness for the legacy live engine target |

## Running the Tests

Run all tests:

```bash
make test_all
```

Run only the full engine test:

```bash
make engine
```

Run only the normalized event parser test:

```bash
make event_parser
```

Run only the bounded event order book test:

```bash
make event_book
```

Run only the event risk gate test:

```bash
make event_risk
```

Run randomized event-book verification against the Python golden model:

```bash
make event_book_randomized
```

Override vector count and seed:

```bash
make event_book_randomized EVENT_RANDOM_EVENTS=5000 EVENT_RANDOM_SEED=7
```

Run a 100,000-event streaming stress benchmark:

```bash
make event_stress
```

Run a larger event benchmark:

```bash
make event_stress EVENT_STRESS_EVENTS=1000000
```

Run a small trace-enabled event benchmark:

```bash
make event_stress_trace
```

Run assertion-enabled event integration checks:

```bash
make assertions
```

Run the same regression used by GitHub Actions:

```bash
make ci
```

Run repository consistency checks without invoking Verilator:

```bash
make static_check
```

Run only the integrated event engine test:

```bash
make event_engine
```

Run integrated event risk accept/reject tests:

```bash
make event_engine_risk
```

Run the event-engine latency test:

```bash
make event_latency
```

## Normalized Event Packet Format

The event-engine upgrade introduces a 64-bit packet format for ADD, CANCEL, EXECUTE, and INVALID market events:

```text
[63:62] event type
[61:58] symbol id
[57]    side
[56:41] order id
[40:25] price
[24:9]  quantity
[8:0]   reserved
```

`rtl/market_types_pkg.sv` keeps these fields in a packed struct so modules can pass a single typed event bundle instead of many loose wires.

## Event Order Book

`rtl/event_order_book.sv` is the first event-based book implementation. It intentionally uses small bounded storage for simulation clarity:

- 4 symbols
- 128 tracked order IDs
- 64 direct price levels starting at 10000

The book accepts ADD, CANCEL, EXECUTE, and INVALID events. ADD creates an active order and adds quantity at a price level. CANCEL removes the active order's remaining quantity. EXECUTE subtracts filled quantity and clamps at zero so order quantities do not underflow. Missing CANCEL/EXECUTE events are ignored while preserving the current best bid/ask snapshot.

`scripts/generate_event_tests.py` provides a software golden model for randomized verification. It generates ADD, CANCEL, EXECUTE, and INVALID events, updates an independent Python book model, and writes expected best bid/ask snapshots for the SystemVerilog randomized testbench.

## Event Engine Pipeline

`rtl/event_market_data_engine.sv` keeps the original 32-bit engine intact and adds a parallel 64-bit event path:

```text
64-bit event packet
    |
FIFO
    |
event packet parser
    |
event order book
    |
event signal engine
    |
event risk engine
    |
signal bundle
```

The event signal bundle includes synchronized symbol, bid, ask, bid quantity, ask quantity, spread, risk status, reject code, and trade signal outputs. `signal_valid` is asserted only when the book has both a nonzero bid and a nonzero ask for the output symbol.

`rtl/event_risk_engine.sv` is a first pre-trade risk gate. It allows a strategy trade signal only when:

- the signal bundle is valid
- spread is below `MAX_RISK_SPREAD`
- bid and ask quantities are below `MAX_ORDER_QTY`

The risk engine emits `risk_ok` and a small `risk_reject_code` so tests and future modules can distinguish "no signal" from spread and quantity rejects.

`sim/tb_event_latency.sv` measures the delay from the accepted ask ADD event that makes the book two-sided to the registered `signal_valid` output. The expected event-pipeline latency is currently 3 cycles:

```text
cycle 0: packet accepted into FIFO
cycle 1: FIFO read and parser valid
cycle 2: event order book update
cycle 3: event signal engine output
```

## Engineering Report

See `docs/final_report.md` for a portfolio-style engineering report covering motivation, architecture, event protocol, verification strategy, throughput goals, limitations, and future FPGA work.

For local simulator setup, see `docs/toolchain_setup.md`.

On Windows, `scripts/run_windows_verification.ps1` can run focused verification targets with explicit Verilator and make paths when those tools are installed but not visible on PATH.

See `docs/reference_alignment.md` for how this project uses the provided HFT accelerator report as an architectural reference while keeping the implementation original and appropriately scoped.

## Continuous Integration

The repository includes a GitHub Actions workflow at `.github/workflows/verilator.yml`. On push or pull request, it installs `make`, `python3`, and `verilator`, then runs:

```bash
make ci
```

That target runs the unit/integration regression, assertion-enabled event integration check, legacy streaming stress benchmark, and event streaming stress benchmark.

Run only the latency test:

```bash
make latency
```

Expected latency output:

```text
Measured latency:   3 cycles
PASS: latency test passed
```

## Current Features

- SystemVerilog RTL design
- FIFO buffering
- 32-bit packet parsing
- Multi-symbol top-of-book storage
- Bid/ask spread calculation
- Trade signal generation
- Cycle-based latency measurement
- Verilator simulation flow
- Makefile-based test runner

## Current Limitations

This is a simplified educational engine, not a real trading system.

Current simplifications:

- Simulated packets only
- No real Ethernet or UDP input
- No real exchange protocol
- No order execution logic
- No risk checks
- No multiple price levels per symbol
- No FPGA board deployment yet

## Future Improvements

Possible next upgrades:

- Add randomized packet testing
- Add invalid packet handling
- Add multiple bid/ask levels per symbol
- Add configurable spread threshold per symbol
- Add risk-checking logic
- Add throughput testing
- Add FPGA board synthesis with Vivado
- Add resource usage and timing reports

## Tools Used

- SystemVerilog
- Verilator
- GTKWave
- GNU Make
- Git
- Ubuntu/WSL

## Project Status

Current status:

```text
FIFO complete
Packet parser complete
Frontend pipeline complete
Order book complete
Signal engine complete
Full engine complete
Latency measurement complete
Makefile test runner complete
```

The current version successfully simulates a complete end-to-end market-data processing pipeline and measures a deterministic 3-cycle latency from accepted ask update to generated signal.
