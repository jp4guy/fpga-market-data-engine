# Reference Alignment

The reference HFT accelerator report is useful as a direction-setting document, not as source material to copy. The engineering themes that matter for this project are:

- A streaming market-data path that decodes feed messages before updating market state
- Backpressure-aware buffering so short bursts do not silently corrupt the pipeline
- An event/order-book core that supports add, cancel, and trade/execute style messages
- Verification against a software reference model
- Explicit latency, throughput, and resource discussions
- Clear separation between parser, book builder, trading logic, and integration work
- Honest status reporting: what works in simulation, what is integrated, and what remains future work

This repo follows the same purpose at a smaller and more portfolio-friendly scale:

```text
64-bit normalized event packet
    |
FIFO/backpressure
    |
event parser
    |
bounded event order book
    |
best bid/ask snapshot
    |
signal engine
    |
risk gate
    |
trade signal bundle
```

Key differences are intentional:

- The input is a normalized 64-bit event packet rather than a full Ethernet/TCP/ITCH parser.
- The order book is bounded and direct-mapped for simulation clarity before any BRAM/tree implementation.
- The strategy is spread-threshold based rather than a larger quantitative model.
- Verification is centered on Verilator, deterministic tests, randomized Python golden vectors, assertions, and CI.
- Board deployment, Ethernet integration, synthesis/timing, and resource reports are listed as future work rather than implied as complete.

The next architecture upgrades inspired by the reference are:

- Add an AXI-stream style valid/ready packet interface.
- Add replace/modify event support as cancel-plus-add behavior.
- Move the book toward explicit memory-latency modeling.
- Add resource/timing estimates once a synthesis toolchain is available.
- Expand performance reporting with per-stage latency measurements.
