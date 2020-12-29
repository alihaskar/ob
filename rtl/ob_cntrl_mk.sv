//========================================================================== //
// Copyright (c) 2020, Stephen Henry
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//========================================================================== //

`include "ob_pkg.vh"
`include "macros_pkg.vh"

module ob_cntrl_mk (

  // ======================================================================== //
  // Bid Table Interface
    input                                         lm_bid_vld_r
  , input ob_pkg::table_t                         lm_bid_r

  // ======================================================================== //
  // Ask Table Interface
  , input                                         lm_ask_vld_r
  , input ob_pkg::table_t                         lm_ask_r

  // ======================================================================== //
  // Market Buy Interface
  , input logic                                   mk_bid_head_vld_r
  , input ob_pkg::table_t                         mk_bid_head_r

  // ======================================================================== //
  // Market Sell Interface
  , input logic                                   mk_ask_head_vld_r
  , input ob_pkg::table_t                         mk_ask_head_r

  // ======================================================================== //
  // Decision Interface
  , input                                         trade_qry
  //
  , output logic                                  trade_vld_r
  , output ob_pkg::search_result_t                trade_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  ob_pkg::quantity_arith_t              mk_ask_mk_bid_quantity_bid;
  logic                                 mk_ask_mk_bid_excess_bid;
  ob_pkg::quantity_arith_t              mk_ask_mk_bid_quantity_ask;
  logic                                 mk_ask_mk_bid_excess_ask;
  logic                                 mk_ask_mk_bid_do_trade;
  bcd_pkg::price_t                      mk_ask_mk_bid_price;
  logic                                 mk_ask_mk_bid_ask_consumed;
  logic                                 mk_ask_mk_bid_bid_consumed;
  ob_pkg::quantity_t                    mk_ask_mk_bid_quantity;
  ob_pkg::quantity_t                    mk_ask_mk_bid_remainder;

  always_comb begin : mk_PROC

    // Compute excess Bid quantity.
    //
    mk_ask_mk_bid_quantity_bid = (mk_bid_head_r.quantity - mk_ask_head_r.quantity);

    // Flag indicating that the current head market buy order quantity exceeds
    // the corresponding head market sell order quantity.
    //
    mk_ask_mk_bid_excess_bid   = (mk_ask_mk_bid_quantity_bid > 0);

    // Compute excess Ask quantity.
    //
    mk_ask_mk_bid_quantity_ask = (mk_ask_head_r.quantity - mk_bid_head_r.quantity);

    // Flag indiciating that the Ask quantity exceeds the Bid quantity.
    //
    mk_ask_mk_bid_excess_ask   = (mk_ask_mk_bid_quantity_ask > 0);

    // A trade can occur by default whenever the market buy/sell queues are
    // non-empty.
    //
    mk_ask_mk_bid_do_trade     = (mk_bid_head_vld_r & mk_ask_head_vld_r);

    // In the Market <-> Market case, the price at which the trade occurs is not
    // necessarily relevant, as the trade takes place simply in the presence of
    // current market bid/ask orders. Logically therefore, the trade occufrs
    // at the current asking price, whatever that price is in relation to
    // the bidding price of the corresponding market bid order.
    //
    mk_ask_mk_bid_price        = mk_ask_head_r.price;

    case ({// Quantity(Bid) > Quantity(Ask)
           mk_ask_mk_bid_excess_bid,
           // Quantity(Ask) > Quantity(Bid)
           mk_ask_mk_bid_excess_ask }) inside
      2'b00: begin
        // Quantity(Bid) == Quantity(Ask)
        mk_ask_mk_bid_ask_consumed = 'b1;
        mk_ask_mk_bid_bid_consumed = 'b1;
        mk_ask_mk_bid_quantity     = mk_bid_head_r.quantity;
        mk_ask_mk_bid_remainder    = '0; // N/A
      end
      2'b10: begin
        // Quantity(Bid) > Quantity(Ask)
        mk_ask_mk_bid_ask_consumed = 'b1;
        mk_ask_mk_bid_bid_consumed = 'b0;
        mk_ask_mk_bid_quantity     = mk_ask_head_r.quantity;
        mk_ask_mk_bid_remainder    =
          ob_pkg::quantity_t'(mk_ask_mk_bid_quantity_bid);
      end
      2'b01: begin
        // Quantity(Ask) > Quantity(Bid)
        mk_ask_mk_bid_ask_consumed = 'b0;
        mk_ask_mk_bid_bid_consumed = 'b1;
        mk_ask_mk_bid_quantity     = mk_bid_head_r.quantity;
        mk_ask_mk_bid_remainder    =
          ob_pkg::quantity_t'(mk_ask_mk_bid_quantity_ask);
      end
      default: begin
        // Otherwise, trade does not occur.
        mk_ask_mk_bid_ask_consumed = 'b0;
        mk_ask_mk_bid_bid_consumed = 'b0;
        mk_ask_mk_bid_quantity     = '0;
        mk_ask_mk_bid_remainder    = '0;
      end
    endcase // case ({...

  end // block: mk_PROC

  // ------------------------------------------------------------------------ //
  //
  ob_pkg::quantity_arith_t              mk_ask_lm_bid_cmp_quantity_lm;
  logic                                 mk_ask_lm_bid_excess_lm;
  ob_pkg::quantity_arith_t              mk_ask_lm_bid_cmp_quantity_mk;
  logic                                 mk_ask_lm_bid_excess_mk;
  logic                                 mk_ask_lm_bid_do_trade;
  logic                                 mk_ask_lm_bid_ask_consumed;
  logic                                 mk_ask_lm_bid_bid_consumed;
  ob_pkg::quantity_t                    mk_ask_lm_bid_quantity;
  ob_pkg::quantity_t                    mk_ask_lm_bid_remainder;

  always_comb begin : mk_ask_lm_bid_PROC

    // Compute relative delta between Limit Buy/Market Sell orders.
    //
    mk_ask_lm_bid_cmp_quantity_lm = (lm_bid_r.quantity - mk_ask_head_r.quantity);

    // For Limit Buy to Market trade, flag indicates that Limit quantity
    // exceeds Market quantity.
    //
    mk_ask_lm_bid_excess_lm       = (mk_ask_lm_bid_cmp_quantity_lm > 0);

    // Compute relative delta between Limit Buy/Market Sell orders.
    //
    mk_ask_lm_bid_cmp_quantity_mk = (mk_ask_head_r.quantity - lm_bid_r.quantity);

    // For Limit Buy to Market trade, flag indicates that Limit quantity
    // exceeds Market quantity.
    //
    mk_ask_lm_bid_excess_mk       = (mk_ask_lm_bid_cmp_quantity_mk > 0);

    // Limit Buy <-> Market Sell occurs whenever entries are present in both
    // tables (disregard relative prices).
    //
    mk_ask_lm_bid_do_trade        = lm_bid_vld_r & mk_ask_head_vld_r;

    // If a trade occurs, compute the update to the machine's state.
    //
    case ({//
           mk_ask_lm_bid_excess_lm,
           //
           mk_ask_lm_bid_excess_mk}) inside
      2'b00: begin
        // No excess on Bid/Ask therefore quantities are equal and therefore
        // both are consumed
        mk_ask_lm_bid_ask_consumed = 'b1;
        mk_ask_lm_bid_bid_consumed = 'b1;
        mk_ask_lm_bid_quantity     = '0;
        mk_ask_lm_bid_remainder    = '0; // N/A
      end
      2'b10: begin
        // Quantity(LM) > Quantity(MK)
        mk_ask_lm_bid_ask_consumed = 'b1;
        mk_ask_lm_bid_bid_consumed = 'b0;
        mk_ask_lm_bid_quantity     = mk_ask_head_r.quantity;
        mk_ask_lm_bid_remainder    =
          ob_pkg::quantity_t'(mk_ask_lm_bid_cmp_quantity_lm);
      end
      2'b01: begin
        // Quantity(MK) > Quantity(LM)
        mk_ask_lm_bid_ask_consumed = 'b0;
        mk_ask_lm_bid_bid_consumed = 'b1;
        mk_ask_lm_bid_quantity     = lm_bid_r.quantity;
        mk_ask_lm_bid_remainder    =
          ob_pkg::quantity_t'(mk_ask_lm_bid_cmp_quantity_mk);
      end
      default: begin
        // Otherwise, trade does not occur.
        mk_ask_lm_bid_ask_consumed = 'b0;
        mk_ask_lm_bid_bid_consumed = 'b0;
        mk_ask_lm_bid_quantity     = '0;
        mk_ask_lm_bid_remainder    = '0;
      end
    endcase // case ({...

  end // block: lm_PROC

  // ------------------------------------------------------------------------ //
  //
  ob_pkg::quantity_arith_t              mk_bid_lm_ask_cmp_quantity_lm;
  logic                                 mk_bid_lm_ask_excess_lm;
  ob_pkg::quantity_arith_t              mk_bid_lm_ask_cmp_quantity_mk;
  logic                                 mk_bid_lm_ask_excess_mk;
  logic                                 mk_bid_lm_ask_do_trade;
  logic                                 mk_bid_lm_ask_ask_consumed;
  logic                                 mk_bid_lm_ask_bid_consumed;
  ob_pkg::quantity_t                    mk_bid_lm_ask_quantity;
  ob_pkg::quantity_t                    mk_bid_lm_ask_remainder;

  always_comb begin : mk_bid_lm_ask_PROC

    // Compute relative delta between Limit Buy/Market Sell orders.
    //
    mk_bid_lm_ask_cmp_quantity_lm = (lm_ask_r.quantity - mk_bid_head_r.quantity);

    // For Limit Buy to Market trade, flag indicates that Limit quantity
    // exceeds Market quantity.
    //
    mk_bid_lm_ask_excess_lm       = (mk_bid_lm_ask_cmp_quantity_lm > 0);

    // Compute relative delta between Limit Buy/Market Sell orders.
    //
    mk_bid_lm_ask_cmp_quantity_mk = (mk_bid_head_r.quantity - lm_ask_r.quantity);

    // For Limit Buy to Market trade, flag indicates that Limit quantity
    // exceeds Market quantity.
    //
    mk_bid_lm_ask_excess_mk       = (mk_bid_lm_ask_cmp_quantity_mk > 0);

    // Limit Buy <-> Market Sell occurs whenever entries are present in both
    // tables (disregard relative prices).
    //
    mk_bid_lm_ask_do_trade        = lm_ask_vld_r & mk_bid_head_vld_r;

    // If a trade occurs, compute the update to the machine's state.
    //
    case ({//
           mk_bid_lm_ask_excess_lm,
           //
           mk_bid_lm_ask_excess_mk}) inside
      2'b00: begin
        // No excess on Bid/Ask therefore quantities are equal and therefore
        // both are consumed
        mk_bid_lm_ask_ask_consumed = 'b1;
        mk_bid_lm_ask_bid_consumed = 'b1;
        mk_bid_lm_ask_quantity     = '0;
        mk_bid_lm_ask_remainder    = '0; // N/A
      end
      2'b10: begin
        // Quantity(LM) > Quantity(MK)
        mk_bid_lm_ask_ask_consumed = 'b1;
        mk_bid_lm_ask_bid_consumed = 'b0;
        mk_bid_lm_ask_quantity     = mk_ask_head_r.quantity;
        mk_bid_lm_ask_remainder    =
          ob_pkg::quantity_t'(mk_bid_lm_ask_cmp_quantity_lm);
      end
      2'b01: begin
        // Quantity(MK) > Quantity(LM)
        mk_bid_lm_ask_ask_consumed = 'b0;
        mk_bid_lm_ask_bid_consumed = 'b1;
        mk_bid_lm_ask_quantity     = lm_bid_r.quantity;
        mk_bid_lm_ask_remainder    =
          ob_pkg::quantity_t'(mk_bid_lm_ask_cmp_quantity_mk);
      end
      default: begin
        // Otherwise, trade does not occur.
        mk_bid_lm_ask_ask_consumed = 'b0;
        mk_bid_lm_ask_bid_consumed = 'b0;
        mk_bid_lm_ask_quantity     = '0;
        mk_bid_lm_ask_remainder    = '0;
      end
    endcase // case ({...

  end // block: mk_bid_lm_ask_PROC

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST_W(logic, trade_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::search_result_t, trade);

  always_comb begin : decision_PROC

    // Defaults:
    trade_vld_w = 'b0;

    // Retain prior by default.
    trade_w     = '0;

    // From precomputed state, select the candidate trade that can take place in
    // the current cycle. Prefer Limit <-> Market, over Market <-> Market as
    // these trade enjoy a higher overall commission per trade.
    //
    case  ({// Query current tradeable state
            trade_qry,
            // Limit Buy <-> Market Sell trade
            mk_ask_lm_bid_do_trade,
            // Limit Sell <-> Market Buy trade
            mk_bid_lm_ask_do_trade,
            // Market Sell <-> Market Buy trade
            mk_ask_mk_bid_do_trade
            }) inside
      4'b1_1??: begin
        // Limit Buy <-> Market Sell trade takes place
        trade_vld_w           = 'b1;
        trade_w.mk_ask_lm_bid = 'b1;
        // Market:
        trade_w.ask_uid       = mk_ask_head_r.uid;
        trade_w.ask_price     = mk_ask_head_r.price;
        trade_w.ask_consumed  = mk_ask_lm_bid_ask_consumed;
        // Limit:
        trade_w.bid_uid       = lm_bid_r.uid;
        trade_w.bid_price     = lm_bid_r.price;
        trade_w.bid_consumed  = mk_ask_lm_bid_bid_consumed;
        // Remainder:
        trade_w.quantity      = mk_ask_lm_bid_quantity;
        trade_w.remainder     = mk_ask_lm_bid_remainder;
      end
      4'b1_01?: begin
        // Limit Sell <-> Market Buy trade takes place
        trade_vld_w           = 'b1;
        trade_w.lm_ask_mk_bid = 'b1;
        // Limit:
        trade_w.ask_uid       = lm_ask_r.uid;
        trade_w.ask_price     = lm_ask_r.price;
        trade_w.ask_consumed  = mk_bid_lm_ask_ask_consumed;
        // Market:
        trade_w.bid_uid       = mk_bid_head_r.uid;
        trade_w.bid_price     = mk_bid_head_r.price;
        trade_w.bid_consumed  = mk_bid_lm_ask_bid_consumed;
        // Remainder:
        trade_w.quantity      = mk_bid_lm_ask_quantity;
        trade_w.remainder     = mk_bid_lm_ask_remainder;
      end
      4'b1_001: begin
        // Market Sell <-> Market Buy trade takes place
        trade_vld_w           = 'b1;
        trade_w.mk_ask_mk_bid = 'b1;
        // Market:
        trade_w.ask_uid       = mk_ask_head_r.uid;
        trade_w.ask_price     = mk_ask_mk_bid_price;
        trade_w.ask_consumed  = mk_ask_mk_bid_ask_consumed;
        // Market:
        trade_w.bid_uid       = mk_bid_head_r.uid;
        trade_w.bid_price     = mk_ask_mk_bid_price;
        trade_w.bid_consumed  = mk_ask_mk_bid_bid_consumed;
        // Remainder:
        trade_w.quantity      = mk_ask_mk_bid_quantity;
        trade_w.remainder     = mk_ask_mk_bid_remainder;
      end
      default: begin
        // Otherwise, no trade occurs. Drive to quiescent state.
        trade_vld_w = 'b0;
      end
    endcase // casez ({...

    // Enables:
    //
    trade_en = trade_vld_w;

  end // block: decision_PROC

endmodule // ob_cntrl_mk
