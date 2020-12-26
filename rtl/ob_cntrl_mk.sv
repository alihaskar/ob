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
  , input ob_pkg::table_t                         mk_buy_head_r
  //
  , input logic                                   mk_buy_empty_w

  // ======================================================================== //
  // Market Sell Interface
  , input ob_pkg::table_t                         mk_sell_head_r
  //
  , input logic                                   mk_sell_empty_w

  // ======================================================================== //
  // Decision Interface
  , input                                         trade_qry
  //
  , output logic                                  trade_vld_r
  , output ob_pkg::cntrl_mk_t                     trade_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  `LIBV_REG_RST(logic, mk_mk_trade, 'b0);
  `LIBV_REG_RST_R(logic, mk_buy_empty, 'b1);
  `LIBV_REG_RST_R(logic, mk_sell_empty, 'b1);

  // ------------------------------------------------------------------------ //
  //
  ob_pkg::quantity_arith_t              mk_cmp_quantity;
  logic                                 mk_cmp_buy_excess;
  logic                                 mk_cmp_equal;

  always_comb begin : mk_PROC

    //
    mk_cmp_quantity   = (mk_buy_head_r.quantity - mk_sell_head_r.quantity);

    // Flag indicating that the current head market buy order quantity exceeds
    // the corresponding head market sell order quantity.
    //
    mk_cmp_buy_excess = (mk_cmp_quantity > '0);

    // The quantity in the buy/sell queues are equal, therefore both can be
    // executed.
    //
    mk_cmp_equal      = (mk_cmp_quantity == '0);

    // A trade can occur by default whenever the market buy/sell queues are
    // non-empty.
    //
    mk_mk_trade_w     = ~(mk_buy_empty_w | mk_sell_empty_w);

  end // block: mk_PROC

  // ------------------------------------------------------------------------ //
  //
  logic                                 lm_b_mk_trade;
  ob_pkg::quantity_arith_t              lm_b_mk_cmp_quantity;
  logic                                 lm_b_mk_lm_excess;
  logic                                 lm_s_mk_trade;
  ob_pkg::quantity_arith_t              lm_s_mk_cmp_quantity;
  logic                                 lm_s_mk_lm_excess;

  always_comb begin : lm_PROC

    // Compute relative delta between Limit Buy/Market Sell orders.
    //
    lm_b_mk_cmp_quantity = (lm_bid_r.quantity - mk_sell_head_r.quantity);

    // For Limit Buy to Market trade, flag indicates that Limit quantity
    // exceeds Market quantity.
    //
    lm_b_mk_lm_excess    = (lm_b_mk_cmp_quantity > '0);

    // Limit Buy <-> Market Sell occurs whenever entries are present in both
    // tables (disregard relative prices).
    //
    lm_b_mk_trade        = lm_bid_vld_r & (~mk_sell_empty_r);

    // Compute relative delta between Limit Sell/Market Buy orders.
    //
    lm_s_mk_cmp_quantity = (lm_ask_r.quantity - mk_buy_head_r.quantity);

    // For Limit Sell to Market trade, flag indicates that Limit quantity
    // exceeds Market quantity.
    //
    lm_s_mk_lm_excess    = (lm_s_mk_cmp_quantity > '0);

    // Limit Sell <-> Market Market occurs whenever entries are present in both
    // tables (disregard relative prices).
    //
    lm_s_mk_trade        = lm_ask_vld_r & (~mk_buy_empty_r);

  end // block: lm_PROC

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST_W(logic, trade_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::cntrl_mk_t, trade);

  always_comb begin : decision_PROC

    // Defaults:
    trade_vld_w = 'b0;

    // Retain prior by default.
    trade_w     = trade_r;

    // From precomputed state, select the candidate trade that can take place in
    // the current cycle. Prefer Limit <-> Market, over Market <-> Market as
    // these trade enjoy a higher overall commission per trade.
    //
    case  ({// Query current tradeable state
            trade_qry,
            // Limit Buy <-> Market Sell trade
            lm_b_mk_trade,
            // Limit Sell <-> Market Buy trade
            lm_s_mk_trade,
            // Market Sell <-> Market Buy trade
            mk_mk_trade_r
            }) inside
      4'b1_1??: begin
        // Limit Buy <-> Market Sell trade takes place
        trade_vld_w = 'b1;
      end
      4'b1_01?: begin
        // Limit Sell <-> Market Buy trade takes place
        trade_vld_w = 'b1;
      end
      4'b1_001: begin
        // Market Sell <-> Market Buy trade takes place
        trade_vld_w = 'b1;
      end
      default: begin
        trade_vld_w = 'b0;
      end
    endcase // casez ({...

    // Enables:
    //
    trade_en = trade_vld_w;

  end // block: decision_PROC

endmodule // ob_cntrl_mk
