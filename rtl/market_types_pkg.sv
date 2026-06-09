`timescale 1ns/1ps

package market_types_pkg;

    localparam int EVENT_TYPE_WIDTH = 2;
    localparam int SYMBOL_WIDTH     = 4;
    localparam int ORDER_ID_WIDTH   = 16;
    localparam int PRICE_WIDTH      = 16;
    localparam int QUANTITY_WIDTH   = 16;

    typedef enum logic [EVENT_TYPE_WIDTH-1:0] {
        EVENT_ADD     = 2'd0,
        EVENT_CANCEL  = 2'd1,
        EVENT_EXECUTE = 2'd2,
        EVENT_INVALID = 2'd3
    } event_type_t;

    typedef struct packed {
        event_type_t                    event_type;
        logic [SYMBOL_WIDTH-1:0]        symbol_id;
        logic                           side;
        logic [ORDER_ID_WIDTH-1:0]      order_id;
        logic [PRICE_WIDTH-1:0]         price;
        logic [QUANTITY_WIDTH-1:0]      quantity;
    } market_event_t;

endpackage
