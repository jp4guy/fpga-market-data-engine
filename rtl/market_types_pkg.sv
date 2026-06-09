package market_types_pkg;
    timeunit 1ns;
    timeprecision 1ps;

    typedef enum logic [1:0] {
        EVENT_ADD     = 2'b00,
        EVENT_CANCEL  = 2'b01,
        EVENT_EXECUTE = 2'b10,
        EVENT_INVALID = 2'b11
    } event_type_t;

    typedef struct packed {
        event_type_t type_id;
        logic [3:0]  symbol_id;
        logic        side;
        logic [15:0] order_id;
        logic [15:0] price;
        logic [15:0] quantity;
    } market_event_t;

endpackage
