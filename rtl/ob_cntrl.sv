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

module ob_cntrl (

  // ======================================================================== //
  // Command In Interface
    input                                         cmd_in_vld
  , input ob_pkg::cmd_t                           cmd_in
  //
  , output logic                                  cmd_in_pop

  // ======================================================================== //
  // Response Out Interface
  , input                                         rsp_out_full_r
  //
  , output logic                                  rsp_out_vld
  , output ob_pkg::rsp_t                          rsp_out

  // ======================================================================== //
  // Bid Table Interface
  , input                                         bid_table_vld_r
  , input ob_pkg::table_t                         bid_table_r
  //
  , input                                         bid_reject_vld_r
  , input ob_pkg::table_t                         bid_reject_r
  //
  , output logic                                  bid_reject_pop
  //
  , output logic                                  bid_insert
  , output ob_pkg::table_t                        bid_insert_tbl
  //
  , output logic                                  bid_pop

  // ======================================================================== //
  // Ask Table Interface
  , input                                         ask_table_vld_r
  , input ob_pkg::table_t                         ask_table_r
  //
  , input                                         ask_reject_vld_r
  , input ob_pkg::table_t                         ask_reject_r
  //
  , output logic                                  ask_reject_pop
  //
  , output logic                                  ask_insert
  , output ob_pkg::table_t                        ask_insert_tbl
  //
  , output logic                                  ask_pop

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST(logic, cmd_latch_vld, 'b0);
  `LIBV_REG_EN(ob_pkg::cmd_t, cmd_latch);

  logic 				cmd_fetch;
  logic 				cmd_consume;

  always_comb begin : cmd_latch_PROC

    //
    cmd_fetch 	    = (cmd_latch_vld_r & cmd_consume) | // (1)
		      (~cmd_latch_vld_r & cmd_in_vld);  // (2)
		      

    // Pop from ingress queue on fetch.
    cmd_in_pop 	    = cmd_fetch;

    // Valid on fetch or Retain on not consume of prior.
    cmd_latch_vld_w = cmd_fetch | (cmd_latch_vld_r & ~cmd_consume);

    //
    cmd_latch_en    = cmd_fetch;
    cmd_latch_w     = cmd_in;

  end // block: cmd_latch_PROC
  
  // ------------------------------------------------------------------------ //
  //
  typedef struct packed {
    // Trade occurs
    logic 	              vld;
    // Bid
    ob_pkg::uid_t             bid_uid;
    bcd_pkg::price_t          bid_price;
    logic                     bid_consumed;
    // Ask
    ob_pkg::uid_t             ask_uid;
    bcd_pkg::price_t          ask_price;
    logic                     ask_consumed;
    //
    ob_pkg::quantity_t        quantity;
    //
    ob_pkg::quantity_t        remainder;
  } cmp_result_t;

  `LIBV_REG_EN(cmp_result_t, cmp_result);
  
  logic                                 cmp_can_trade;
  ob_pkg::quantity_t                    cmp_ask_excess;
  ob_pkg::quantity_t                    cmp_bid_excess;
  logic                                 cmp_ask_has_more;
  logic                                 cmp_bid_has_more;
  logic                                 cmp_bid_ask_equal;
  
  always_comb begin : cmp_PROC

    // 
    cmp_can_trade 	      = (bid_table_r.price >= ask_table_r.price);

    //
    cmp_ask_excess 	      = (ask_table_r.quantity - bid_table_r.quantity);

    //
    cmp_ask_has_more 	      = (cmp_ask_excess > 'b0);

    //
    cmp_bid_excess 	      = (bid_table_r.quantity - ask_table_r.quantity);

    //
    cmp_bid_has_more 	      = (cmp_bid_excess > 'b0);

    //
    cmp_bid_ask_equal 	      = (cmp_bid_excess == 'b0);

    // Compare result outcome:
    cmp_result_w 	      = '0;

    // Bid:
    cmp_result_w.bid_uid      = bid_table_r.uid;
    cmp_result_w.bid_price    = bid_table_r.price;

    // Ask:
    cmp_result_w.ask_uid      = ask_table_r.uid;
    cmp_result_w.ask_price    = ask_table_r.price;

    casez ({
	    bid_table_vld_r, ask_table_vld_r, cmp_can_trade,

	    cmp_ask_has_more,
	    cmp_bid_has_more,
	    cmp_bid_ask_equal
	    })
      'b111_1??: begin
	// Trade occurs; Ask Quantity > Bid Quantity; Bid (Buy) executes.
	cmp_result_w.vld 	  = 'b1;
	//
	cmp_result_w.bid_consumed = 'b1;
	//
	cmp_result_w.quantity 	  = bid_table_r.quantity;
	cmp_result_w.remainder 	  = cmp_ask_excess;
      end
      'b111_01?: begin
	// Trade occurs; Bid Quantity > Ask Quantity; Ask (Sell) executes.
	cmp_result_w.vld 	  = 'b1;
	//
	cmp_result_w.ask_consumed = 'b1;
	//
	cmp_result_w.quantity 	  = ask_table_r.quantity;
	cmp_result_w.remainder 	  = cmp_bid_excess;
      end
      'b111_001: begin
	// Trade occurs; Bid-/Ask- Quantities match; Bid/Ask execute.
	cmp_result_w.vld 	  = 'b1;
	//
	cmp_result_w.bid_consumed = 'b1;
	cmp_result_w.ask_consumed = 'b1;
	//
	cmp_result_w.quantity 	  = bid_table_r.quantity;
	cmp_result_w.remainder 	  = '0;
      end
      default: ;
    endcase // casez ({bid_table_vld_r, ask_table_vld_r})

  end // block: cmp_PROC
  
  // ------------------------------------------------------------------------ //
  //
  typedef enum logic [2:0] { // Default idle state
			     FSM_CNTRL_IDLE 	 = 3'b000,
			     // Issue table query on current
			     FSM_CNTRL_TABLE_ISSUE_QRY = 3'b001,
			     // Execute query response
			     FSM_CNTRL_TABLE_EXECUTE = 3'b010
			     } fsm_state_t;

  // State flop
  `LIBV_REG_EN_RST(fsm_state_t, fsm_state, FSM_CNTRL_IDLE);
  
  always_comb begin : cntrl_PROC

    // Defaults:

    // Command In:
    cmd_in_pop 	   = 'b0;

    // Response Out:
    rsp_out_vld    = 'b0;
    rsp_out 	   = '0;

    // State update:
    fsm_state_w    = fsm_state_r;
    fsm_state_en   = 'b0;

    // Command latch:
    cmd_consume    = 'b0;

    // Bid Table:
    bid_insert 	   = 'b0;
    bid_insert_tbl = '0;

    bid_pop 	   = 'b0;

    // Ask Table:
    ask_insert 	   = 'b0;
    ask_insert_tbl = '0;

    ask_pop 	   = 'b0;

    // Compare query
    cmp_result_en  = 'b0;

    case (fsm_state_r)

      FSM_CNTRL_IDLE: begin

	// Command decode)
	case ({cmd_latch_vld_r, cmd_latch_r.opcode})
	  {1'b1, ob_pkg::Op_Nop}: begin
	    // No-Operation (NOP) generate Okay response for command.
	    if (!rsp_out_full_r) begin
	      cmd_in_pop     = 'b1;

	      // Consume command
	      cmd_consume    = 'b1;
	      
	      rsp_out_vld    = 'b1;

	      rsp_out 	     = '0;
	      rsp_out.uid    = cmd_latch_r.uid;
	      rsp_out.status = ob_pkg::S_Okay;
	    end
	  end
	  {1'b1, ob_pkg::Op_QryBidAsk}: begin
	    // Qry Bid-/Ask- spread
	    if (!rsp_out_full_r) begin
	      ob_pkg::result_qrybidask_t result;

	      // Consume command
	      cmd_consume 	       = 'b1;

	      // Form result:
	      result 		       = '0;
	      result.ask 	       = ask_table_r.price;
	      result.bid 	       = bid_table_r.price;

	      // Emit out:
	      rsp_out_vld 	       = 'b1;

	      rsp_out 		       = '0;
	      rsp_out.uid 	       = cmd_latch_r.uid;
	      rsp_out.status 	       = ob_pkg::S_Okay;
	      rsp_out.result.qrybidask = result;
	    end
	  end
	  {1'b1, ob_pkg::Op_Buy}: begin
	    ob_pkg::table_t bid_table;

	    bid_table 	       = '0;
	    bid_table.uid      = cmd_latch_r.uid;
	    bid_table.quantity = cmd_latch_r.oprand.buy.quantity;
	    bid_table.price    = cmd_latch_r.oprand.buy.price;

	    fsm_state_en       = 'b1;
	    fsm_state_w        = FSM_CNTRL_TABLE_ISSUE_QRY;
	  end
	  {1'b1, ob_pkg::Op_Sell}: begin
	    ob_pkg::table_t bid_table;

	    // Await result of install operation.
	    bid_table 	       = '0;
	    bid_table.uid      = cmd_latch_r.uid;
	    bid_table.quantity = cmd_latch_r.oprand.sell.quantity;
	    bid_table.price    = cmd_latch_r.oprand.sell.price;

	    // Await result of install operation.
	    fsm_state_en       = 'b1;
	    fsm_state_w        = FSM_CNTRL_TABLE_ISSUE_QRY;
	  end
	  {1'b1, ob_pkg::Op_PopTopBid}: begin
	    ob_pkg::result_poptop_t poptop;

	    poptop 		  = '0;
	    poptop.price 	  = bid_table_r.price;
	    poptop.quantity 	  = bid_table_r.quantity;
	    poptop.uid 		  = bid_table_r.uid;

	    bid_pop 		  = bid_table_vld_r;

	    rsp_out_vld 	  = 'b1;
	    rsp_out.uid 	  = cmd_latch_r.uid;
	    rsp_out.status 	  =
              bid_table_vld_r ? ob_pkg::S_BadPop : ob_pkg::S_Okay;
	    rsp_out.result 	  = '0;
	    rsp_out.result.poptop = poptop;
	  end
	  {1'b1, ob_pkg::Op_PopTopAsk}: begin
	    ob_pkg::result_poptop_t poptop;

	    poptop 		  = '0;

	    poptop.price 	  = ask_table_r.price;
	    poptop.quantity 	  = ask_table_r.quantity;
	    poptop.uid 		  = ask_table_r.uid;

	    bid_pop 		  = ask_table_vld_r;

	    rsp_out_vld 	  = 'b1;
	    rsp_out.uid 	  = cmd_latch_r.uid;
	    rsp_out.status 	  =
              ask_table_vld_r ? ob_pkg::S_BadPop : ob_pkg::S_Okay;
	    rsp_out.result 	  = '0;
	    rsp_out.result.poptop = poptop;
	  end
	  default: begin
	    // Invalid op:
	  end
	endcase // case (ingress_queue_pop_data.opcode)

      end

      FSM_CNTRL_TABLE_ISSUE_QRY: begin
	// In this state, the state of the table has been updated with
	// a prior Bid/Ask installation. Now, query the state of the
	// respective heads to determine whether a trade can take
	// place. The decision is computed in this cycle to arrive in
	// the next to avoid a timing-path through the arithmetic
	// logic.
	//
	cmp_result_en = 'b1;

	fsm_state_en  = 'b1;
	fsm_state_w   = FSM_CNTRL_TABLE_EXECUTE;
      end

      FSM_CNTRL_TABLE_EXECUTE: begin
	// In this state, the tables have been queried and we should
	// now have an understanding if a trade occurs between the
	// respective heads of the bid/ask tables. Repeat this process
	// until no further trades can take place. If no trade has
	// taken place, query the reject status of the respective
	// tables and, if a reject from a prior install has occurred,
	// issue the reject message. We would hope that in the
	// presence of successfully trades, the rejected entries may
	// transition back to the unrejected state.
	//
	
	casez ({rsp_out_full_r,
		// A trade can take place in the current cycle.
		cmp_result_r.vld,
		// The Bid table has a reject entry.
		bid_reject_vld_r,
		// The Ask table has a reject entry.
		ask_reject_vld_r
		})

	  4'b0_1??: begin
	    // Execute trade
	    ob_pkg::result_trade_t trade;

	    // Form trade message (Bid/Ask; Shares traded)
	    trade 		 = '0;
	    trade.bid_uid 	 = cmp_result_r.bid_uid;
	    trade.ask_uid 	 = cmp_result_r.ask_uid;
	    trade.quantity 	 = cmp_result_r.quantity;

	    // Emit output message
	    rsp_out_vld 	 = 'b1;

	    // Form output message
	    rsp_out 		 = '0;
	    // Trade has no originator ID
	    rsp_out.uid 	 = '1;
	    rsp_out.status 	 = ob_pkg::S_Okay;
	    rsp_out.result.trade = trade;

	    // Return to query state to attempt further trades.
	    fsm_state_en 	 = 'b1;
	    fsm_state_w 	 = FSM_CNTRL_TABLE_ISSUE_QRY;
	  end
	  4'b0_01?: begin
	    // Execute bid reject
	    bid_reject_pop = 'b1;

	    // Emit output message
	    rsp_out_vld    = 'b1;

	    // Form output message:
	    rsp_out 	   = '0;
	    rsp_out.uid    = bid_reject_r.uid;
	    rsp_out.status = ob_pkg::S_Reject;
	    rsp_out.result = '0;
	  end
	  4'b0_001: begin
	    // Execute ask reject
	    ask_reject_pop = 'b1;

	    // Emit output message
	    rsp_out_vld    = 'b1;

	    // Form output message:
	    rsp_out 	   = '0;
	    rsp_out.uid    = ask_reject_r.uid;
	    rsp_out.status = ob_pkg::S_Reject;
	    rsp_out.result = '0;
	  end
	  4'b1_1??,
	  4'b1_01?,
	  4'b1_001: begin
	    // Stalled on output resources.
	  end
	  default: begin
	    // Otherwise, no further work. Return to IDLE state.
	    fsm_state_en = 'b1;
	    fsm_state_w  = FSM_CNTRL_IDLE;
	  end
	endcase // casez ({...
	
      end

      default:;

    endcase // case (fsm_state_r)

  end // block: cntrl_PROC

endmodule // ob_cntrl

