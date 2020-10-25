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
  typedef logic [31:0] uid_t;

  // Number of shares to trade.
  typedef logic [15:0] quantity_t;
  
  typedef enum logic [2:0] {
			    // No operation; NOP.
			    Op_Nop 	 = 3'b000,
					 
			    // Qry current bid-/ask- spread
			    Op_QryBidAsk = 3'b001,
					 
			    // Buy transaction
			    Op_Buy 	 = 3'b010,
					 
			    // Sell transaction
			    Op_Sell 	 = 3'b011

			    } opcode_t;

  typedef struct packed {
    // Number of equities to trade.
    quantity_t quantity;

    // Price at which to buy.
    bcd_pkg::price_t price;
  } oprand_buy_t;

  typedef struct packed {
    // Number of equities to trade.
    quantity_t quantity;

    // Price at which to sell.
    bcd_pkg::price_t price;
  } oprand_sell_t;

  typedef union packed {
    oprand_buy_t buy;
    oprand_sell_t sell;
  } oprand_t;
  
  typedef struct packed {
    // Unique command identifier.
    uid_t           uid;

    // Command opcode.
    opcode_t        opcode;

    // Command oprand.
    oprand_t        oprand;
  } cmd_t;

  typedef enum logic [2:0] {  
			      // Command executed 
			      S_Okay   = 3'b000,

			      // Command rejected (table is full).
			      S_ErrRejectTableFull = 3'b001

			      } status_t;

  typedef struct packed {
    // Unique command identifier.
    uid_t           uid;

    // Command opcode.
    status_t        status;
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

endpackage // ob_pkg

`endif
