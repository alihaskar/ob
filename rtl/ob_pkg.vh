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

`ifndef OB_RTL_OB_PKG_VH
`define OB_RTL_OB_PKG_VH

`include "libv_pkg.vh"
`include "bcd_pkg.vh"
`include "cfg_pkg.vh"

package ob_pkg;

  // Command unique identifier (UID).
  //
  // Note: '1 indicates a OB initiated trade and cannot be issued as
  // part of a command.
  typedef logic [31:0] uid_t;

  // Number of shares to trade.
  typedef logic [15:0] quantity_t;

  // Number of bits to represent the total quantity contains by the BID/ASK
  // tables.
  localparam int ACCUM_TABLE_QUANTITY_BITS =
     $clog2(libv_pkg::max(cfg_pkg::BID_TABLE_DEPTH_N, cfg_pkg::ASK_TABLE_DEPTH_N)
              * (1 << $bits(quantity_t)));

  // Type to represent the accumulated quantity of all entries in the BID/ASK
  // tables.
  typedef logic [ACCUM_TABLE_QUANTITY_BITS - 1:0] accum_quantity_t;

  // Arithmetic type for quantity operations.
  typedef logic signed [16:0] quantity_arith_t;

  // Commands supported by the matching engine.
  typedef enum logic [4:0] {// No operation; NOP.
                            Op_Nop        = 5'b00000,
                            // Qry current bid-/ask- spread
                            Op_QryBidAsk  = 5'b00001,
                            // Buy transaction
                            Op_BuyLimit   = 5'b00010,
                            // Sell transaction
                            Op_SellLimit  = 5'b00011,
                            // Remove winning bid from order book.
                            Op_PopTopBid  = 5'b00100,
                            // Remove winning ask from order book.
                            Op_PopTopAsk  = 5'b00101,
			                      // Cancel prior Bid/Ask
			                      Op_Cancel     = 5'b00110,
                            // Issue Buy Market order.
                            Op_BuyMarket  = 5'b01000,
                            // Issue Sell Market order.
                            Op_SellMarket = 5'b01001,
                            // Qry Ask table entries less-than oprand.
                            Op_QryTblAskLe = 5'b01010,
                            // Qry Bid table entries greater-than oprand; for
                            // example, for a given ask price (oprand), compute
                            // the number of shares that can be traded from the
                            // bid limit table that can be traded (the number of
                            // bidding orders that are greater than the oprand).
                            Op_QryTblBidGe = 5'b01011,
                            // Conditional buy once price1 value or below has
                            // been reached. On maturity command becomes a
                            // standard market buy order.
                            Op_BuyStopLoss = 5'b01100,
                            // Conditional sell once price1 value or above has
                            // been reached. On maturity command becomes a
                            // standard market sell order.
                            Op_SellStopLoss = 5'b01101,
                            // As Op_BuyStopLess command but becomes limit
                            // order instead of market.
                            Op_BuyStopLimit = 5'b01110,
                            // As Op_Buy_SellStopLoss command but becomes limit
                            // order instead of market.
                            Op_SellStopLimit = 5'b01111
                            } opcode_t;

  // Time-In-Force (TIF) types
  typedef enum logic [2:0] { // Good Until Cancelled (GUC)
                             Tif_GoodUntilCancelled = 3'b000,
                             // Imeediate or cancel (immediate, allows partial)
                             Tif_ImmediateOrCancel  = 3'b001,
                             // Fill Or Kill (immediate, disallow partial)
                             Tif_FillOrKill         = 3'b010,
                             // All or None (deferrable, disallow partial)
                             Tif_AllOrNone          = 3'b011
                            } tif_t;

  //
  typedef struct packed {
    // Unique command identifier.
    uid_t                uid;
    // Command opcode.
    opcode_t             opcode;
    // Time in force (TIF)
    tif_t                tif;
    // Price oprand; where applicable.
    bcd_pkg::price_t     price;
    // Quantity oprand; where applicable.
    quantity_t           quantity;
    // Secondary UID (on cancel); where applicable
    uid_t                uid1;
    // Secondary price for conditional commands (price on maturity).
    bcd_pkg::price_t     price1;
  } cmd_t;

  //
  typedef enum   logic [2:0] {// Command executed
                              S_Okay   = 3'b000,
                              // Command UID has been rejected by the OB
                              S_Reject = 3'b001,
                              // Cancel operation hit pending bid/ask
                              S_CancelHit = 3'b010,
                              // Cancel operation missed.
                              S_CancelMiss = 3'b011,
                              // Prior command could not complete
                              S_Bad = 3'b100,
                              // Attempt to pop from empty table.
                              S_BadPop = 3'b101
                              } status_t;

  typedef struct packed { // 80b
    // Bid
    uid_t       bid_uid; // 32b
    // Ask
    uid_t       ask_uid; // 32b
    // Quantity (shares traded)
    quantity_t  quantity; // 16b
  } result_trade_t;

  typedef struct packed { // 40b
    // Padding for union sizing.
    logic [39:0] padding;
    // Current bid
    bcd_pkg::price_t bid; // 20b
    // Current ask
    bcd_pkg::price_t ask; // 20b
  } result_qrybidask_t;

  typedef struct packed { // 68b
    // Padding for union sizing.
    logic [11:0]         padding;
    // Bid/Ask Price
    bcd_pkg::price_t     price; // 20b
    // Bid/Ask Quantity
    quantity_t           quantity; // 16b
    // Bid/Ask ID
    uid_t                uid; // 32b
  } result_poptop_t;

  typedef struct packed { // 68b
    logic [67:$bits(accum_quantity_t)] padding;
    accum_quantity_t accum;
  } result_qry_t;

  typedef union packed {
    // Query Bid/Ask spread
    result_qrybidask_t qrybidask;
    // Pop top Bid/Ask
    result_poptop_t poptop;
    // Trade result type
    result_trade_t trade;
    // Accumulated Qry
    result_qry_t qry;
  } result_t;

  //
  typedef struct packed {
    // Unique command identifier.
    uid_t           uid;

    // Command opcode.
    status_t        status;

    // Response result.
    result_t        result;
  } rsp_t;

  // Order-book table (bid/ask) entry.
  typedef struct packed {
    // Unique command identifier.
    uid_t                uid;
    // Number of shares to trade.
    quantity_t           quantity;
    // Price at which to trade.
    bcd_pkg::price_t     price;
  } table_t;

  typedef struct packed {
    // Trade on Limit Ask (Sell) <-> Limit Bid (Buy)
    logic                     lm_ask_lm_bid;
    // Trade on Limit Ask (Sell) <-> Market Bid (Buy)
    logic                     lm_ask_mk_bid;
    // Trade on Market Ask (Sell) <-> Limit Bid (Buy)
    logic                     mk_ask_lm_bid;
    // Trade on Market Ask (Sell) <-> Market Bid (Buy)
    logic                     mk_ask_mk_bid;
    // Bid
    ob_pkg::uid_t             bid_uid;
    bcd_pkg::price_t          bid_price;
    logic                     bid_consumed;
    // Ask
    ob_pkg::uid_t             ask_uid;
    bcd_pkg::price_t          ask_price;
    logic                     ask_consumed;
    // Quantity traded
    ob_pkg::quantity_t        quantity;
    // Quantity remaining
    ob_pkg::quantity_t        remainder;
  } search_result_t;

  //
  localparam table_t TABLE_ASK_INIT  = '{ uid: '0,
                                          quantity: '0,
                                          price: bcd_pkg::PRICE_MAX };

  //
  localparam table_t TABLE_BID_INIT  = '{ uid: '0,
                                          quantity: '0,
                                          price: bcd_pkg::PRICE_MIN };

endpackage // ob_pkg

`endif
