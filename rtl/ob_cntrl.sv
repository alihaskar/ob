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
`include "ob_cntrl_pkg.vh"
`include "macros_pkg.vh"

//`define ENABLE_OLD

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
  , input                                         lm_bid_table_vld_r
  , input ob_pkg::table_t                         lm_bid_table_r
  //
  , input                                         lm_bid_reject_vld_r
  , input ob_pkg::table_t                         lm_bid_reject_r
  //
  , input                                         lm_bid_cancel_hit_w
  , input ob_pkg::table_t                         lm_bid_cancel_hit_tbl_w
  //
  , output logic                                  lm_bid_reject_pop
  //
  , output logic                                  lm_bid_insert
  , output ob_pkg::table_t                        lm_bid_insert_tbl
  //
  , output logic                                  lm_bid_pop
  //
  , output logic                                  lm_bid_update_vld
  , output ob_pkg::table_t                        lm_bid_update
  //
  , output logic                                  lm_bid_cancel
  , output ob_pkg::uid_t                          lm_bid_cancel_uid
  // Qry interface:
  , input                                         lm_bid_qry_rsp_vld_r
  , input                                         lm_bid_qry_rsp_is_ge_r
  , input ob_pkg::accum_quantity_t                lm_bid_qry_rsp_qty_r
  //
  , output logic                                  lm_bid_qry_vld
  , output bcd_pkg::price_t                       lm_bid_qry_price
  , output ob_pkg::quantity_t                     lm_bid_qry_quantity

  // ======================================================================== //
  // Ask Table Interface
  , input                                         lm_ask_table_vld_r
  , input ob_pkg::table_t                         lm_ask_table_r
  //
  , input                                         lm_ask_reject_vld_r
  , input ob_pkg::table_t                         lm_ask_reject_r
  //
  , input                                         lm_ask_cancel_hit_w
  , input ob_pkg::table_t                         lm_ask_cancel_hit_tbl_w
  //
  , output logic                                  lm_ask_reject_pop
  //
  , output logic                                  lm_ask_insert
  , output ob_pkg::table_t                        lm_ask_insert_tbl
  //
  , output logic                                  lm_ask_pop
  //
  , output logic                                  lm_ask_update_vld
  , output ob_pkg::table_t                        lm_ask_update
  //
  , output logic                                  lm_ask_cancel
  , output ob_pkg::uid_t                          lm_ask_cancel_uid
  // Qry interface:
  , input                                         lm_ask_qry_rsp_vld_r
  , input                                         lm_ask_qry_rsp_is_ge_r
  , input ob_pkg::accum_quantity_t                lm_ask_qry_rsp_qty_r
  //
  , output logic                                  lm_ask_qry_vld
  , output bcd_pkg::price_t                       lm_ask_qry_price
  , output ob_pkg::quantity_t                     lm_ask_qry_quantity

  // ======================================================================== //
  // Market Bid Interface
  , input                                         mk_bid_head_vld_r
  , input                                         mk_bid_head_did_update_r
  , input ob_pkg::table_t                         mk_bid_head_r
  //
  , output logic                                  mk_bid_head_pop
  , output logic                                  mk_bid_head_push
  , output ob_pkg::table_t                        mk_bid_head_push_tbl
  //
  , input                                         mk_bid_cancel_hit_w
  , input ob_pkg::table_t                         mk_bid_cancel_hit_tbl_w
  // Status
  , input                                         mk_bid_full_w
  , input                                         mk_bid_empty_w
  , input ob_pkg::accum_quantity_t                mk_bid_quantity_r
  // Control Interface
  , output logic                                  mk_bid_insert
  , output ob_pkg::table_t                        mk_bid_insert_tbl
  // Cancel UID Interface
  , output                                        mk_bid_cancel
  , output ob_pkg::uid_t                          mk_bid_cancel_uid

  // ======================================================================== //
  // Market Ask Interface
  , input                                         mk_ask_head_vld_r
  , input                                         mk_ask_head_did_update_r
  , input ob_pkg::table_t                         mk_ask_head_r
  //
  , output logic                                  mk_ask_head_pop
  , output logic                                  mk_ask_head_push
  , output ob_pkg::table_t                        mk_ask_head_push_tbl
  //
  , input                                         mk_ask_cancel_hit_w
  , input ob_pkg::table_t                         mk_ask_cancel_hit_tbl_w
  // Status
  , input                                         mk_ask_full_w
  , input                                         mk_ask_empty_w
  , input ob_pkg::accum_quantity_t                mk_ask_quantity_r
  // Control Interface
  , output logic                                  mk_ask_insert
  , output ob_pkg::table_t                        mk_ask_insert_tbl
  // Cancel UID Interface
  , output                                        mk_ask_cancel
  , output ob_pkg::uid_t                          mk_ask_cancel_uid

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

  `LIBV_REG_RST_R(logic, lm_bid_cancel_hit, 'b0);
  `LIBV_REG_EN_R(ob_pkg::table_t, lm_bid_cancel_hit_tbl);

  `LIBV_REG_RST_R(logic, lm_ask_cancel_hit, 'b0);
  `LIBV_REG_EN_R(ob_pkg::table_t, lm_ask_cancel_hit_tbl);

  `LIBV_REG_RST_R(logic, mk_bid_cancel_hit, 'b0);
  `LIBV_REG_EN_R(ob_pkg::table_t, mk_bid_cancel_hit_tbl);

  `LIBV_REG_RST_R(logic, mk_ask_cancel_hit, 'b0);
  `LIBV_REG_EN_R(ob_pkg::table_t, mk_ask_cancel_hit_tbl);

  `LIBV_REG_RST_R(logic, mk_bid_full, 'b0);
  `LIBV_REG_RST_R(logic, mk_bid_empty, 'b1);

  `LIBV_REG_RST_R(logic, mk_ask_full, 'b0);
  `LIBV_REG_RST_R(logic, mk_ask_empty, 'b1);

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
  ob_pkg::accum_quantity_t                   qry_qty_combined;

  always_comb begin : qry_PROC

    case ({lm_bid_qry_rsp_vld_r, lm_ask_qry_rsp_vld_r}) inside
      2'b1?:   qry_qty_combined = lm_bid_qry_rsp_qty_r + mk_bid_quantity_r;
      2'b01:   qry_qty_combined = lm_ask_qry_rsp_qty_r + mk_ask_quantity_r;
      default: qry_qty_combined = '0;
    endcase

  end // block: qry_PROC

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
  logic                                 trade_qry;
  logic                                 mk_trade_vld_r;
  ob_pkg::search_result_t               mk_trade_r;
  logic                                 lm_trade_vld_r;
  ob_pkg::search_result_t               lm_trade_r;
  ob_cntrl_pkg::inst_t                  cntrl_inst;

  always_comb begin : cntrl_PROC

    // Defaults:
    cntrl_inst           = ob_cntrl_pkg::encode_nop();

    // Command In:
    cmd_in_pop           = 'b0;
`ifdef ENABLE_OLD

    // Response Out:
    rsp_out_vld          = 'b0;
    rsp_out              = '0;

    // State update:
    fsm_state_w          = fsm_state_r;
    fsm_state_en         = 'b0;

    // Command latch:
    cmd_consume          = 'b0;

    // Bid Table:
    lm_bid_insert        = 'b0;
    lm_bid_insert_tbl    = '0;

    lm_bid_pop           = 'b0;

    lm_bid_update_vld    = 'b0;
    lm_bid_update        = '0;

    lm_bid_cancel        = 'b0;
    lm_bid_cancel_uid    = '0;

    lm_bid_reject_pop    = 'b0;

    // Bid query
    lm_bid_qry_vld       = 'b0;
    lm_bid_qry_price     = '0;
    lm_bid_qry_quantity  = '0;

    // Ask Table:
    lm_ask_insert        = 'b0;
    lm_ask_insert_tbl    = '0;

    lm_ask_pop           = 'b0;

    lm_ask_update_vld    = 'b0;
    lm_ask_update        = '0;

    lm_ask_cancel        = 'b0;
    lm_ask_cancel_uid    = '0;

    lm_ask_reject_pop    = 'b0;

    // Ask query
    lm_ask_qry_vld       = 'b0;
    lm_ask_qry_price     = '0;
    lm_ask_qry_quantity  = '0;

    // Buy Market queue
    mk_bid_head_pop      = 'b0;
    mk_bid_head_push     = 'b0;
    mk_bid_head_push_tbl = '0;

    mk_bid_insert        = 'b0;
    mk_bid_insert_tbl    = '0;

    mk_bid_cancel        = 'b0;
    mk_bid_cancel_uid    = '0;

    // Sell Market queue
    mk_ask_head_pop      = 'b0;
    mk_ask_head_push     = 'b0;
    mk_ask_head_push_tbl = '0;

    mk_ask_insert        = 'b0;
    mk_ask_insert_tbl    = '0;

    mk_ask_cancel        = 'b0;
    mk_ask_cancel_uid    = '0;
`endif

    // Compare query
    trade_qry            = 'b0;

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

              cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
                .uid(cmd_latch_r.uid), .status(ob_pkg::S_Okay));
`ifdef ENABLE_OLD
              rsp_out_vld    = 'b1;

              rsp_out        = '0;
              rsp_out.uid    = cmd_latch_r.uid;
              rsp_out.status = ob_pkg::S_Okay;
`endif
            end
          end
          {1'b1, ob_pkg::Op_QryBidAsk}: begin
            // Qry Bid-/Ask- spread
            if (!rsp_out_full_r) begin
`ifdef ENABLE_OLD
              ob_pkg::result_qrybidask_t result;
`endif
              ob_pkg::status_t status;

              // Consume command
              cmd_consume = 'b1;

              case ({lm_ask_table_vld_r, lm_bid_table_vld_r})
                2'b11:   status = ob_pkg::S_Okay;
                default: status = ob_pkg::S_Bad;
              endcase

              // Emit command:
              cntrl_inst  = ob_cntrl_pkg::encode_emit_rsp_qry_bid_ask(
                .uid(cmd_latch_r.uid), .bid_price(lm_bid_table_r.price),
                .ask_price(lm_ask_table_r.price), .status(status));
`ifdef ENABLE_OLD

              // Form result:
              result      = '0;
              result.ask  = lm_ask_table_r.price;
              result.bid  = lm_bid_table_r.price;

              // Emit out:
              rsp_out_vld = 'b1;

              rsp_out     = '0;
              rsp_out.uid = cmd_latch_r.uid;
              casez ({lm_ask_table_vld_r, lm_bid_table_vld_r})
                2'b11:   rsp_out.status = ob_pkg::S_Okay;
                default: rsp_out.status = ob_pkg::S_Bad;
              endcase
              rsp_out.result.qrybidask = result;
`endif
            end // if (!rsp_out_full_r)
          end
          {1'b1, ob_pkg::Op_BuyLimit}: begin
`ifdef ENABLE_OLD
            ob_pkg::table_t lm_bid_table;

            lm_bid_table          = '0;
            lm_bid_table.uid      = cmd_latch_r.uid;
            lm_bid_table.quantity = cmd_latch_r.quantity;
            lm_bid_table.price    = cmd_latch_r.price;

            // Insert in Bid Table.
            lm_bid_insert         = 'b1;
            lm_bid_insert_tbl     = lm_bid_table;

            // Emit out:
            rsp_out_vld           = 'b1;

            // From response:
            rsp_out               = '0;
            rsp_out.uid           = cmd_latch_r.uid;
            rsp_out.status        = ob_pkg::S_Okay;
`endif

            // Issue push command:
            cntrl_inst            = ob_cntrl_pkg::encode_push_table(
             .cmd(cmd_latch_r), .table_id(ob_cntrl_pkg::TBL_ID__LM_BID));

            // Next, query update table.
            fsm_state_en          = 'b1;
            fsm_state_w           = FSM_CNTRL_TABLE_ISSUE_QRY;
          end
          {1'b1, ob_pkg::Op_SellLimit}: begin
`ifdef ENABLE_OLD
            ob_pkg::table_t lm_ask_table;

            // Await result of install operation.
            lm_ask_table          = '0;
            lm_ask_table.uid      = cmd_latch_r.uid;
            lm_ask_table.quantity = cmd_latch_r.quantity;
            lm_ask_table.price    = cmd_latch_r.price;

            // Insert in Ask Table.
            lm_ask_insert         = 'b1;
            lm_ask_insert_tbl     = lm_ask_table;

            // Emit out:
            rsp_out_vld           = 'b1;

            // From response:
            rsp_out               = '0;
            rsp_out.uid           = cmd_latch_r.uid;
            rsp_out.status        = ob_pkg::S_Okay;
`endif

            // Issue push command:
            cntrl_inst            = ob_cntrl_pkg::encode_push_table(
              .cmd(cmd_latch_r), .table_id(ob_cntrl_pkg::TBL_ID__LM_ASK));

            // Next, query update table.
            fsm_state_en          = 'b1;
            fsm_state_w           = FSM_CNTRL_TABLE_ISSUE_QRY;
          end
          {1'b1, ob_pkg::Op_PopTopBid}: begin
            ob_pkg::status_t status;

            // Consume command
            cmd_consume     = 'b1;

            status     = lm_bid_table_vld_r ? ob_pkg::S_Okay : ob_pkg::S_BadPop;
            cntrl_inst = ob_cntrl_pkg::encode_poptop(
              .id(ob_cntrl_pkg::TBL_ID__LM_BID), .t(lm_bid_table_r),
              .status(status), .is_ask('b0));

`ifdef ENABLE_OLD
            ob_pkg::result_poptop_t poptop;

            // Consume command
            cmd_consume     = 'b1;

            // Form result:
            poptop          = '0;
            poptop.price    = lm_bid_table_r.price;
            poptop.quantity = lm_bid_table_r.quantity;
            poptop.uid      = lm_bid_table_r.uid;

            // Pop top valid item.
            lm_bid_pop      = lm_bid_table_vld_r;

            // Emit out:
            rsp_out_vld     = 'b1;
            rsp_out.uid     = cmd_latch_r.uid;
            rsp_out.status  =
              lm_bid_table_vld_r ? ob_pkg::S_Okay : ob_pkg::S_BadPop;
            rsp_out.result        = '0;
            rsp_out.result.poptop = poptop;
`endif
          end
          {1'b1, ob_pkg::Op_PopTopAsk}: begin
            ob_pkg::status_t status;

            // Consume command
            cmd_consume     = 'b1;

            status     = lm_ask_table_vld_r ? ob_pkg::S_Okay : ob_pkg::S_BadPop;
            cntrl_inst = ob_cntrl_pkg::encode_poptop(
              .id(ob_cntrl_pkg::TBL_ID__LM_ASK), .t(lm_ask_table_r),
              .status(status), .is_ask('b1));
`ifdef ENABLE_OLD
            ob_pkg::result_poptop_t poptop;

            // Consume command
            cmd_consume     = 'b1;

            // Form result:
            poptop          = '0;
            poptop.price    = lm_ask_table_r.price;
            poptop.quantity = lm_ask_table_r.quantity;
            poptop.uid      = lm_ask_table_r.uid;

            // Pop top valid item.
            lm_ask_pop         = lm_ask_table_vld_r;

            // Emit out:
            rsp_out_vld     = 'b1;
            rsp_out.uid     = cmd_latch_r.uid;
            rsp_out.status  =
              lm_ask_table_vld_r ? ob_pkg::S_Okay : ob_pkg::S_BadPop;
            rsp_out.result        = '0;
            rsp_out.result.poptop = poptop;
`endif
          end // case: {1'b1, ob_pkg::Op_PopTopAsk}
          {1'b1, ob_pkg::Op_Cancel}: begin

            cntrl_inst        = ob_cntrl_pkg::encode_emit_cancel(
              .uid(cmd_latch_r.uid1));
`ifdef ENABLE_OLD
            // Issue cancel op. to Bid table.
            lm_bid_cancel     = 'b1;
            lm_bid_cancel_uid = cmd_latch_r.uid1;

            // Issue cancel op. to Ask table.
            lm_ask_cancel     = 'b1;
            lm_ask_cancel_uid = cmd_latch_r.uid1;
`endif

            // Advance to next state when egress queue is non-full, as
            // next state does not support back-pressure.
            fsm_state_en      = (~rsp_out_full_r);
            fsm_state_w       = FSM_CNTRL_CANCEL_RESP;
          end // case: {1'b1, ob_pkg::Op_Cancel}
          {1'b1, ob_pkg::Op_BuyMarket}: begin
            // Market Buy command:
            cmd_consume = 'b1;

            case ({mk_bid_full_r})
              1'b1: begin
                // Market sell buffer is full, command is rejected

                // Issue reject message:
                cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
                  .uid(cmd_latch_r.uid), .status(ob_pkg::S_Reject));

`ifdef ENABLE_OLD
                rsp_out_vld    = 'b1;
                rsp_out.uid    = cmd_latch_r.uid;
                rsp_out.status = ob_pkg::S_Reject;
                rsp_out.result = '0;
`endif
              end
              default: begin
                // Otherwise, push current command to the tail of the command
                // queue.
                cntrl_inst                 = ob_cntrl_pkg::encode_push_table(
                  .cmd(cmd_latch_r), .table_id(ob_cntrl_pkg::TBL_ID__MK_BID));

`ifdef ENABLE_OLD
                mk_bid_insert              = 'b1;
                mk_bid_insert_tbl          = '0;
                mk_bid_insert_tbl.uid      = cmd_latch_r.uid;
                mk_bid_insert_tbl.quantity = cmd_latch_r.quantity;
                mk_bid_insert_tbl.price    = cmd_latch_r.price;
`endif

                // Advance to query state
                fsm_state_en               = (~rsp_out_full_r);
                fsm_state_w                = FSM_CNTRL_TABLE_ISSUE_QRY;
              end
            endcase
          end
          {1'b1, ob_pkg::Op_SellMarket}: begin
            // Market Sell command:
            cmd_consume = 'b1;

            case ({mk_ask_full_r})
              1'b1: begin
                // Market sell buffer is full, command is rejected

                // Issue reject message.
                cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
                  .uid(cmd_latch_r.uid), .status(ob_pkg::S_Reject));

`ifdef ENABLE_OLD
                rsp_out_vld    = 'b1;
                rsp_out.uid    = cmd_latch_r.uid;
                rsp_out.status = ob_pkg::S_Reject;
                rsp_out.result = '0;
`endif
              end
              default: begin
                // Otherwise, push current command to the tail of the command
                // queue.
                cntrl_inst                 = ob_cntrl_pkg::encode_push_table(
                  .cmd(cmd_latch_r), .table_id(ob_cntrl_pkg::TBL_ID__MK_ASK));
`ifdef ENABLE_OLD
                mk_ask_insert              = 'b1;
                mk_ask_insert_tbl          = '0;
                mk_ask_insert_tbl.uid      = cmd_latch_r.uid;
                mk_ask_insert_tbl.quantity = cmd_latch_r.quantity;
                mk_ask_insert_tbl.price    = cmd_latch_r.price;
`endif

                // Advance to query state.
                fsm_state_en               = (~rsp_out_full_r);
                fsm_state_w                = FSM_CNTRL_TABLE_ISSUE_QRY;
              end
            endcase
          end // case: {1'b1, ob_pkg::Op_SellMarket}
          {1'b1, ob_pkg::Op_QryTblAskLe}: begin
            // Issue query command
            cntrl_inst          = ob_cntrl_pkg::encode_issue_qry(
              .price(cmd_latch_r.price), .quantity(cmd_latch_r.quantity),
              .is_ask('b1));

`ifdef ENABLE_OLD
            lm_ask_qry_vld      = 'b1;
            lm_ask_qry_price    = cmd_latch_r.price;
            lm_ask_qry_quantity = cmd_latch_r.quantity;
`endif

            // Transition to await response state.
            fsm_state_en        = 'b1;
            fsm_state_w         = FSM_CNTRL_QRY_TBL;
          end // case: {1'b1, ob_pkg::Op_QryTblAskLe}
          {1'b1, ob_pkg::Op_QryTblBidGe}: begin
            // Issue query command
            cntrl_inst          = ob_cntrl_pkg::encode_issue_qry(
              .price(cmd_latch_r.price), .quantity(cmd_latch_r.quantity),
              .is_ask('b0));
`ifdef ENABLE_OLD
            lm_bid_qry_vld      = 'b1;
            lm_bid_qry_price    = cmd_latch_r.price;
            lm_bid_qry_quantity = cmd_latch_r.quantity;
`endif

            // Transition to await response state.
            fsm_state_en        = 'b1;
            fsm_state_w         = FSM_CNTRL_QRY_TBL;
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

`ifdef ENABLE_OLD
        rsp_out_vld = 'b1;
        rsp_out     = '0;
        rsp_out.uid = cmd_latch_r.uid;
`endif

        case ({// Bid limit table hits cancel
               lm_bid_cancel_hit_r,
               // Ask limit table hits cancel
               lm_ask_cancel_hit_r,
               // Bid market table hits cancel
               mk_bid_cancel_hit_r,
               // Ask market table table cancel
               mk_ask_cancel_hit_r
               }) inside
          4'b1???: begin
            // Hit on bid table.
            cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
              .uid(cmd_latch_r.uid), .status(ob_pkg::S_CancelHit));
`ifdef ENABLE_OLD
            rsp_out.status = ob_pkg::S_CancelHit;
`endif
          end
          4'b01??: begin
            // Hit on ask table.
            cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
              .uid(cmd_latch_r.uid), .status(ob_pkg::S_CancelHit));
`ifdef ENABLE_OLD
            rsp_out.status = ob_pkg::S_CancelHit;
`endif
          end
          4'b001?: begin
            // Hit on bid market table.
            cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
              .uid(cmd_latch_r.uid), .status(ob_pkg::S_CancelHit));
`ifdef ENABLE_OLD
            rsp_out.status = ob_pkg::S_CancelHit;
`endif
          end
          4'b0001: begin
            // Hit on ask market table.
            cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
              .uid(cmd_latch_r.uid), .status(ob_pkg::S_CancelHit));
`ifdef ENABLE_OLD
            rsp_out.status = ob_pkg::S_CancelHit;
`endif
          end
          default: begin
            // Miss, UID not found
            cntrl_inst     = ob_cntrl_pkg::encode_emit_rsp(
              .uid(cmd_latch_r.uid), .status(ob_pkg::S_CancelMiss));
`ifdef ENABLE_OLD
            rsp_out.status = ob_pkg::S_CancelMiss;
`endif
          end
        endcase // case ({...

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
        trade_qry     = 'b1;

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

        case  ({// Output response queue is not full
                rsp_out_full_r,
                // Limit controller hits possible trade
                lm_trade_vld_r,
                // Market controller hits possible trade
                mk_trade_vld_r,
                // The Bid table has a reject entry.
                lm_bid_reject_vld_r,
                // The Ask table has a reject entry.
                lm_ask_reject_vld_r
                }) inside
          5'b01???: begin
`ifdef ENABLE_OLD
            ob_pkg::result_trade_t trade; // REMOVE
`endif

            // Execute trade between limit (bid) <-> limit (ask) tables
            cntrl_inst = ob_cntrl_pkg::encode_search_result(lm_trade_r);

            // Return to query state to attempt further trades.
            fsm_state_en         = 'b1;
            fsm_state_w          = FSM_CNTRL_TABLE_ISSUE_QRY;
`ifdef ENABLE_OLD

            // Update tables:
            case ({lm_trade_r.bid_consumed, lm_trade_r.ask_consumed})
              2'b10: begin
                // Bid head has been consumed; Ask head remains.

                ob_pkg::table_t updated_table;

                // Bid table update
                lm_bid_pop                = 'b1;

                // Form updated table entry.
                updated_table          = lm_ask_table_r;
                updated_table.quantity = lm_trade_r.remainder;

                lm_ask_update_vld         = 'b1;
                lm_ask_update             = updated_table;
              end
              2'b01: begin
                // Ask head has been consumed; Bid has remains.

                ob_pkg::table_t updated_table;

                // Ask table update
                lm_ask_pop                = 'b1;

                // Form updated table entry.
                updated_table          = lm_bid_table_r;
                updated_table.quantity = lm_trade_r.remainder;

                lm_bid_update_vld         = 'b1;
                lm_bid_update             = updated_table;
              end
              2'b11: begin
                // Both Bid and Ask heads have been consumed.
                lm_bid_pop = 'b1;
                lm_ask_pop = 'b1;
              end
              default: ;
            endcase // casez ({lm_trade_r.bid_consumed, lm_trade_r.ask_consumed})

            // Form trade message (Bid/Ask; Shares traded)
            trade                = '0;
            trade.bid_uid        = lm_trade_r.bid_uid;
            trade.ask_uid        = lm_trade_r.ask_uid;
            trade.quantity       = lm_trade_r.quantity;

            // Emit output message
            rsp_out_vld          = 'b1;

            // Form output message
            rsp_out              = '0;
            // Trade has no originator ID
            rsp_out.uid          = '1;
            rsp_out.status       = ob_pkg::S_Okay;
            rsp_out.result.trade = trade;
`endif
          end // case: 7'b0_1????
          5'b001??: begin
            // Market trade: Limit Ask <-> Market Bid
            cntrl_inst = ob_cntrl_pkg::encode_search_result(mk_trade_r);

            // Return to query state to attempt further trades.
            fsm_state_en         = 'b1;
            fsm_state_w          = FSM_CNTRL_TABLE_ISSUE_QRY;
          end
          5'b0001?: begin
            // Execute bid reject
            lm_bid_reject_pop = 'b1;


            cntrl_inst        = ob_cntrl_pkg::encode_reject_pop(
              .uid(lm_ask_reject_r.uid), .is_ask('b0));
`ifdef ENABLE_OLD
            // Emit output message
            rsp_out_vld    = 'b1;

            // Form output message:
            rsp_out        = '0;
            rsp_out.uid    = lm_bid_reject_r.uid;
            rsp_out.status = ob_pkg::S_Reject;
            rsp_out.result = '0;
`endif
          end
          5'b00001: begin
            // Execute ask reject
            lm_ask_reject_pop = 'b1;

            cntrl_inst        = ob_cntrl_pkg::encode_reject_pop(
              .uid(lm_ask_reject_r.uid), .is_ask('b1));
`ifdef ENABLE_OLD
            // Emit output message
            rsp_out_vld    = 'b1;

            // Form output message:
            rsp_out        = '0;
            rsp_out.uid    = lm_ask_reject_r.uid;
            rsp_out.status = ob_pkg::S_Reject;
            rsp_out.result = '0;
`endif
          end
          5'b1????: begin
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

        casez ({lm_bid_qry_rsp_vld_r, lm_ask_qry_rsp_vld_r})
          2'b1?, 2'b01: begin
            // Consume command, now completed.
            cmd_consume              = 'b1;

            // Emit response
            cntrl_inst               =
              ob_cntrl_pkg::encode_emit_qry_result(
                .uid(cmd_latch_r.uid), .accum(qry_qty_combined));
`ifdef ENABLE_OLD
            rsp_out_vld              = 'b1;
            rsp_out                  = '0;
            rsp_out.uid              = cmd_latch_r.uid;
            rsp_out.status           = ob_pkg::S_Okay;
            rsp_out.result.qry.accum = qry_qty_combined;
`endif

            // Return to idle state.
            fsm_state_en             = 'b1;
            fsm_state_w              = FSM_CNTRL_IDLE;
          end
          default: begin
            // Otherwise, continue to await response from table count
            // controller.
          end
        endcase // casez ({lm_bid_qry_rsp_vld_r, lm_ask_qry_rsp_vld_r})

      end // case: FSM_CNTRL_QRY_TBL

      default:;

    endcase // case (fsm_state_r)

  end // block: cntrl_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : cancel_PROC

    // Latch on next is valid.
    lm_bid_cancel_hit_tbl_en = lm_bid_cancel_hit_w;

    // Latch on next is valid.
    lm_ask_cancel_hit_tbl_en = lm_ask_cancel_hit_w;

    // Latch on next is valid.
    mk_bid_cancel_hit_tbl_en = mk_bid_cancel_hit_w;

    // Latch on next is valid.
    mk_ask_cancel_hit_tbl_en = mk_ask_cancel_hit_w;

  end // block: cancel_PROC

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl_pkg::ucode_t                 decode_ucode;

  always_comb begin : decode_unpack_PROC

    // Response Interface:
    rsp_out_vld          = decode_ucode.rsp_vld;
    rsp_out              = decode_ucode.rsp;

    // Limit Bid Table Interface:
    lm_bid_reject_pop    = decode_ucode.lm_bid_reject_pop;
    lm_bid_insert        = decode_ucode.lm_bid_insert;
    lm_bid_insert_tbl    = decode_ucode.lm_bid_insert_tbl;
    lm_bid_pop           = decode_ucode.lm_bid_pop;
    lm_bid_update_vld    = decode_ucode.lm_bid_update_vld;
    lm_bid_update        = decode_ucode.lm_bid_update;
    lm_bid_cancel        = decode_ucode.lm_bid_cancel;
    lm_bid_cancel_uid    = decode_ucode.lm_bid_cancel_uid;
    lm_bid_qry_vld       = decode_ucode.lm_bid_qry_rsp_vld;
    lm_bid_qry_price     = decode_ucode.lm_bid_qry_price;
    lm_bid_qry_quantity  = decode_ucode.lm_bid_qry_quantity;

    // Limit Ask Table Interface:
    lm_ask_reject_pop    = decode_ucode.lm_ask_reject_pop;
    lm_ask_insert        = decode_ucode.lm_ask_insert;
    lm_ask_insert_tbl    = decode_ucode.lm_ask_insert_tbl;
    lm_ask_pop           = decode_ucode.lm_ask_pop;
    lm_ask_update_vld    = decode_ucode.lm_ask_update_vld;
    lm_ask_update        = decode_ucode.lm_ask_update;
    lm_ask_cancel        = decode_ucode.lm_ask_cancel;
    lm_ask_cancel_uid    = decode_ucode.lm_ask_cancel_uid;
    lm_ask_qry_vld       = decode_ucode.lm_ask_qry_rsp_vld;
    lm_ask_qry_price     = decode_ucode.lm_ask_qry_price;
    lm_ask_qry_quantity  = decode_ucode.lm_ask_qry_quantity;

    // Market Bid Table Interface:
    mk_bid_head_pop      = decode_ucode.mk_bid_head_pop;
    mk_bid_head_push     = decode_ucode.mk_bid_head_push;
    mk_bid_head_push_tbl = decode_ucode.mk_bid_head_push_tbl;
    mk_bid_insert        = decode_ucode.mk_bid_insert;
    mk_bid_insert_tbl    = decode_ucode.mk_bid_insert_tbl;
    mk_bid_cancel        = decode_ucode.mk_bid_cancel;
    mk_bid_cancel_uid    = decode_ucode.mk_bid_cancel_uid;

    // Market Ask Table Interface:
    mk_ask_head_pop      = decode_ucode.mk_ask_head_pop;
    mk_ask_head_push     = decode_ucode.mk_ask_head_push;
    mk_ask_head_push_tbl = decode_ucode.mk_ask_head_push_tbl;
    mk_ask_insert        = decode_ucode.mk_ask_insert;
    mk_ask_insert_tbl    = decode_ucode.mk_ask_insert_tbl;
    mk_ask_cancel        = decode_ucode.mk_ask_cancel;
    mk_ask_cancel_uid    = decode_ucode.mk_ask_cancel_uid;

  end // block: decode_unpack_PROC

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl_dec u_ob_cntrl_dec (
    //
      .inst                        (cntrl_inst              )
    //
    , .ucode                       (decode_ucode            )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl_lm u_ob_cntrl_lm (
    //
      .lm_bid_vld_r                (lm_bid_table_vld_r      )
    , .lm_bid_r                    (lm_bid_table_r          )
    //
    , .lm_ask_vld_r                (lm_ask_table_vld_r      )
    , .lm_ask_r                    (lm_ask_table_r          )
    //
    , .trade_qry                   (trade_qry               )
    , .trade_vld_r                 (lm_trade_vld_r          )
    , .trade_r                     (lm_trade_r              )
    //
    , .clk                         (clk                     )
    , .rst                         (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl_mk u_ob_cntrl_mk (
    //
      .lm_bid_vld_r                (lm_bid_table_vld_r      )
    , .lm_bid_r                    (lm_bid_table_r          )
    //
    , .lm_ask_vld_r                (lm_ask_table_vld_r      )
    , .lm_ask_r                    (lm_ask_table_r          )
    //
    , .mk_bid_head_vld_r           (mk_bid_head_vld_r       )
    , .mk_bid_head_r               (mk_bid_head_r           )
    //
    , .mk_ask_head_vld_r           (mk_ask_head_vld_r       )
    , .mk_ask_head_r               (mk_ask_head_r           )
    //
    , .trade_qry                   (trade_qry               )
    , .trade_vld_r                 (mk_trade_vld_r          )
    , .trade_r                     (mk_trade_r              )
    //
    , .clk                         (clk                     )
    , .rst                         (rst                     )
  );

endmodule // ob_cntrl
