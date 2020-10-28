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

`include "bcd_pkg.vh"

package ob_pkg;

  // Command unique identifier (UID).
  //
  // Note: '1 indicates a OB initiated trade and cannot be issued as
  // part of a command.
  typedef logic [31:0] uid_t;

  // Number of shares to trade.
  typedef logic [15:0] quantity_t;

  // Arithmetic type for quantity operations.
  typedef logic signed [16:0] quantity_arith_t;

  //
  typedef enum logic [3:0] {
                            // No operation; NOP.
                            Op_Nop        = 4'b0000,
                                         
                            // Qry current bid-/ask- spread
                            Op_QryBidAsk  = 4'b0001,
                                         
                            // Buy transaction
                            Op_Buy        = 4'b0010,
                                         
                            // Sell transaction
                            Op_Sell       = 4'b0011,
                                         
                            // Remove winning bid from order book.
                            Op_PopTopBid  = 4'b0100,
                            
                            // Remove winning ask from order book.
                            Op_PopTopAsk  = 4'b0101,

			    // Cancel prior Bid/Ask
			    Op_Cancel     = 4'b0110

                            } opcode_t;

  //
  typedef struct packed {
    // Number of equities to trade.
    quantity_t quantity;

    // Price at which to buy.
    bcd_pkg::price_t price;
  } oprand_buy_t;

  //
  typedef struct packed {
    // Number of equities to trade.
    quantity_t quantity;

    // Price at which to sell.
    bcd_pkg::price_t price;
  } oprand_sell_t;

  //
  typedef struct packed {
    // ID to cancel.
    uid_t           uid;
  } oprand_cancel_t;

  //
  typedef union packed {
    oprand_buy_t buy;
    oprand_sell_t sell;
    oprand_cancel_t cancel;
  } oprand_t;

  //
  typedef struct packed {
    // Unique command identifier.
    uid_t           uid;

    // Command opcode.
    opcode_t        opcode;

    // Command oprand.
    oprand_t        oprand;
  } cmd_t;

  //
  typedef enum logic [2:0] {  
    // Command executed 
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

  typedef struct packed {
    // Bid
    uid_t       bid_uid;
    // Ask
    uid_t       ask_uid;
    // Quantity (shares traded)
    quantity_t  quantity;
  } result_trade_t;

  typedef struct packed {
    // Current bid
    bcd_pkg::price_t bid;
    // Current ask
    bcd_pkg::price_t ask;
  } result_qrybidask_t;

  typedef struct packed {
    // Bid/Ask Price
    bcd_pkg::price_t     price;
    // Bid/Ask Quantity
    quantity_t           quantity;
    // Bid/Ask ID
    uid_t                uid;
  } result_poptop_t;
  
  typedef union packed {
    // Query Bid/Ask spread
    result_qrybidask_t qrybidask;
    // Pop top Bid/Ask
    result_poptop_t poptop;
    // Trade result type
    result_trade_t trade;
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
