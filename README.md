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
| `rtl/market_data_frontend.sv` | Connects FIFO to parser |
| `rtl/order_book.sv` | Stores best bid and ask for each symbol |
| `rtl/signal_engine.sv` | Calculates spread and generates trade signal |
| `rtl/market_data_engine.sv` | Top-level full pipeline |

## Tests

| Testbench | Purpose |
|---|---|
| `sim/tb_smoke.sv` | Basic Verilator smoke test |
| `sim/tb_fifo.sv` | Tests FIFO push/pop behavior |
| `sim/tb_packet_parser.sv` | Tests packet decoding |
| `sim/tb_market_data_frontend.sv` | Tests FIFO-to-parser pipeline |
| `sim/tb_order_book.sv` | Tests bid/ask storage |
| `sim/tb_signal_engine.sv` | Tests spread calculation and signal generation |
| `sim/tb_market_data_engine.sv` | Tests full end-to-end engine |
| `sim/tb_latency.sv` | Measures end-to-end signal latency |

## Running the Tests

Run all tests:

```bash
make test_all
```

Run only the full engine test:

```bash
make engine
```

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
