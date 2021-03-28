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

`default_nettype none
`timescale 1ns/1ps

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
  , output logic                                  rsp_out_vld_r
  , output ob_pkg::rsp_t                          rsp_out_r

  // ======================================================================== //
  // Event interface
  , output logic                                  evt_texe_r
  , output bcd_pkg::price_t                       evt_texe_ask_r
  , output bcd_pkg::price_t                       evt_texe_bid_r

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
  , output                                        mk_bid_head_upt
  , output ob_pkg::table_t                        mk_bid_head_upt_tbl
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
  // Control Interface
  , output logic                                  mk_bid_insert
  , output ob_pkg::table_t                        mk_bid_insert_tbl
  // Cancel UID Interface
  , output                                        mk_bid_cancel
  , output ob_pkg::uid_t                          mk_bid_cancel_uid
  //
  , input                                         mk_bid_qry_rsp_vld_r
  , input ob_pkg::accum_quantity_t                mk_bid_qry_rsp_qty_r
  //
  , output logic                                  mk_bid_qry_vld

  // ======================================================================== //
  // Market Ask Interface
  , input                                         mk_ask_head_vld_r
  , input                                         mk_ask_head_did_update_r
  , input ob_pkg::table_t                         mk_ask_head_r
  //
  , output                                        mk_ask_head_upt
  , output ob_pkg::table_t                        mk_ask_head_upt_tbl
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
  // Control Interface
  , output logic                                  mk_ask_insert
  , output ob_pkg::table_t                        mk_ask_insert_tbl
  // Cancel UID Interface
  , output                                        mk_ask_cancel
  , output ob_pkg::uid_t                          mk_ask_cancel_uid
  //
  , input                                         mk_ask_qry_rsp_vld_r
  , input ob_pkg::accum_quantity_t                mk_ask_qry_rsp_qty_r
  //
  , output logic                                  mk_ask_qry_vld

  // ======================================================================== //
  // Conditional command interface
  , output logic                                  cn_cmd_vld
  , output ob_pkg::cmd_t                          cn_cmd_r
  //
  , output logic                                  cn_mtr_accept
  //
  , input                                         cn_cancel_hit_w
  //
  , output logic                                  cn_cancel
  , output ob_pkg::uid_t                          cn_cancel_uid
  //
  , input                                         cn_mtr_vld_r
  , input ob_pkg::cmd_t                           cn_mtr_r
  //
  , input                                         cn_full_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  ob_pkg::uid_t     debug_ask_head_uid;
  bcd_pkg::price_t  debug_ask_head_price;
  ob_pkg::uid_t     debug_bid_head_uid;
  bcd_pkg::price_t  debug_bid_head_price;


  always_comb begin

    debug_ask_head_uid = lm_ask_table_r.uid;
    debug_ask_head_price = lm_ask_table_r.price;

    debug_bid_head_uid = lm_bid_table_r.uid;
    debug_bid_head_price = lm_ask_table_r.price;

  end

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

  `LIBV_REG_RST_R(logic, cn_cancel_hit, 'b0);

  `LIBV_REG_RST_R(logic, mk_bid_full, 'b0);
  `LIBV_REG_RST_R(logic, mk_bid_empty, 'b1);

  `LIBV_REG_RST_R(logic, mk_ask_full, 'b0);
  `LIBV_REG_RST_R(logic, mk_ask_empty, 'b1);

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST(logic, cmdl_vld, 'b0);
  `LIBV_REG_EN(ob_pkg::cmd_t, cmdl);
  logic                                      cmdl_adv;
  logic                                      cmdl_consume;
  logic                                      cmdl_cn_can_issue;
  logic                                      cmdl_cn_is_valid;

  always_comb begin : cmdl_PROC

    // Market orders are dependent upon the capacity of the market tables and
    // therefore commands cannot be dequeued from CN unless there is space
    // available in the tables for the command. Limit orders are always
    // actionable however as the limit tables always retain an unused reject
    // slot.
    //
    // Market orders: A one cycle hazard occurs in the cycle where the CN
    // command is injected into the command-latch and a command is already
    // present in the cmd_latch. To avoid the case where the current command
    // inserts an item in the market table, causing it to become full and
    // subsequently causing the following CN command to be rejected, we
    // specifically wait until no command is present, or, if a command is
    // present, that it is assured not to touch the corresponding market table.
    //
    // Recall also that commands returning from CN are no longer the "stop"
    // commands and have been permuted into their corresponding matured
    // commands: Stop -> Market, StopLimit -> Limit.
    //
    // Pleanty of opportunity for optimization here. Entirely possible for each
    // CN engine to emit some pre-decoded signals to avoid the decode logic here
    // at the cost of some additional flop overhead. This logic should not
    // however be on the critical path, therefore we're probably unconcerned
    // about it at the moment.
    //
    case (cn_mtr_r.opcode)
      ob_pkg::Op_BuyMarket: begin
        case ({cmdl_vld_r, mk_bid_full_r}) inside
          2'b0_0:  cmdl_cn_can_issue = 'b1;
          2'b1_0:  cmdl_cn_can_issue = (cmdl_r.opcode != ob_pkg::Op_BuyMarket);
          default: cmdl_cn_can_issue = 'b0;
        endcase // case ({cmdl_vld_r, mk_bid_full_r})
      end
      ob_pkg::Op_SellMarket: begin
        case ({cmdl_vld_r, mk_ask_full_r}) inside
          2'b0_0:  cmdl_cn_can_issue = 'b1;
          2'b1_0:  cmdl_cn_can_issue = (cmdl_r.opcode != ob_pkg::Op_SellMarket);
          default: cmdl_cn_can_issue = 'b0;
        endcase // case ({cmdl_vld_r, mk_bid_full_r})
      end
      ob_pkg::Op_BuyLimit,
      ob_pkg::Op_SellLimit: begin
        cmdl_cn_can_issue = 'b1;
      end
      default: begin
        // Otherwise, unknown command.
        cmdl_cn_can_issue = 'b0;
      end
    endcase // case (cn_mtr_r.opcode)

    // A conditional command has matured and is now ready to be issued.
    cmdl_cn_is_valid = cn_mtr_vld_r & cmdl_cn_can_issue;

    // The command latch advances whenever a command (at the latch) is consumed,
    // or if it currently invalid (sampling new state).
    cmdl_adv         = (~cmdl_vld_r) | cmdl_consume;

    // Pop ingress command queue when commands are present. Defeat in the
    // presence of a valid CN command.
    cmd_in_pop       = cmd_in_vld & (~cmdl_cn_is_valid) & cmdl_adv;

    // Accept matured CN command when present and when the command latch
    // advances.
    cn_mtr_accept    = cmdl_cn_is_valid & cmdl_adv;

    // Valid on fetch or Retain on not consume of prior.
    case ({cmd_in_pop, cn_mtr_accept, cmdl_consume}) inside
      3'b1??:  cmdl_vld_w = 'b1;
      3'b01?:  cmdl_vld_w = 'b1;
      3'b001:  cmdl_vld_w = 'b0;
      default: cmdl_vld_w = cmdl_vld_r;
    endcase // case ({cmd_in_pop, cn_mtr_accept, cmdl_consume})

    // Latch command on advancement.
    cmdl_en       = cmdl_adv;

    // Next command originates from the CN unit if command is accepted,
    // otherwise the ingress command queue.
    cmdl_w        = cn_mtr_accept ? cn_mtr_r : cmd_in;

  end // block: cmdl_PROC

  // ------------------------------------------------------------------------ //
  //
  typedef enum logic [4:0] { // Default idle state
                             FSM_CNTRL_IDLE            = 5'b00001,
                             // Issue table query on current
                             FSM_CNTRL_TABLE_ISSUE_QRY = 5'b00010,
                             // Execute query response
                             FSM_CNTRL_TABLE_EXECUTE   = 5'b00100,
                             // Receive cancel notification
                             FSM_CNTRL_CANCEL_RESP     = 5'b01000,
                             // Perform 'count' lookup on the nominated table.
                             FSM_CNTRL_QRY_TBL         = 5'b10000
                             } fsm_state_t;

  // State flop
  `LIBV_REG_EN_RST(fsm_state_t, fsm_state, FSM_CNTRL_IDLE);
  logic                                 trade_qry;
  logic                                 mk_trade_vld_r;
  ob_pkg::search_result_t               mk_trade_r;
  logic                                 lm_trade_vld_r;
  ob_pkg::search_result_t               lm_trade_r;

  `LIBV_REG_RST_W(logic, evt_texe, 'b0);
  `LIBV_REG_EN_W(bcd_pkg::price_t, evt_texe_ask);
  `LIBV_REG_EN_W(bcd_pkg::price_t, evt_texe_bid);
  `LIBV_REG_RST_W(logic, rsp_out_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::rsp_t, rsp_out);

  always_comb begin : cntrl_PROC

    // Defaults:

    // Machine events:
    evt_texe_w           = 'b0;
    evt_texe_ask_en      = '0;
    evt_texe_ask_w       = '0;
    evt_texe_ask_en      = '0;
    evt_texe_ask_w       = '0;

    // Command In:
    cmd_in_pop           = 'b0;

    // Response Out:
    rsp_out_vld_w        = 'b0;
    rsp_out_w            = '0;

    // State update:
    fsm_state_w          = fsm_state_r;
    fsm_state_en         = 'b0;

    // Command latch:
    cmdl_consume         = 'b0;

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

    mk_bid_head_upt      = 'b0;
    mk_bid_head_upt_tbl  = '0;

    mk_bid_insert        = 'b0;
    mk_bid_insert_tbl    = '0;

    mk_bid_cancel        = 'b0;
    mk_bid_cancel_uid    = '0;

    mk_bid_qry_vld       = 'b0;

    // Sell Market queue
    mk_ask_head_pop      = 'b0;
    mk_ask_head_push     = 'b0;
    mk_ask_head_push_tbl = '0;

    mk_ask_head_upt      = 'b0;
    mk_ask_head_upt_tbl  = '0;

    mk_ask_insert        = 'b0;
    mk_ask_insert_tbl    = '0;

    mk_ask_cancel        = 'b0;
    mk_ask_cancel_uid    = '0;

    mk_ask_qry_vld       = 'b0;

    // Conditionl defaults
    cn_cmd_vld           = 'b0;
    cn_cmd_r             = cmdl_r;
    cn_cancel            = 'b0;
    cn_cancel_uid        = '0;
    cn_mtr_accept        = 'b0;

    // Compare query
    trade_qry            = 'b0;

    case (fsm_state_r)

      FSM_CNTRL_IDLE: begin

        case ({cmdl_vld_r, rsp_out_vld_r})
          2'b1_0: begin

            // Command decode)
            case (cmdl_r.opcode)
              ob_pkg::Op_Nop: begin
                // No-Operation (NOP) generate Okay response for command.
                cmd_in_pop       = 'b1;

                // Consume command
                cmdl_consume     = 'b1;

                rsp_out_vld_w    = 'b1;

                rsp_out_w        = '0;
                rsp_out_w.uid    = cmdl_r.uid;
                rsp_out_w.status = ob_pkg::S_Okay;
              end // case: ob_pkg::Op_Nop
              ob_pkg::Op_QryBidAsk: begin
                // Qry Bid-/Ask- spread
                // Consume command
                cmdl_consume                   = 'b1;

                // Emit out:
                rsp_out_vld_w                  = 'b1;
                rsp_out_w                      = '0;
                rsp_out_w.uid                  = cmdl_r.uid;
                rsp_out_w.result               = '0;
                rsp_out_w.result.qrybidask.ask = lm_ask_table_r.price;
                rsp_out_w.result.qrybidask.bid = lm_bid_table_r.price;

                case ({lm_ask_table_vld_r, lm_bid_table_vld_r}) inside
                  2'b11:   rsp_out_w.status = ob_pkg::S_Okay;
                  default: rsp_out_w.status = ob_pkg::S_Bad;
                endcase // case ({lm_ask_table_vld_r, lm_bid_table_vld_r})
              end // case: ob_pkg::Op_QryBidAsk
              ob_pkg::Op_BuyLimit: begin
                ob_pkg::table_t lm_bid_table;

                cmdl_consume          = 'b1;

                lm_bid_table          = '0;
                lm_bid_table.uid      = cmdl_r.uid;
                lm_bid_table.quantity = cmdl_r.quantity;
                lm_bid_table.price    = cmdl_r.price;

                // Insert in Bid Table.
                lm_bid_insert         = 'b1;
                lm_bid_insert_tbl     = lm_bid_table;

                // Emit out:
                rsp_out_vld_w         = 'b1;

                // From response:
                rsp_out_w             = '0;
                rsp_out_w.uid         = cmdl_r.uid;
                rsp_out_w.status      = ob_pkg::S_Okay;

                // Next, query update table.
                fsm_state_en          = 'b1;
                fsm_state_w           = FSM_CNTRL_TABLE_ISSUE_QRY;
              end // case: ob_pkg::Op_BuyLimit
              ob_pkg::Op_SellLimit: begin
                ob_pkg::table_t lm_ask_table;

                cmdl_consume          = 'b1;

                // Await result of install operation.
                lm_ask_table          = '0;
                lm_ask_table.uid      = cmdl_r.uid;
                lm_ask_table.quantity = cmdl_r.quantity;
                lm_ask_table.price    = cmdl_r.price;

                // Insert in Ask Table.
                lm_ask_insert         = 'b1;
                lm_ask_insert_tbl     = lm_ask_table;

                // Emit out:
                rsp_out_vld_w         = 'b1;

                // From response:
                rsp_out_w             = '0;
                rsp_out_w.uid         = cmdl_r.uid;
                rsp_out_w.status      = ob_pkg::S_Okay;

                // Next, query update table.
                fsm_state_en          = 'b1;
                fsm_state_w           = FSM_CNTRL_TABLE_ISSUE_QRY;
              end // case: ob_pkg::Op_SellLimit
              ob_pkg::Op_PopTopBid: begin
                // Consume command
                cmdl_consume                     = 'b1;

                // Pop top valid item.
                lm_bid_pop                       = lm_bid_table_vld_r;

                // Emit out:
                rsp_out_vld_w                    = 'b1;
                rsp_out_w                        = '0;
                rsp_out_w.result                 = '0;
                rsp_out_w.result.poptop.price    = lm_bid_table_r.price;
                rsp_out_w.result.poptop.quantity = lm_bid_table_r.quantity;
                rsp_out_w.result.poptop.uid      = lm_bid_table_r.uid;

                rsp_out_w.uid                    = cmdl_r.uid;
                rsp_out_w.status                 = lm_bid_table_vld_r ?
                                                   ob_pkg::S_Okay :
                                                   ob_pkg::S_BadPop;
              end // case: ob_pkg::Op_PopTopBid
              ob_pkg::Op_PopTopAsk: begin
                // Consume command
                cmdl_consume                     = 'b1;

                // Pop top valid item.
                lm_ask_pop                       = lm_ask_table_vld_r;

                // Emit out:
                rsp_out_vld_w                    = 'b1;
                rsp_out_w.uid                    = cmdl_r.uid;
                rsp_out_w.result                 = '0;
                rsp_out_w.result.poptop.price    = lm_ask_table_r.price;
                rsp_out_w.result.poptop.quantity = lm_ask_table_r.quantity;
                rsp_out_w.result.poptop.uid      = lm_ask_table_r.uid;
                rsp_out_w.status                 = lm_ask_table_vld_r ?
                                                   ob_pkg::S_Okay :
                                                   ob_pkg::S_BadPop;
              end // case: ob_pkg::Op_PopTopAsk
              ob_pkg::Op_Cancel: begin
                // Issue cancel op. to Bid table.
                lm_bid_cancel     = 'b1;
                lm_bid_cancel_uid = cmdl_r.uid1;

                // Issue cancel op. to Bid table (market).
                mk_bid_cancel     = 'b1;
                mk_bid_cancel_uid = cmdl_r.uid1;

                // Issue cancel op. to Ask table.
                lm_ask_cancel     = 'b1;
                lm_ask_cancel_uid = cmdl_r.uid1;

                // Issue cancel op. to Ask table (market).
                mk_ask_cancel     = 'b1;
                mk_ask_cancel_uid = cmdl_r.uid1;

                // Issue cancel op. to CN table
                cn_cancel         = 'b1;
                cn_cancel_uid     = cmdl_r.uid1;

                // Advance to next state when egress queue is non-full, as
                // next state does not support back-pressure.
                fsm_state_en      = 'b1;
                fsm_state_w       = FSM_CNTRL_CANCEL_RESP;
              end // case: ob_pkg::Op_Cancel
              ob_pkg::Op_BuyMarket: begin
                // Market Buy command:
                cmdl_consume = 'b1;

                case ({mk_bid_full_r})
                  1'b1: begin
                    // Market sell buffer is full, command is rejected
                    rsp_out_vld_w    = 'b1;
                    rsp_out_w.uid    = cmdl_r.uid;
                    rsp_out_w.status = ob_pkg::S_Reject;
                    rsp_out_w.result = '0;
                  end
                  default: begin
                    // Insert into table.
                    mk_bid_insert              = 'b1;
                    mk_bid_insert_tbl          = '0;
                    mk_bid_insert_tbl.uid      = cmdl_r.uid;
                    mk_bid_insert_tbl.quantity = cmdl_r.quantity;
                    mk_bid_insert_tbl.price    = cmdl_r.price;

                    // Emit response
                    rsp_out_vld_w              = 'b1;
                    rsp_out_w                  = '0;
                    rsp_out_w.uid              = cmdl_r.uid;
                    rsp_out_w.status           = ob_pkg::S_Okay;

                    // Advance to query state
                    fsm_state_en               = 1'b1;
                    fsm_state_w                = FSM_CNTRL_TABLE_ISSUE_QRY;
                  end
                endcase // case ({mk_bid_full_r})
              end // case: ob_pkg::Op_BuyMarket
              ob_pkg::Op_SellMarket: begin
                // Market Sell command:
                cmdl_consume = 'b1;

                case ({mk_ask_full_r})
                  1'b1: begin
                    // Market sell buffer is full, command is rejected
                    rsp_out_vld_w    = 'b1;
                    rsp_out_w.uid    = cmdl_r.uid;
                    rsp_out_w.status = ob_pkg::S_Reject;
                    rsp_out_w.result = '0;
                  end
                  default: begin
                    // Insert into table.
                    mk_ask_insert              = 'b1;
                    mk_ask_insert_tbl          = '0;
                    mk_ask_insert_tbl.uid      = cmdl_r.uid;
                    mk_ask_insert_tbl.quantity = cmdl_r.quantity;
                    mk_ask_insert_tbl.price    = cmdl_r.price;

                    // Emit response
                    rsp_out_vld_w              = 'b1;
                    rsp_out_w                  = '0;
                    rsp_out_w.uid              = cmdl_r.uid;
                    rsp_out_w.status           = ob_pkg::S_Okay;

                    // Advance to query state.
                    fsm_state_en               = 1'b1;
                    fsm_state_w                = FSM_CNTRL_TABLE_ISSUE_QRY;
                  end
                endcase // case ({mk_ask_full_r})
              end // case: ob_pkg::Op_SellMarket
              ob_pkg::Op_QryTblAskLe: begin
                // Retain command at cmdl.

                // Issue query command (Limit)
                lm_ask_qry_vld      = 'b1;
                lm_ask_qry_price    = cmdl_r.price;
                lm_ask_qry_quantity = cmdl_r.quantity;

                // Issue query command (Market)
                mk_ask_qry_vld      = 'b1;

                // Transition to await response state.
                fsm_state_en        = 'b1;
                fsm_state_w         = FSM_CNTRL_QRY_TBL;
              end // case: ob_pkg::Op_QryTblAskLe
              ob_pkg::Op_QryTblBidGe: begin
                // Retain command at cmdl.

                // Issue query command (Limit)
                lm_bid_qry_vld      = 'b1;
                lm_bid_qry_price    = cmdl_r.price;
                lm_bid_qry_quantity = cmdl_r.quantity;

                // Issue query command (Market)
                mk_bid_qry_vld      = 'b1;

                // Transition to await response state.
                fsm_state_en        = 'b1;
                fsm_state_w         = FSM_CNTRL_QRY_TBL;
              end // case: ob_pkg::Op_QryTblBidGe
              ob_pkg::Op_BuyStopLoss,
              ob_pkg::Op_SellStopLoss,
              ob_pkg::Op_BuyStopLimit,
              ob_pkg::Op_SellStopLimit: begin
                // Conditional command(s), issue to conditional engine if non-full
                // otherwise reject on structural hazard.

                rsp_out_w     = '0;
                rsp_out_w.uid = cmdl_r.uid;

                case ({cn_full_r}) inside
                  1'b0: begin

                    // Consume command: is issued to CN unit.
                    cmdl_consume     = 'b1;

                    // Otherwise, we are free to issue command to conditional table.
                    cn_cmd_vld       = 'b1;

                    // Emit response
                    rsp_out_vld_w    = 'b1;
                    rsp_out_w.status = ob_pkg::S_Okay;
                  end
                  1'b1: begin
                    // Consume command: is rejected.
                    cmdl_consume     = 'b1;

                    // Reject command.
                    rsp_out_vld_w    = 'b1;
                    rsp_out_w.status = ob_pkg::S_Reject;
                  end
                  default: begin
                    // Stall current command awaiting output buffer entry.
                  end
                endcase
              end // case: ob_pkg::Op_BuyStopLoss,...
              default: begin
                // Invalid op:
              end
            endcase // case (ingress_queue_pop_data.opcode)
          end
          default: begin
            // Otherwise, blocked awaiting resources.
          end
        endcase // case (cmdl_vld_r, rsp_out_vld_r)

      end // case: FSM_CNTRL_IDLE

      FSM_CNTRL_CANCEL_RESP: begin
        if (!rsp_out_full_r) begin
        // In this state, the response to the prior cancel request has
        // been collated and is known. From this, form the final response
        // for the command to the egress queue and consume the command.
        //

        // Consume command.
        cmdl_consume = 'b1;

        rsp_out_vld_w = 'b1;
        rsp_out_w     = '0;
        rsp_out_w.uid = cmdl_r.uid;

        case ({// Bid limit table hits cancel
               lm_bid_cancel_hit_r,
               // Ask limit table hits cancel
               lm_ask_cancel_hit_r,
               // Bid market table hits cancel
               mk_bid_cancel_hit_r,
               // Ask market table table cancel
               mk_ask_cancel_hit_r,
               // CN table cancel
               cn_cancel_hit_r
               }) inside
          5'b1????: begin
            // Hit on bid table.
            rsp_out_w.status = ob_pkg::S_CancelHit;
          end
          5'b01???: begin
            // Hit on ask table.
            rsp_out_w.status = ob_pkg::S_CancelHit;
          end
          5'b001??: begin
            // Hit on bid market table.
            rsp_out_w.status = ob_pkg::S_CancelHit;
          end
          5'b0001?: begin
            // Hit on ask market table.
            rsp_out_w.status = ob_pkg::S_CancelHit;
          end
          5'b00001: begin
            // Hit on conditional table.
            rsp_out_w.status = ob_pkg::S_CancelHit;
          end
          default: begin
            // Miss, UID not found
            rsp_out_w.status = ob_pkg::S_CancelMiss;
          end
        endcase // case ({...

        // Advance to next state.
          fsm_state_en = 'b1;
          fsm_state_w  = FSM_CNTRL_IDLE;
        end

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
          5'b01???, 5'b001??: begin
            ob_pkg::search_result_t sr;
            // Select matching controller, prefer limit.
            sr         = lm_trade_vld_r ? lm_trade_r : mk_trade_r;

            case ({// LM/LM trade
                   sr.lm_ask_lm_bid,
                   // LM/MK trade
                   sr.lm_ask_mk_bid,
                   // MK/LM trade
                   sr.mk_ask_lm_bid,
                   // MK/MK trade
                   sr.mk_ask_mk_bid}) inside
              4'b1???: begin
                // Limit Ask <-> Limit Bid trade possible

                // Raise "Trade-Execute" event indicating that the current
                // bid/ask spread indicates the new market price. Note: we do
                // not consider market trades in this condition as we do not
                // consider market events to modify the market price, only limit
                // trades.
                evt_texe_w      = 'b1;

                // Emit traded asking price
                evt_texe_ask_en = 'b1;
                evt_texe_ask_w  = lm_ask_table_r.price;

                // Emit traded bidding price.
                evt_texe_bid_en = 'b1;
                evt_texe_bid_w  = lm_bid_table_r.price;

                case ({sr.bid_consumed, sr.ask_consumed})
                  2'b10: begin
                    // Discard entry at the head of the bid table.
                    lm_bid_pop             = 'b1;

                    // Update head entry in Ask limit table.
                    lm_ask_update_vld      = 'b1;
                    lm_ask_update          = lm_ask_table_r;
                    lm_ask_update.quantity = sr.remainder;
                  end
                  2'b01: begin
                    // Discard entry at the head of the ask table.
                    lm_ask_pop = 'b1;

                    // Update head entry in Bid limit table.
                    lm_bid_update_vld      = 'b1;
                    lm_bid_update          = lm_bid_table_r;
                    lm_bid_update.quantity = sr.remainder;
                  end
                  2'b11: begin
                    // Discard entries at the head of the bid and ask tables.
                    lm_bid_pop = 'b1;
                    lm_ask_pop = 'b1;
                  end
                  default: begin
                    // Otherwise, error: For a match, one of either entry must
                    // have been consumed.
                  end
                endcase

              end
              4'b01??: begin
                // Ask: Limit, Bid: Market

                case ({sr.bid_consumed, sr.ask_consumed})
                  2'b10: begin
                    // Discard bidder as consumed
                    mk_bid_head_pop        = 'b1;

                    // Update corresponding limit table entry.
                    lm_ask_update_vld      = 'b1;
                    lm_ask_update          = lm_ask_table_r;
                    lm_ask_update.quantity = sr.remainder;
                  end
                  2'b01: begin
                    // Discard asker as consumed
                    lm_ask_pop                   = 'b1;

                    // Update entry at the head of the bid market table.
                    mk_bid_head_upt              = 'b1;
                    mk_bid_head_upt_tbl          = mk_bid_head_r;
                    mk_bid_head_upt_tbl.quantity = sr.remainder;
                  end
                  2'b11: begin
                    // Discard bidder/asker as both consumed
                    mk_bid_head_pop = 'b1;
                    lm_ask_pop      = 'b1;
                  end
                  default: begin
                    // Otherwise, error: For a match, one of either entry must
                    // have been consumed.
                  end
                endcase

              end
              4'b001?: begin
                // Ask: Market, Limit: Bid

                case ({sr.bid_consumed, sr.ask_consumed})
                  2'b10: begin
                    lm_bid_pop                   = 'b1;

                    // Update entry at the head of the market ask table.
                    mk_ask_head_upt              = 'b1;
                    mk_ask_head_upt_tbl          = mk_ask_head_r;
                    mk_ask_head_upt_tbl.quantity = sr.remainder;
                  end
                  2'b01: begin
                    mk_ask_head_pop        = 'b1;

                    lm_bid_update_vld      = 'b1;
                    lm_bid_update          = lm_bid_table_r;
                    lm_bid_update.quantity = sr.remainder;
                  end
                  2'b11: begin
                    lm_bid_pop      = 'b1;
                    mk_ask_head_pop = 'b1;
                  end
                  default: begin
                    // Otherwise, error: For a match, one of either entry must
                    // have been consumed.
                  end
                endcase

              end
              4'b0001: begin
                // Ask: Market, Limit: Market

                case ({sr.bid_consumed, sr.ask_consumed})
                  2'b10: begin
                    mk_bid_head_pop = 'b1;

                    // Update entry at the head of the market ask table.
                    mk_ask_head_upt              = 'b1;
                    mk_ask_head_upt_tbl          = mk_ask_head_r;
                    mk_ask_head_upt_tbl.quantity = sr.remainder;
                  end
                  2'b01: begin
                    mk_ask_head_pop = 'b1;

                    // Update entry at the head of the market ask table.
                    mk_bid_head_upt              = 'b1;
                    mk_bid_head_upt_tbl          = mk_bid_head_r;
                    mk_bid_head_upt_tbl.quantity = sr.remainder;
                  end
                  2'b11: begin
                    mk_bid_head_pop = 'b1;
                    mk_ask_head_pop = 'b1;
                  end
                  default: begin
                    // Otherwise, error: For a match, one of either entry must
                    // have been consumed.
                  end
                endcase

              end
              default: begin
                // Otherwise, error: Cannot have hit in the query engines and
                // yet have produced no actual match.
              end
            endcase // case ({...

            // Emit output message
            rsp_out_vld_w                   = 'b1;

            // Form output message
            rsp_out_w                       = '0;
            // Trade has no originator ID
            rsp_out_w.uid                   = '1;
            rsp_out_w.status                = ob_pkg::S_Okay;
            rsp_out_w.result.trade          = '0;
            rsp_out_w.result.trade.bid_uid  = sr.bid_uid;
            rsp_out_w.result.trade.ask_uid  = sr.ask_uid;
            rsp_out_w.result.trade.quantity = sr.quantity;

            // Return to query state to attempt further trades.
            fsm_state_en                    = 'b1;
            fsm_state_w                     = FSM_CNTRL_TABLE_ISSUE_QRY;
          end // case: inside...
          5'b0001?: begin
            // Execute bid reject
            lm_bid_reject_pop = 'b1;

            // Emit output message
            rsp_out_vld_w     = 'b1;

            // Form output message:
            rsp_out_w         = '0;
            rsp_out_w.uid     = lm_bid_reject_r.uid;
            rsp_out_w.status  = ob_pkg::S_Reject;
            rsp_out_w.result  = '0;
          end
          5'b00001: begin
            // Execute ask reject
            lm_ask_reject_pop = 'b1;

            // Emit output message
            rsp_out_vld_w     = 'b1;

            // Form output message:
            rsp_out_w         = '0;
            rsp_out_w.uid     = lm_ask_reject_r.uid;
            rsp_out_w.status  = ob_pkg::S_Reject;
            rsp_out_w.result  = '0;
          end
          5'b1????: begin
              // Stalled on output resources.
          end
          default: begin
            // Consume command

            // Otherwise, no further work. Return to IDLE state.
            fsm_state_en = 'b1;
            fsm_state_w  = FSM_CNTRL_IDLE;
          end
        endcase // case ({...

      end // case: FSM_CNTRL_TABLE_EXECUTE

      FSM_CNTRL_QRY_TBL: begin
        if (!rsp_out_full_r) begin

        // Response defaults:
        rsp_out_w        = '0;
        rsp_out_w.uid    = cmdl_r.uid;
        rsp_out_w.status = ob_pkg::S_Okay;

        case (cmdl_r.opcode)
          ob_pkg::Op_QryTblAskLe: begin

            case ({lm_ask_qry_rsp_vld_r, mk_ask_qry_rsp_vld_r}) inside
              2'b1_1: begin
                // Command complete, advance.
                cmdl_consume               = 'b1;

                // Emit response:
                rsp_out_vld_w              = 'b1;
                rsp_out_w.result.qry.accum =
                  (lm_ask_qry_rsp_qty_r + mk_ask_qry_rsp_qty_r);
              end
              default: begin
                // Otherwise, continue to await completion of counter
                // operations.
              end
            endcase // case ({lm_ask_qry_rsp_vld_r, mk_ask_qry_rsp_vld_r})

          end // case: ob_pkg::Op_QryTblAskLe

          ob_pkg::Op_QryTblBidGe: begin

            case ({lm_bid_qry_rsp_vld_r, mk_bid_qry_rsp_vld_r}) inside
              2'b1_1: begin
                // Command complete, advance.
                cmdl_consume               = 'b1;

                // Emit response:
                rsp_out_vld_w              = 'b1;
                rsp_out_w.result.qry.accum =
                  (lm_bid_qry_rsp_qty_r + mk_bid_qry_rsp_qty_r);
              end
              default: begin
                // Otherwise, continue to await completion of counter
                // operations.
              end
            endcase // case ({lm_bid_qry_rsp_vld_r, mk_bid_qry_rsp_vld_r})

          end // case: ob_pkg::Op_QryTblBidGe

          default: begin
            // Otherwise, todo:
          end
        endcase // case (cmdl_r.opcode)

        // Return to idle state
          fsm_state_en = cmdl_consume;
          fsm_state_w  = FSM_CNTRL_IDLE;
        end

      end // case: FSM_CNTRL_QRY_TBL

      default:;

    endcase // case (fsm_state_r)

    // Latch output on becoming valid.
    rsp_out_en = rsp_out_vld_w;

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

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

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
