#!/usr/bin/env python3
"""Generate randomized event-order-book vectors with a golden model."""

from __future__ import annotations

import argparse
import random
from dataclasses import dataclass


EVENT_ADD = 0
EVENT_CANCEL = 1
EVENT_EXECUTE = 2
EVENT_INVALID = 3


@dataclass
class Order:
    symbol_id: int
    side: int
    price: int
    quantity: int


class GoldenBook:
    def __init__(self, num_symbols: int, max_orders: int, price_levels: int, base_price: int) -> None:
        self.num_symbols = num_symbols
        self.max_orders = max_orders
        self.price_levels = price_levels
        self.base_price = base_price
        self.orders: dict[int, Order] = {}
        self.level_qty = [
            [[0 for _ in range(price_levels)] for _ in range(2)]
            for _ in range(num_symbols)
        ]

    def apply(self, type_id: int, symbol_id: int, side: int, order_id: int, price: int, quantity: int) -> None:
        symbol_in_range = 0 <= symbol_id < self.num_symbols
        order_in_range = 0 <= order_id < self.max_orders
        price_idx = price - self.base_price
        price_in_range = 0 <= price_idx < self.price_levels

        if not symbol_in_range:
            return

        if type_id == EVENT_ADD:
            if order_in_range and price_in_range and quantity != 0 and order_id not in self.orders:
                self.orders[order_id] = Order(symbol_id, side, price, quantity)
                self.level_qty[symbol_id][side][price_idx] += quantity
        elif type_id == EVENT_CANCEL:
            order = self.orders.pop(order_id, None)
            if order is not None:
                self.level_qty[order.symbol_id][order.side][order.price - self.base_price] -= order.quantity
        elif type_id == EVENT_EXECUTE:
            order = self.orders.get(order_id)
            if order is not None:
                fill_qty = min(quantity, order.quantity)
                self.level_qty[order.symbol_id][order.side][order.price - self.base_price] -= fill_qty
                order.quantity -= fill_qty
                if order.quantity == 0:
                    del self.orders[order_id]

    def snapshot(self, symbol_id: int) -> tuple[int, int, int, int]:
        if not 0 <= symbol_id < self.num_symbols:
            return 0, 0, 0, 0

        bid = 0
        bid_qty = 0
        for idx, qty in enumerate(self.level_qty[symbol_id][0]):
            if qty != 0:
                bid = self.base_price + idx
                bid_qty = qty

        ask = 0
        ask_qty = 0
        for idx, qty in enumerate(self.level_qty[symbol_id][1]):
            if qty != 0:
                ask = self.base_price + idx
                ask_qty = qty
                break

        return bid, ask, bid_qty, ask_qty


def choose_event(rng: random.Random, book: GoldenBook) -> tuple[int, int, int, int, int, int]:
    active_ids = list(book.orders)
    roll = rng.randrange(100)

    if active_ids and roll < 25:
        order_id = rng.choice(active_ids)
        return EVENT_CANCEL, rng.randrange(book.num_symbols), rng.randrange(2), order_id, 0, 0

    if active_ids and roll < 55:
        order_id = rng.choice(active_ids)
        order = book.orders[order_id]
        quantity = rng.randint(1, max(order.quantity + 5, 1))
        return EVENT_EXECUTE, rng.randrange(book.num_symbols), rng.randrange(2), order_id, 0, quantity

    if roll < 90:
        order_id = rng.randrange(book.max_orders)
        symbol_id = rng.randrange(book.num_symbols)
        side = rng.randrange(2)
        price = book.base_price + rng.randrange(book.price_levels)
        quantity = rng.randint(1, 200)
        return EVENT_ADD, symbol_id, side, order_id, price, quantity

    return EVENT_INVALID, rng.randrange(book.num_symbols), rng.randrange(2), rng.randrange(book.max_orders), 0, 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--events", type=int, default=500)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--output", default="sim/generated_event_order_book_vectors.txt")
    parser.add_argument("--num-symbols", type=int, default=4)
    parser.add_argument("--max-orders", type=int, default=128)
    parser.add_argument("--price-levels", type=int, default=64)
    parser.add_argument("--base-price", type=int, default=10000)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    book = GoldenBook(args.num_symbols, args.max_orders, args.price_levels, args.base_price)
    rows: list[tuple[int, ...]] = []

    for _ in range(args.events):
        type_id, symbol_id, side, order_id, price, quantity = choose_event(rng, book)
        book.apply(type_id, symbol_id, side, order_id, price, quantity)
        best_bid, best_ask, best_bid_qty, best_ask_qty = book.snapshot(symbol_id)
        rows.append((
            type_id,
            symbol_id,
            side,
            order_id,
            price,
            quantity,
            best_bid,
            best_ask,
            best_bid_qty,
            best_ask_qty,
        ))

    with open(args.output, "w", encoding="utf-8") as out_file:
        out_file.write(f"{len(rows)}\n")
        for row in rows:
            out_file.write(" ".join(str(value) for value in row))
            out_file.write("\n")


if __name__ == "__main__":
    main()
