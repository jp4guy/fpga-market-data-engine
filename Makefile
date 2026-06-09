.RECIPEPREFIX := >

VERILATOR = verilator
PYTHON = python3
FLAGS = -Wall -Wno-BLKSEQ -Wno-UNUSEDSIGNAL --binary --trace
ASSERT_FLAGS = $(FLAGS) --assert
LEGACY_ENGINE_SRCS = -f filelists/legacy_engine.f
EVENT_ENGINE_SRCS = -f filelists/event_engine.f
EVENT_RANDOM_EVENTS ?= 500
EVENT_RANDOM_SEED ?= 1
EVENT_STRESS_EVENTS ?= 100000
EVENT_TRACE_EVENTS ?= 500

.PHONY: smoke fifo parser event_parser frontend order_book event_book event_book_randomized event_risk signal_engine engine event_engine event_engine_risk latency event_latency live test_all throughput assertions static_check ci clean event_stress event_stress_trace

smoke:
>$(VERILATOR) $(FLAGS) sim/tb_smoke.sv rtl/smoke_counter.sv -o smoke_test
>./obj_dir/smoke_test

fifo:
>$(VERILATOR) $(FLAGS) sim/tb_fifo.sv rtl/fifo.sv -o fifo_test
>./obj_dir/fifo_test

parser:
>$(VERILATOR) $(FLAGS) sim/tb_packet_parser.sv rtl/packet_parser.sv -o parser_test
>./obj_dir/parser_test

event_parser:
>$(VERILATOR) $(FLAGS) rtl/market_types_pkg.sv rtl/event_packet_parser.sv sim/tb_event_packet_parser.sv -o event_parser_test
>./obj_dir/event_parser_test

frontend:
>$(VERILATOR) $(FLAGS) sim/tb_market_data_frontend.sv rtl/market_data_frontend.sv rtl/fifo.sv rtl/packet_parser.sv -o frontend_test
>./obj_dir/frontend_test

order_book:
>$(VERILATOR) $(FLAGS) sim/tb_order_book.sv rtl/order_book.sv -o order_book_test
>./obj_dir/order_book_test

event_book:
>$(VERILATOR) $(FLAGS) rtl/market_types_pkg.sv rtl/event_order_book.sv sim/tb_event_order_book.sv -o event_order_book_test
>./obj_dir/event_order_book_test

event_book_randomized:
>$(PYTHON) scripts/generate_event_tests.py --events $(EVENT_RANDOM_EVENTS) --seed $(EVENT_RANDOM_SEED)
>$(VERILATOR) $(FLAGS) rtl/market_types_pkg.sv rtl/event_order_book.sv sim/tb_event_order_book_randomized.sv -o event_order_book_randomized_test
>./obj_dir/event_order_book_randomized_test

event_risk:
>$(VERILATOR) $(FLAGS) sim/tb_event_risk_engine.sv rtl/event_risk_engine.sv -o event_risk_engine_test
>./obj_dir/event_risk_engine_test

signal_engine:
>$(VERILATOR) $(FLAGS) sim/tb_signal_engine.sv rtl/signal_engine.sv -o signal_engine_test
>./obj_dir/signal_engine_test

engine:
>$(VERILATOR) $(FLAGS) sim/tb_market_data_engine.sv $(LEGACY_ENGINE_SRCS) -o engine_test
>./obj_dir/engine_test

event_engine:
>$(VERILATOR) $(FLAGS) -f filelists/event_engine.f sim/tb_event_market_data_engine.sv -o event_engine_test
>./obj_dir/event_engine_test

event_engine_risk:
>$(VERILATOR) $(FLAGS) $(EVENT_ENGINE_SRCS) sim/tb_event_market_data_engine_risk.sv -o event_engine_risk_test
>./obj_dir/event_engine_risk_test

latency:
>$(VERILATOR) $(FLAGS) sim/tb_latency.sv $(LEGACY_ENGINE_SRCS) -o latency_test
>./obj_dir/latency_test

event_latency:
>$(VERILATOR) $(FLAGS) $(EVENT_ENGINE_SRCS) sim/tb_event_latency.sv -o event_latency_test
>./obj_dir/event_latency_test

live:
>$(VERILATOR) -Wall -Wno-BLKSEQ -Wno-UNUSEDSIGNAL --trace --cc $(LEGACY_ENGINE_SRCS) --top-module market_data_engine --exe sim/engine_live_main.cpp --build -o live_engine
>./obj_dir/live_engine

randomized:
>$(VERILATOR) $(FLAGS) sim/tb_randomized_engine.sv $(LEGACY_ENGINE_SRCS) -o randomized_engine_test
>./obj_dir/randomized_engine_test

throughput:
>$(VERILATOR) $(FLAGS) sim/tb_throughput_engine.sv $(LEGACY_ENGINE_SRCS) -o throughput_engine_test
>./obj_dir/throughput_engine_test

assertions:
>$(VERILATOR) $(ASSERT_FLAGS) sim/tb_event_market_data_engine.sv $(EVENT_ENGINE_SRCS) -o event_assertions_test
>./obj_dir/event_assertions_test

static_check:
>$(PYTHON) scripts/check_repo_static.py

test_all: smoke fifo parser event_parser frontend order_book event_book event_book_randomized event_risk signal_engine engine event_engine event_engine_risk latency event_latency randomized throughput

ci: static_check test_all assertions stress event_stress

clean:
>rm -rf obj_dir
>rm -f *.vcd *.fst
>rm -f Vtb_* verilated*.d verilated*.o

STRESS_PACKETS ?= 100000
TRACE_PACKETS ?= 500

.PHONY: stress stress_trace

stress:
>$(VERILATOR) $(FLAGS) sim/tb_streaming_stress.sv $(LEGACY_ENGINE_SRCS) -o streaming_stress_test
>./obj_dir/streaming_stress_test +NUM_PACKETS=$(STRESS_PACKETS)

stress_trace:
>$(VERILATOR) $(FLAGS) sim/tb_streaming_stress.sv $(LEGACY_ENGINE_SRCS) -o streaming_stress_test
>./obj_dir/streaming_stress_test +NUM_PACKETS=$(TRACE_PACKETS) +TRACE

event_stress:
>$(VERILATOR) $(FLAGS) $(EVENT_ENGINE_SRCS) sim/tb_event_streaming_stress.sv -o event_streaming_stress_test
>./obj_dir/event_streaming_stress_test +NUM_EVENTS=$(EVENT_STRESS_EVENTS)

event_stress_trace:
>$(VERILATOR) $(FLAGS) $(EVENT_ENGINE_SRCS) sim/tb_event_streaming_stress.sv -o event_streaming_stress_test
>./obj_dir/event_streaming_stress_test +NUM_EVENTS=$(EVENT_TRACE_EVENTS) +TRACE
.PHONY: event_parser

event_parser:
>$(VERILATOR) $(FLAGS) rtl/market_types_pkg.sv rtl/event_packet_parser.sv sim/tb_event_packet_parser.sv -o event_parser_test
>./obj_dir/event_parser_test
