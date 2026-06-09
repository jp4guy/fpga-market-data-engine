# FPGA Market Data Event Engine Report

## 1. Background and Motivation

This project models the front half of a low-latency market-data accelerator: packets arrive as a stream, are decoded into normalized events, update an order book, and produce a synchronized best bid/ask signal bundle. The goal is not to copy a production HFT design, but to build a readable FPGA-style project with the same engineering purpose: deterministic streaming datapaths, bounded state, backpressure, verification, and measured throughput.

The project direction was cross-checked against a larger HFT accelerator report. The shared ideas are architectural: streaming parser, order-book builder, trading/risk logic, latency measurement, software-reference verification, and honest integration status. This repo deliberately keeps the protocol normalized and the book bounded so the design remains understandable, runnable, and appropriate for an individual portfolio project.

## 2. System Architecture

The original engine remains available as a 32-bit quote-update pipeline:

```text
32-bit quote packet -> FIFO -> parser -> top-of-book store -> signal engine
```

The new event engine adds a parallel 64-bit event pipeline:

```text
64-bit event packet
    |
FIFO/backpressure
    |
event_packet_parser
    |
event_order_book
    |
event_signal_engine
    |
event_risk_engine
    |
best bid/ask + spread + trade signal
```

Keeping the old engine intact while adding the event path makes the upgrade incremental and testable.

## 3. Packet/Event Protocol

The normalized event packet is 64 bits:

```text
[63:62] event type
[61:58] symbol id
[57]    side
[56:41] order id
[40:25] price
[24:9]  quantity
[8:0]   reserved
```

`rtl/market_types_pkg.sv` defines `event_type_t` and `market_event_t`. A packed struct keeps related fields together as one hardware bundle, which makes module interfaces easier to review and less error-prone than passing many unrelated wires.

## 4. Parser Design

`rtl/event_packet_parser.sv` is combinational decode logic. It maps fixed bit ranges into a typed `market_event_t` and passes through `event_valid`.

Because the parser is pure decode logic, it uses `always_comb`: outputs respond immediately to input changes in simulation and synthesize as gates/muxes rather than registers. Clocked state is kept in surrounding pipeline stages such as the FIFO and downstream order book.

## 5. Order Book Design

`rtl/event_order_book.sv` is intentionally bounded for clear simulation:

- 4 symbols
- 128 global order IDs
- 64 direct price levels
- Base price of 10000

The book supports:

- ADD: creates an active order and adds quantity to a price level
- CANCEL: removes an active order's remaining quantity
- EXECUTE: subtracts fill quantity without underflow
- INVALID: produces a snapshot without mutating state

This is not yet a BRAM/tree order book. It is the first correct event-based design step, meant to be verified before moving to a more resource-realistic implementation.

## 6. Signal and Risk Logic

The event signal engine emits a synchronized bundle:

- `signal_valid`
- `signal_symbol`
- `signal_bid`
- `signal_ask`
- `signal_bid_qty`
- `signal_ask_qty`
- `spread`
- `trade_signal`
- `risk_ok`
- `risk_reject_code`

`signal_valid` asserts only when both bid and ask are nonzero and the ask is not below the bid. The strategy signal is spread-threshold based, then `rtl/event_risk_engine.sv` gates it with basic pre-trade checks: max spread and max displayed quantity. Future work can add position limits, order-rate checks, symbol-specific thresholds, and kill-switch logic.

## 7. Verification Methodology

The project now uses several verification layers:

- Fixed unit tests for parser and deterministic order-book behavior
- Event-engine integration test for parser/book/signal alignment
- Event risk gate unit test for spread and quantity rejects
- Integrated event-engine risk test for top-level accept/reject behavior
- Python golden model generation for randomized event-order-book vectors
- Streaming stress tests for continuous input throughput and stalls
- SystemVerilog assertions for FIFO and signal-bundle invariants

The Python model is intentionally independent from RTL syntax. It updates a software book and writes expected snapshots that the randomized SystemVerilog testbench compares against.

## 8. Latency and Throughput Analysis

The original quote engine documents a 3-cycle measured latency. The event engine adds a FIFO, parser, event book, and registered signal stage. Once Verilator is available locally, the key commands are:

```bash
make event_engine
make event_latency
make event_stress
make event_stress EVENT_STRESS_EVENTS=1000000
make test_all
```

The event latency test measures from the accepted ADD ask event that creates a two-sided book to the registered signal output. The current expected event latency is 3 cycles. The stress test reports accepted events, measurement cycles, stalls, signal outputs, and errors. The target for the current FIFO-driven event path is one accepted event per cycle with zero input stalls under the provided stream pattern.

Continuous integration is defined in `.github/workflows/verilator.yml`. The CI job installs Verilator and runs `make ci`, which covers fixed tests, randomized event-book vectors, assertion-enabled event integration, and streaming stress benchmarks.

The repository also includes `scripts/check_repo_static.py`, a lightweight consistency check that verifies Makefile targets, referenced source files, documentation snippets, and generated-file ignore rules before the simulator starts.

Top-level simulations use ordered filelists in `filelists/` so package and module source ordering is explicit and reviewable.

## 9. Resource and Timing Future Work

The current design is simulation-oriented. Future FPGA-facing work should replace or augment the direct arrays with:

- ITCH-like byte-stream parser or AXI-stream input wrapper
- BRAM-backed order storage
- Price-level memory with explicit read/write latency
- Tree or priority-search structure for best bid/ask
- AXI-stream or Avalon-stream style ready/valid interfaces
- Synthesis and timing reports from a vendor FPGA flow

## 10. Lessons Learned

Hardware design improves when each stage has a crisp contract. The parser owns bitfield decode, the FIFO owns backpressure, the book owns market state, and the signal engine owns the output bundle. Assertions and randomized golden-model testing make those contracts visible, which is what moves the project from a toy demo toward a serious engineering portfolio artifact.
