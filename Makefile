.RECIPEPREFIX := >

VERILATOR = verilator
FLAGS = -Wall -Wno-BLKSEQ -Wno-UNUSEDSIGNAL --binary --trace

.PHONY: smoke fifo parser frontend order_book signal_engine engine test_all clean

smoke:
>$(VERILATOR) $(FLAGS) sim/tb_smoke.sv rtl/smoke_counter.sv -o smoke_test
>./obj_dir/smoke_test

fifo:
>$(VERILATOR) $(FLAGS) sim/tb_fifo.sv rtl/fifo.sv -o fifo_test
>./obj_dir/fifo_test

parser:
>$(VERILATOR) $(FLAGS) sim/tb_packet_parser.sv rtl/packet_parser.sv -o parser_test
>./obj_dir/parser_test

frontend:
>$(VERILATOR) $(FLAGS) sim/tb_market_data_frontend.sv rtl/market_data_frontend.sv rtl/fifo.sv rtl/packet_parser.sv -o frontend_test
>./obj_dir/frontend_test

order_book:
>$(VERILATOR) $(FLAGS) sim/tb_order_book.sv rtl/order_book.sv -o order_book_test
>./obj_dir/order_book_test

signal_engine:
>$(VERILATOR) $(FLAGS) sim/tb_signal_engine.sv rtl/signal_engine.sv -o signal_engine_test
>./obj_dir/signal_engine_test

engine:
>$(VERILATOR) $(FLAGS) sim/tb_market_data_engine.sv rtl/market_data_engine.sv rtl/market_data_frontend.sv rtl/fifo.sv rtl/packet_parser.sv rtl/order_book.sv rtl/signal_engine.sv -o engine_test
>./obj_dir/engine_test

test_all: smoke fifo parser frontend order_book signal_engine engine

clean:
>rm -rf obj_dir
>rm -f *.vcd *.fst
>rm -f Vtb_* verilated*.d verilated*.o
