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
  , input                                         bid_cancel_hit_w
  , input ob_pkg::table_t                         bid_cancel_hit_tbl_w
  //
  , output logic                                  bid_reject_pop
  //
  , output logic                                  bid_insert
  , output ob_pkg::table_t                        bid_insert_tbl
  //
  , output logic                                  bid_pop
  //
  , output logic                                  bid_update_vld
  , output ob_pkg::table_t                        bid_update
  //
  , output logic                                  bid_cancel
  , output ob_pkg::uid_t                          bid_cancel_uid
  // Qry interface:
  , input                                         bid_qry_rsp_vld_r
  , input                                         bid_qry_rsp_is_ge_r
  , input ob_pkg::accum_quantity_t                bid_qry_rsp_qty_r
  //
  , output logic                                  bid_qry_vld
  , output bcd_pkg::price_t                       bid_qry_price
  , output ob_pkg::quantity_t                     bid_qry_quantity

  // ======================================================================== //
  // Ask Table Interface
  , input                                         ask_table_vld_r
  , input ob_pkg::table_t                         ask_table_r
  //
  , input                                         ask_reject_vld_r
  , input ob_pkg::table_t                         ask_reject_r
  //
  , input                                         ask_cancel_hit_w
  , input ob_pkg::table_t                         ask_cancel_hit_tbl_w
  //
  , output logic                                  ask_reject_pop
  //
  , output logic                                  ask_insert
  , output ob_pkg::table_t                        ask_insert_tbl
  //
  , output logic                                  ask_pop
  //
  , output logic                                  ask_update_vld
  , output ob_pkg::table_t                        ask_update
  //
  , output logic                                  ask_cancel
  , output ob_pkg::uid_t                          ask_cancel_uid
  // Qry interface:
  , input                                         ask_qry_rsp_vld_r
  , input                                         ask_qry_rsp_is_ge_r
  , input ob_pkg::accum_quantity_t                ask_qry_rsp_qty_r
  //
  , output logic                                  ask_qry_vld
  , output bcd_pkg::price_t                       ask_qry_price
  , output ob_pkg::quantity_t                     ask_qry_quantity

  // ======================================================================== //
  // Market Buy Interface
  , input ob_pkg::table_t                         mk_buy_head_r
  , input ob_pkg::table_t                         mk_buy_cmd_pop_data
  //
  , output logic                                  mk_buy_cmd_vld
  , output libv_pkg::deque_op_t                   mk_buy_cmd_op
  , output ob_pkg::table_t                        mk_buy_cmd_push_data
  //
  , input logic                                   mk_buy_empty_w
  , input logic                                   mk_buy_full_w

  // ======================================================================== //
  // Market Sell Interface
  , input ob_pkg::table_t                         mk_sell_head_r
  , input ob_pkg::table_t                         mk_sell_cmd_pop_data
  //
  , output logic                                  mk_sell_cmd_vld
  , output libv_pkg::deque_op_t                   mk_sell_cmd_op
  , output ob_pkg::table_t                        mk_sell_cmd_push_data
  //
  , input logic                                   mk_sell_empty_w
  , input logic                                   mk_sell_full_w

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ======================================================================== //
  //                                                                          //
  // Wires                                                                    //
  //                                                                          //
  // ======================================================================== //

  `LIBV_REG_RST_R(logic, bid_cancel_hit, 'b0);
  `LIBV_REG_EN_R(ob_pkg::table_t, bid_cancel_hit_tbl);

  `LIBV_REG_RST_R(logic, ask_cancel_hit, 'b0);
  `LIBV_REG_EN_R(ob_pkg::table_t, ask_cancel_hit_tbl);

  `LIBV_REG_RST_R(logic, mk_buy_full, 'b0);
  `LIBV_REG_RST_R(logic, mk_buy_empty, 'b1);

  `LIBV_REG_RST_R(logic, mk_sell_full, 'b0);
  `LIBV_REG_RST_R(logic, mk_sell_empty, 'b1);

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST(logic, cmd_latch_vld, 'b0);
  `LIBV_REG_EN(ob_pkg::cmd_t, cmd_latch);

  logic         cmd_fetch;
  logic         cmd_consume;

  always_comb begin : cmd_latch_PROC

    //
    cmd_fetch       = cmd_in_vld & (cmd_consume | ~cmd_latch_vld_r);

    // Valid on fetch or Retain on not consume of prior.
    casez ({cmd_fetch, cmd_consume})
      2'b1?:   cmd_latch_vld_w = 'b1;
      2'b01:   cmd_latch_vld_w = 'b0;
      default: cmd_latch_vld_w = cmd_latch_vld_r;
    endcase

    //
    cmd_latch_en    = cmd_fetch;
    cmd_latch_w     = cmd_in;

    // Pop from ingress queue on fetch.
    cmd_in_pop        = cmd_fetch;

  end // block: cmd_latch_PROC

  // ------------------------------------------------------------------------ //
  //
  typedef struct packed {
    // Trade occurs between limit (bid) <-> limit (ask) tables
    logic                     lbid_lask_vld;
    // Trade occurs between market (bid) <-> limit (ask) tables
    logic                     mbid_lask_vld;
    // Trade occurs between limit (bid) <-> market (ask) tables
    logic                     lbid_mask_vld;

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
  } cmp_result_t;

  `LIBV_REG_EN(cmp_result_t, cmp_result);

  logic                                 cmp_can_trade;
  ob_pkg::quantity_arith_t              cmp_ask_excess;
  ob_pkg::quantity_arith_t              cmp_bid_excess;
  logic                                 cmp_ask_has_more;
  logic                                 cmp_bid_has_more;
  logic                                 cmp_bid_ask_equal;

  always_comb begin : cmp_PROC

    // A trade can take place if the current maximum bid exceeds (or
    // is equal to) the current minimum ask.
    cmp_can_trade          = (bid_table_r.price >= ask_table_r.price);

    // Ask excess; the number of shares remaining in the ask if a trade
    // takes place.
    cmp_ask_excess         = (ask_table_r.quantity - bid_table_r.quantity);

    // Flag indicating that shares will remain in the ask after a trade.
    cmp_ask_has_more       = (cmp_ask_excess > 0);

    // Bid Excess; the number of shares remaining in the bid if a trade
    // takes place.
    cmp_bid_excess         = (bid_table_r.quantity - ask_table_r.quantity);

    // Flag indiciating that shares will remain in the bid after a trade.
    cmp_bid_has_more       = (cmp_bid_excess > 0);

    // Flag indicating that the quantity of bid equals the quantity of ask.
    cmp_bid_ask_equal      = (cmp_bid_excess == 'b0);

    // Compare result outcome:
    cmp_result_w           = '0;

    // Bid:
    cmp_result_w.bid_uid   = bid_table_r.uid;
    cmp_result_w.bid_price = bid_table_r.price;

    // Ask:
    cmp_result_w.ask_uid   = ask_table_r.uid;
    cmp_result_w.ask_price = ask_table_r.price;

    // Compute Limit <-> Limit:
    //
    casez ({
            bid_table_vld_r, ask_table_vld_r, cmp_can_trade,

            cmp_ask_has_more,
            cmp_bid_has_more,
            cmp_bid_ask_equal
            })
      'b111_1??: begin
        // Trade occurs; Ask Quantity > Bid Quantity; Bid (Buy) executes.
        cmp_result_w.lbid_lask_vld = 'b1;
        //
        cmp_result_w.bid_consumed  = 'b1;
        //
        cmp_result_w.quantity      = bid_table_r.quantity;
        cmp_result_w.remainder     = ob_pkg::quantity_t'(cmp_ask_excess);
      end
      'b111_01?: begin
        // Trade occurs; Bid Quantity > Ask Quantity; Ask (Sell) executes.
        cmp_result_w.lbid_lask_vld = 'b1;
        //
        cmp_result_w.ask_consumed  = 'b1;
        //
        cmp_result_w.quantity      = ask_table_r.quantity;
        cmp_result_w.remainder     = ob_pkg::quantity_t'(cmp_bid_excess);
      end
      'b111_001: begin
        // Trade occurs; Bid-/Ask- Quantities match; Bid/Ask execute.
        cmp_result_w.lbid_lask_vld = 'b1;
        //
        cmp_result_w.bid_consumed  = 'b1;
        cmp_result_w.ask_consumed  = 'b1;
        //
        cmp_result_w.quantity      = bid_table_r.quantity;
        cmp_result_w.remainder     = '0;
      end
      default:
        // Otherwise, no trade occurs
        ;
    endcase // casez ({bid_table_vld_r, ask_table_vld_r})

    // Compute Market (bid) <-> Limit (ask):
    //
    casez ({ // Market queue is not empty
             mk_buy_empty_r,
             //
             ask_table_vld_r
            })
      2'b01: begin
        cmp_result_w.mbid_lask_vld = 'b1;
      end
      default:
        // Otherwise, nop
        ;
    endcase

    // Compute Limit (bid) <-> Market (ask):
    //
    casez ({ // Market queue is not empty
             bid_table_vld_r,
             //
             mk_sell_empty_r
            })
      2'b01: begin
        cmp_result_w.lbid_mask_vld = 'b1;
      end
      default:
        // Otherwise, nop
        ;
    endcase

  end // block: cmp_PROC

  // ------------------------------------------------------------------------ //
  //
  typedef enum logic [4:0] { // Default idle state
                             FSM_CNTRL_IDLE            = 5'b0_0000,
                             // Issue table query on current
                             FSM_CNTRL_TABLE_ISSUE_QRY = 5'b1_0001,
                             // Execute query response
                             FSM_CNTRL_TABLE_EXECUTE   = 5'b1_0010,
                             // Receive cancel notification
                             FSM_CNTRL_CANCEL_RESP     = 5'b1_0011,
                             // Perform 'count' lookup on the nominated table.
                             FSM_CNTRL_QRY_TBL         = 5'b0100
                             } fsm_state_t;

  // State flop
  `LIBV_REG_EN_RST(fsm_state_t, fsm_state, FSM_CNTRL_IDLE);

  always_comb begin : cntrl_PROC

    // Defaults:

    // Command In:
    cmd_in_pop            = 'b0;

    // Response Out:
    rsp_out_vld           = 'b0;
    rsp_out               = '0;

    // State update:
    fsm_state_w           = fsm_state_r;
    fsm_state_en          = 'b0;

    // Command latch:
    cmd_consume           = 'b0;

    // Bid Table:
    bid_insert            = 'b0;
    bid_insert_tbl        = '0;

    bid_pop               = 'b0;

    bid_update_vld        = 'b0;
    bid_update            = '0;

    bid_cancel            = 'b0;
    bid_cancel_uid        = '0;

    bid_reject_pop        = 'b0;

    // Bid query
    bid_qry_vld           = 'b0;
    bid_qry_price         = '0;
    bid_qry_quantity      = '0;

    // Ask Table:
    ask_insert            = 'b0;
    ask_insert_tbl        = '0;

    ask_pop               = 'b0;

    ask_update_vld        = 'b0;
    ask_update            = '0;

    ask_cancel            = 'b0;
    ask_cancel_uid        = '0;

    ask_reject_pop        = 'b0;

    // Ask query
    ask_qry_vld           = 'b0;
    ask_qry_price         = '0;
    ask_qry_quantity      = '0;

    // Buy Market queue
    mk_buy_cmd_vld        = 'b0;
    mk_buy_cmd_op         = '0;
    mk_buy_cmd_push_data  = '0;

    // Sell Market queue
    mk_sell_cmd_vld       = 'b0;
    mk_sell_cmd_op        = '0;
    mk_sell_cmd_push_data = '0;

    // Compare query
    cmp_result_en         = 'b0;

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

              rsp_out        = '0;
              rsp_out.uid    = cmd_latch_r.uid;
              rsp_out.status = ob_pkg::S_Okay;
            end
          end
          {1'b1, ob_pkg::Op_QryBidAsk}: begin
            // Qry Bid-/Ask- spread
            if (!rsp_out_full_r) begin
              ob_pkg::result_qrybidask_t result;

              // Consume command
              cmd_consume    = 'b1;

              // Form result:
              result         = '0;
              result.ask     = ask_table_r.price;
              result.bid     = bid_table_r.price;

              // Emit out:
              rsp_out_vld    = 'b1;

              rsp_out        = '0;
              rsp_out.uid    = cmd_latch_r.uid;
              casez ({ask_table_vld_r, bid_table_vld_r})
                2'b11:   rsp_out.status = ob_pkg::S_Okay;
                default: rsp_out.status = ob_pkg::S_Bad;
              endcase
              rsp_out.result.qrybidask = result;
            end
          end
          {1'b1, ob_pkg::Op_BuyLimit}: begin
            ob_pkg::table_t bid_table;

            bid_table          = '0;
            bid_table.uid      = cmd_latch_r.uid;
            bid_table.quantity = cmd_latch_r.quantity;
            bid_table.price    = cmd_latch_r.price;

            // Insert in Bid Table.
            bid_insert         = 'b1;
            bid_insert_tbl     = bid_table;

            // Emit out:
            rsp_out_vld        = 'b1;

            // From response:
            rsp_out            = '0;
            rsp_out.uid        = cmd_latch_r.uid;
            rsp_out.status     = ob_pkg::S_Okay;

            // Next, query update table.
            fsm_state_en       = 'b1;
            fsm_state_w        = FSM_CNTRL_TABLE_ISSUE_QRY;
          end
          {1'b1, ob_pkg::Op_SellLimit}: begin
            ob_pkg::table_t ask_table;

            // Await result of install operation.
            ask_table          = '0;
            ask_table.uid      = cmd_latch_r.uid;
            ask_table.quantity = cmd_latch_r.quantity;
            ask_table.price    = cmd_latch_r.price;

            // Insert in Ask Table.
            ask_insert         = 'b1;
            ask_insert_tbl     = ask_table;

            // Emit out:
            rsp_out_vld        = 'b1;

            // From response:
            rsp_out            = '0;
            rsp_out.uid        = cmd_latch_r.uid;
            rsp_out.status     = ob_pkg::S_Okay;

            // Next, query update table.
            fsm_state_en       = 'b1;
            fsm_state_w        = FSM_CNTRL_TABLE_ISSUE_QRY;
          end
          {1'b1, ob_pkg::Op_PopTopBid}: begin
            ob_pkg::result_poptop_t poptop;

            // Consume command
            cmd_consume     = 'b1;

            // Form result:
            poptop          = '0;
            poptop.price    = bid_table_r.price;
            poptop.quantity = bid_table_r.quantity;
            poptop.uid      = bid_table_r.uid;

            // Pop top valid item.
            bid_pop         = bid_table_vld_r;

            // Emit out:
            rsp_out_vld     = 'b1;
            rsp_out.uid     = cmd_latch_r.uid;
            rsp_out.status  =
              bid_table_vld_r ? ob_pkg::S_Okay : ob_pkg::S_BadPop;
            rsp_out.result        = '0;
            rsp_out.result.poptop = poptop;
          end
          {1'b1, ob_pkg::Op_PopTopAsk}: begin
            ob_pkg::result_poptop_t poptop;

            // Consume command
            cmd_consume     = 'b1;

            // Form result:
            poptop          = '0;
            poptop.price    = ask_table_r.price;
            poptop.quantity = ask_table_r.quantity;
            poptop.uid      = ask_table_r.uid;

            // Pop top valid item.
            ask_pop         = ask_table_vld_r;

            // Emit out:
            rsp_out_vld     = 'b1;
            rsp_out.uid     = cmd_latch_r.uid;
            rsp_out.status  =
              ask_table_vld_r ? ob_pkg::S_Okay : ob_pkg::S_BadPop;
            rsp_out.result      = '0;
            rsp_out.result.poptop = poptop;
          end // case: {1'b1, ob_pkg::Op_PopTopAsk}
          {1'b1, ob_pkg::Op_Cancel}: begin

            // Issue cancel op. to Bid table.
            bid_cancel     = 'b1;
            bid_cancel_uid = cmd_latch_r.uid1;

            // Issue cancel op. to Ask table.
            ask_cancel     = 'b1;
            ask_cancel_uid = cmd_latch_r.uid1;

            // Advance to next state when egress queue is non-full, as
            // next state does not support back-pressure.
            fsm_state_en   = (~rsp_out_full_r);
            fsm_state_w    = FSM_CNTRL_CANCEL_RESP;
          end // case: {1'b1, ob_pkg::Op_Cancel}
          {1'b1, ob_pkg::Op_BuyMarket}: begin
            // Market Buy command:
            cmd_consume = 'b1;

            case ({mk_buy_full_r})
              1'b1: begin
                // Market sell buffer is full, command is rejected

                // Issue reject message:
                rsp_out_vld    = 'b1;
                rsp_out.uid    = cmd_latch_r.uid;
                rsp_out.status = ob_pkg::S_Reject;
                rsp_out.result = '0;
              end
              default: begin
                // Otherwise, push current command to the tail of the command
                // queue.
                mk_buy_cmd_vld                = 'b1;
                mk_buy_cmd_op                 = libv_pkg::OpPushBack;
                mk_buy_cmd_push_data          = '0;
                mk_buy_cmd_push_data.uid      = cmd_latch_r.uid;
                mk_buy_cmd_push_data.quantity = cmd_latch_r.quantity;
                mk_buy_cmd_push_data.price    = cmd_latch_r.price;

                // Advance to query state
                fsm_state_en                   = (~rsp_out_full_r);
                fsm_state_w                    = FSM_CNTRL_TABLE_ISSUE_QRY;
              end
            endcase
          end
          {1'b1, ob_pkg::Op_SellMarket}: begin
            // Market Sell command:
            cmd_consume = 'b1;

            case ({mk_sell_full_r})
              1'b1: begin
                // Market sell buffer is full, command is rejected

                // Issue reject message.
                rsp_out_vld    = 'b1;
                rsp_out.uid    = cmd_latch_r.uid;
                rsp_out.status = ob_pkg::S_Reject;
                rsp_out.result = '0;
              end
              default: begin
                // Otherwise, push current command to the tail of the command
                // queue.
                mk_sell_cmd_vld                = 'b1;
                mk_sell_cmd_op                 = libv_pkg::OpPushBack;
                mk_sell_cmd_push_data          = '0;
                mk_sell_cmd_push_data.uid      = cmd_latch_r.uid;
                mk_sell_cmd_push_data.quantity = cmd_latch_r.quantity;
                mk_sell_cmd_push_data.price    = cmd_latch_r.price;

                // Advance to query state.
                fsm_state_en                   = (~rsp_out_full_r);
                fsm_state_w                    = FSM_CNTRL_TABLE_ISSUE_QRY;
              end
            endcase
          end // case: {1'b1, ob_pkg::Op_SellMarket}
          {1'b1, ob_pkg::Op_QryTblAskLe}: begin
            // Issue query commadn
            ask_qry_vld      = 'b1;
            ask_qry_price    = cmd_latch_r.price;
            ask_qry_quantity = cmd_latch_r.quantity;

            // Transition to await response state.
            fsm_state_en     = 'b1;
            fsm_state_w      = FSM_CNTRL_QRY_TBL;
          end // case: {1'b1, ob_pkg::Op_QryTblAskLe}
          {1'b1, ob_pkg::Op_QryTblBidGe}: begin
            // Issue query command
            bid_qry_vld      = 'b1;
            bid_qry_price    = cmd_latch_r.price;
            bid_qry_quantity = cmd_latch_r.quantity;

            // Transition to await response state.
            fsm_state_en = 'b1;
            fsm_state_w  = FSM_CNTRL_QRY_TBL;
          end // case: {1'b1, ob_pkg::Op_QryTblBidGe}
          default: begin
            // Invalid op:
          end
        endcase // case (ingress_queue_pop_data.opcode)

      end // case: FSM_CNTRL_IDLE

      FSM_CNTRL_CANCEL_RESP: begin
        // In this state, the response to the prior cancel request has
        // been collated and is known. From this, form the final response
        // for the command to the egress queue and consume the command.
        //

        // Consume command.
        cmd_consume = 'b1;

        rsp_out_vld = 'b1;
        rsp_out     = '0;
        rsp_out.uid = cmd_latch_r.uid;

        casez ({bid_cancel_hit_r, ask_cancel_hit_r})
          2'b1?: begin
            // Hit on bid table.
            rsp_out.status = ob_pkg::S_CancelHit;
          end
          2'b01: begin
            // Hit on ask table.
            rsp_out.status = ob_pkg::S_CancelHit;
          end
          default: begin
            // Miss, UID not found
            rsp_out.status = ob_pkg::S_CancelMiss;
          end
        endcase // casez ({bid_cancel_hit_r, ask_cancel_hit_r})

        // Advance to next state.
        fsm_state_en = 'b1;
        fsm_state_w  = FSM_CNTRL_IDLE;

      end // case: FSM_CNTRL_CANCEL_RESP

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
                // Trade occurs limit bid/limit ask.
                cmp_result_r.lbid_lask_vld,
                // Trade occurs market bid/limit ask.
//                cmp_result_r.mbid_lask_vld,
                1'b0,
                // Trade occurs limit bid/market ask.
//                cmp_result_r.lbid_mask_vld,
                1'b0,
                // The Bid table has a reject entry.
                bid_reject_vld_r,
                // The Ask table has a reject entry.
                ask_reject_vld_r
                })

          6'b0_1????: begin
            // Execute trade between limit (bid) <-> limit (ask) tables
            ob_pkg::result_trade_t trade;

            // Update tables:
            casez ({cmp_result_r.bid_consumed, cmp_result_r.ask_consumed})
              2'b10: begin
                // Bid head has been consumed; Ask head remains.

                ob_pkg::table_t updated_table;

                // Bid table update
                bid_pop                = 'b1;

                // Form updated table entry.
                updated_table          = ask_table_r;
                updated_table.quantity = cmp_result_r.remainder;

                ask_update_vld         = 'b1;
                ask_update             = updated_table;
              end
              2'b01: begin
                // Ask head has been consumed; Bid has remains.

                ob_pkg::table_t updated_table;

                // Ask table update
                ask_pop                = 'b1;

                // Form updated table entry.
                updated_table          = bid_table_r;
                updated_table.quantity = cmp_result_r.remainder;

                bid_update_vld         = 'b1;
                bid_update             = updated_table;
              end
              2'b11: begin
                // Both Bid and Ask heads have been consumed.
                bid_pop = 'b1;
                ask_pop = 'b1;
              end
              default: ;
            endcase // casez ({cmp_result_r.bid_consumed, cmp_result_r.ask_consumed})

            // Form trade message (Bid/Ask; Shares traded)
            trade                = '0;
            trade.bid_uid        = cmp_result_r.bid_uid;
            trade.ask_uid        = cmp_result_r.ask_uid;
            trade.quantity       = cmp_result_r.quantity;

            // Emit output message
            rsp_out_vld          = 'b1;

            // Form output message
            rsp_out              = '0;
            // Trade has no originator ID
            rsp_out.uid          = '1;
            rsp_out.status       = ob_pkg::S_Okay;
            rsp_out.result.trade = trade;

            // Return to query state to attempt further trades.
            fsm_state_en         = 'b1;
            fsm_state_w          = FSM_CNTRL_TABLE_ISSUE_QRY;
          end // case: 6'b0_1????
          6'b0_01???: begin
            // Trade occurs between market (bid) <-> limit (ask)

            // TODO:
          end
          6'b0_001??: begin
            // Trade occurs between limit (bid) <-> market (ask)

            // TODO:
          end
          6'b0_0001?: begin
            // Execute bid reject
            bid_reject_pop = 'b1;

            // Emit output message
            rsp_out_vld    = 'b1;

            // Form output message:
            rsp_out        = '0;
            rsp_out.uid    = bid_reject_r.uid;
            rsp_out.status = ob_pkg::S_Reject;
            rsp_out.result = '0;
          end
          6'b0_00001: begin
            // Execute ask reject
            ask_reject_pop = 'b1;

            // Emit output message
            rsp_out_vld    = 'b1;

            // Form output message:
            rsp_out        = '0;
            rsp_out.uid    = ask_reject_r.uid;
            rsp_out.status = ob_pkg::S_Reject;
            rsp_out.result = '0;
          end
          6'b1_?????: begin
              // Stalled on output resources.
          end
          default: begin
            // Consume command
            cmd_consume  = 'b1;

            // Otherwise, no further work. Return to IDLE state.
            fsm_state_en = 'b1;
            fsm_state_w  = FSM_CNTRL_IDLE;
          end
        endcase // casez ({...

      end // case: FSM_CNTRL_TABLE_EXECUTE

      FSM_CNTRL_QRY_TBL: begin

        casez ({bid_qry_rsp_vld_r, ask_qry_rsp_vld_r})
          2'b1?: begin
            // Consume command, now completed.
            cmd_consume              = 'b1;

            // Emit response
            rsp_out_vld              = 'b1;
            rsp_out                  = '0;
            rsp_out.uid              = cmd_latch_r.uid;
            rsp_out.status           = ob_pkg::S_Okay;
            rsp_out.result.qry.accum = bid_qry_rsp_qty_r;

            // Return to idle state.
            fsm_state_en             = 'b1;
            fsm_state_w              = FSM_CNTRL_IDLE;
          end
          2'b01: begin
            // Consume command, now completed.
            cmd_consume              = 'b1;

            // Emit response
            rsp_out_vld              = 'b1;
            rsp_out                  = '0;
            rsp_out.uid              = cmd_latch_r.uid;
            rsp_out.status           = ob_pkg::S_Okay;
            rsp_out.result.qry.accum = ask_qry_rsp_qty_r;

            // Return to idle state.
            fsm_state_en             = 'b1;
            fsm_state_w              = FSM_CNTRL_IDLE;
          end
          default: begin
            // Otherwise, continue to await response from table count
            // controller.
          end
        endcase // casez ({bid_qry_rsp_vld_r, ask_qry_rsp_vld_r})

      end // case: FSM_CNTRL_QRY_TBL

      default:;

    endcase // case (fsm_state_r)

  end // block: cntrl_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : cancel_PROC

    // Latch on next is valid.
    bid_cancel_hit_tbl_en = bid_cancel_hit_w;

    // Latch on next is valid.
    ask_cancel_hit_tbl_en = ask_cancel_hit_w;

  end // block: cancel_PROC

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl_mk u_ob_cntrl_mk (
    //
      .lm_bid_vld_r           ()
    , .lm_bid_r               ()
    //
    , .lm_ask_vld_r           ()
    , .lm_ask_r               ()
    //
    , .mk_buy_head_r          ()
    , .mk_buy_empty_w         ()
    //
    , .mk_sell_head_r         ()
    , .mk_sell_empty_w        ()
    //
    , .trade_qry              ()
    , .trade_vld_r            ()
    , .trade_r                ()
    //
    , .clk                    (clk                )
    , .rst                    (rst                )
  );

endmodule // ob_cntrl
