#include "Vmarket_data_engine.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

namespace {

vluint64_t sim_time = 0;

std::uint32_t make_packet(
    std::uint32_t message_type,
    std::uint32_t symbol_id,
    std::uint32_t side,
    std::uint32_t price
) {
    return ((message_type & 0xFu) << 28) |
           ((symbol_id & 0xFu) << 24) |
           ((side & 0x1u) << 23) |
           (price & 0x7FFFFFu);
}

void tick(Vmarket_data_engine* top) {
    top->clk = 0;
    top->eval();
    sim_time++;

    top->clk = 1;
    top->eval();
    sim_time++;
}

void send_packet(Vmarket_data_engine* top, std::uint32_t packet) {
    top->in_packet = packet;
    top->in_valid = 1;
    tick(top);
    top->in_valid = 0;
    top->in_packet = 0;
}

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    auto* top = new Vmarket_data_engine;

    top->rst = 1;
    top->in_valid = 0;
    top->in_packet = 0;

    tick(top);
    tick(top);
    top->rst = 0;

    send_packet(top, make_packet(1, 0, 0, 10005));
    send_packet(top, make_packet(1, 0, 1, 10010));

    for (int i = 0; i < 10; ++i) {
        tick(top);

        if (top->signal_valid) {
            std::cout << "signal_valid at sim_time=" << sim_time
                      << " symbol=" << static_cast<int>(top->signal_symbol)
                      << " bid=" << top->signal_bid
                      << " ask=" << top->signal_ask
                      << " spread=" << top->spread
                      << " trade_signal=" << static_cast<int>(top->trade_signal)
                      << '\n';
        }
    }

    top->final();
    delete top;

    return 0;
}
