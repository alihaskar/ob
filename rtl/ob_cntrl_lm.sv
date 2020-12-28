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

module ob_cntrl_lm (

  // ======================================================================== //
  // Bid Table Interface
    input                                         lm_bid_vld_r
  , input ob_pkg::table_t                         lm_bid_r

  // ======================================================================== //
  // Ask Table Interface
  , input                                         lm_ask_vld_r
  , input ob_pkg::table_t                         lm_ask_r

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
  logic                                 lm_ask_lm_bid_do_trade;
  ob_pkg::quantity_arith_t              lm_ask_lm_bid_ask_excess;
  ob_pkg::quantity_arith_t              lm_ask_lm_bid_bid_excess;
  logic                                 lm_ask_lm_bid_ask_has_more;
  logic                                 lm_ask_lm_bid_bid_has_more;
  logic                                 lm_ask_lm_bid_bid_ask_equal;

  always_comb begin : lm_ask_lm_bid_PROC

    // A trade can take place if the current maximum bid exceeds (or
    // is equal to) the current minimum ask.
    //
    case ({trade_qry, lm_bid_vld_r, lm_ask_vld_r})
      3'b111:  lm_ask_lm_bid_do_trade = (lm_bid_r.price >= lm_ask_r.price);
      default: lm_ask_lm_bid_do_trade = 'b0;
    endcase

    // Ask excess; the number of shares remaining in the ask if a trade
    // takes place.
    lm_ask_lm_bid_ask_excess    = (lm_ask_r.quantity - lm_bid_r.quantity);

    // Flag indicating that shares will remain in the ask after a trade.
    lm_ask_lm_bid_ask_has_more  = (lm_ask_lm_bid_ask_excess > 0);

    // Bid Excess; the number of shares remaining in the bid if a trade
    // takes place.
    lm_ask_lm_bid_bid_excess    = (lm_bid_r.quantity - lm_ask_r.quantity);

    // Flag indiciating that shares will remain in the bid after a trade.
    lm_ask_lm_bid_bid_has_more  = (lm_ask_lm_bid_bid_excess > 0);

    // Flag indicating that the quantity of bid equals the quantity of ask.
    lm_ask_lm_bid_bid_ask_equal = (lm_ask_lm_bid_bid_excess == 'b0);

  end // block: lm_ask_lm_bid_PROC

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST_W(logic, trade_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::search_result_t, trade);

  always_comb begin : decision_PROC

    // Defaults:
    trade_vld_w = 'b0;

    // Retain prior by default.
    trade_w     = '0;

    // Bid:
    trade_w.bid_uid   = lm_bid_r.uid;
    trade_w.bid_price = lm_bid_r.price;

    // Ask:
    trade_w.ask_uid   = lm_ask_r.uid;
    trade_w.ask_price = lm_ask_r.price;

    // Compute Limit <-> Limit:
    //
    unique case ({// Limit Bid <-> Limit Ask trade takes place
                  lm_ask_lm_bid_do_trade,
                  // Quantity(Ask) > Quantity(Bid)
                  lm_ask_lm_bid_ask_has_more,
                  // Quantity(Bid) > Quantity(Ask)
                  lm_ask_lm_bid_bid_has_more,
                  // Quantity(Bid) == Quantity(Ask)
                  lm_ask_lm_bid_bid_ask_equal
                  }) inside
      4'b1_1??: begin
        // Trade occurs; Ask Quantity > Bid Quantity; Bid (Buy) executes.
        trade_vld_w           = 'b1;
        //
        trade_w.lm_ask_lm_bid = 'b1;
        //
        trade_w.bid_consumed  = 'b1;
        trade_w.quantity      = lm_bid_r.quantity;
        trade_w.remainder     =
          ob_pkg::quantity_t'(lm_ask_lm_bid_ask_excess);
      end
      4'b1_01?: begin
        // Trade occurs; Bid Quantity > Ask Quantity; Ask (Sell) executes.
        trade_vld_w           = 'b1;
        //
        trade_w.lm_ask_lm_bid = 'b1;
        //
        trade_w.ask_consumed  = 'b1;
        trade_w.quantity      = lm_ask_r.quantity;
        trade_w.remainder     =
          ob_pkg::quantity_t'(lm_ask_lm_bid_bid_excess);
      end
      4'b1_001: begin
        // Trade occurs; Bid-/Ask- Quantities match; Bid/Ask execute.
        trade_vld_w           = 'b1;
        //
        trade_w.lm_ask_lm_bid = 'b1;
        //
        trade_w.bid_consumed  = 'b1;
        trade_w.ask_consumed  = 'b1;
        trade_w.quantity      = lm_bid_r.quantity;
        trade_w.remainder     = '0;
      end
      default: begin
        // Otherwise, no trade occurs
      end
    endcase // casez ({bid_table_vld_r, ask_table_vld_r})

    // Enables:
    //
    trade_en = trade_vld_w;

  end // block: decision_PROC

endmodule // ob_cntrl_lm
