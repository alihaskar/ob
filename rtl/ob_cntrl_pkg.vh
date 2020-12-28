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

`ifndef OB_RTL_OB_CNTRL_PKG_VH
`define OB_RTL_OB_CNTRL_PKG_VH

`include "ob_pkg.vh"
`include "bcd_pkg.vh"

package ob_cntrl_pkg;

  // In effect, the following structure corresponds to the set of all signals
  // which may be actively driven to external agents by the central controller
  // state machine.
  //
  typedef struct packed {
    // Response Interface:
    logic                     rsp_vld;
    ob_pkg::rsp_t             rsp;

    // Limit Bid Table Interface:
    logic                     lm_bid_reject_pop;
    logic                     lm_bid_insert;
    ob_pkg::table_t           lm_bid_insert_tbl;
    logic                     lm_bid_pop;
    logic                     lm_bid_update_vld;
    ob_pkg::table_t           lm_bid_update;
    logic                     lm_bid_cancel;
    ob_pkg::uid_t             lm_bid_cancel_uid;
    logic                     lm_bid_qry_rsp_vld;
    bcd_pkg::price_t          lm_bid_qry_price;
    ob_pkg::quantity_t        lm_bid_qry_quantity;

    // Limit Ask Table Interface:
    logic                     lm_ask_reject_pop;
    logic                     lm_ask_insert;
    ob_pkg::table_t           lm_ask_insert_tbl;
    logic                     lm_ask_pop;
    logic                     lm_ask_update_vld;
    ob_pkg::table_t           lm_ask_update;
    logic                     lm_ask_cancel;
    ob_pkg::uid_t             lm_ask_cancel_uid;
    logic                     lm_ask_qry_rsp_vld;
    bcd_pkg::price_t          lm_ask_qry_price;
    ob_pkg::quantity_t        lm_ask_qry_quantity;

    // Market Bid Interface
    logic                     mk_bid_head_pop;
    logic                     mk_bid_head_push;
    ob_pkg::table_t           mk_bid_head_push_tbl;
    logic                     mk_bid_insert;
    ob_pkg::table_t           mk_bid_insert_tbl;
    logic                     mk_bid_cancel;
    ob_pkg::uid_t             mk_bid_cancel_uid;

    // Market Ask Interface
    logic                     mk_ask_head_pop;
    logic                     mk_ask_head_push;
    ob_pkg::table_t           mk_ask_head_push_tbl;
    logic                     mk_ask_insert;
    ob_pkg::table_t           mk_ask_insert_tbl;
    logic                     mk_ask_cancel;
    ob_pkg::uid_t             mk_ask_cancel_uid;
  } ucode_t;

  typedef enum logic [2:0] { // Limit Ask
                             TBL_ID__LM_ASK = 3'b000,
                             // Limit Bid
                             TBL_ID__LM_BID = 3'b001,
                             // Market Ask
                             TBL_ID__MK_ASK = 3'b010,
                             // Market Bid
                             TBL_ID__MK_BID = 3'b011
                            } table_id_t;


  typedef enum logic [3:0] { // No-operation
                             OP_NOP                   = 4'b0000,
                             //
                             //
                             OP_SEARCH_RESULT         = 4'b0001,
                             //
                             //
                             OP_EMIT_RSP              = 4'b0010,
                             //
                             //
                             OP_PUSH_TABLE            = 4'b0011,
                             //
                             OP_POP_TABLE             = 4'b0100,
                             // Remove command "Reject" slot from nominated
                             // table and issue reject response message.
                             OP_REJECT_POP            = 4'b0101,
                             // Limit Ask/Bid table for eligable trades for a
                             // given giving asking/bidding price.
                             OP_ISSUE_QRY             = 4'b0110,
                             // Attempt to cancel a pending trade which may be
                             // currently retained by a table in the engine.
                             OP_ISSUE_CANCEL          = 4'b0111,
                             // Report current Bid/Ask price spread across
                             // current limit tables. Command succeeds only
                             // if both tables are populated.
                             OP_ISSUE_RSP_QRY_BID_ASK = 4'b1000,
                             //
                             //
                             OP_ISSUE_POP_TOP         = 4'b1001
                            } opcode_t;

  // Packed instruction format passed by the central control state machine to
  // the decoder.
  typedef struct packed {
    opcode_t opcode;

    union packed {

      // Opcode: OP_SEARCH_RESULT
      struct packed {
        ob_pkg::search_result_t sr;
      } search_result;

      // Opcode: OP_EMIT_RSP
      struct packed {
        // Side-effects:
        // Pop bid table limit reject slot.
        logic lm_bid_reject_pop;
        // Pop bid table limit reject slot.
        logic lm_ask_reject_pop;
        // Set accumulator field
        logic set_accum;
        // Quantity field.
        ob_pkg::accum_quantity_t accum;
        // UID attached to resposne
        ob_pkg::uid_t uid;
        // Status
        ob_pkg::status_t status;
      } emit_rsp;

      // Opcode: OP_PUSH_TABLE
      struct packed {
        // Command to be pushed to table.
        ob_pkg::cmd_t cmd;
        // ID of destination table.
        table_id_t table_id;
      } push_table;

      // Opcode: OP_POP_TABLE
      struct packed {
        table_id_t table_id;
      } pop_table;

      // Opcode: OP_REJECT_POP
      struct packed {
        // Pop ask table.
        logic is_ask;
        // Associated UID
        ob_pkg::uid_t uid;
      } reject_pop;

      // Opcode: OP_REJECT_POP
      struct packed {
        // Query ask table
        logic is_ask;
        // Associated Price
        bcd_pkg::price_t price;
        // Associated quantity (for early termination).
        ob_pkg::quantity_t quantity;
      } issue_qry;

      // Opcode: OP_ISSUE_CANCEL
      struct packed {
        // UID to be cancelled.
        ob_pkg::uid_t uid;
      } issue_cancel;

      // Opcode: OP_ISSUE_RSP_QRY_BID_ASK
      struct packed {
        // UID of command
        ob_pkg::uid_t uid;
        // Current bidding price
        bcd_pkg::price_t bid_price;
        // Current asking price
        bcd_pkg::price_t ask_price;
        // "Success" status of command.
        ob_pkg::status_t status;
      } qry_bid_ask;

      // Opcode: OP_ISSUE_POP_TOP
      struct packed {
        table_id_t id;
      } pop_top;

    } oprand;
  } inst_t;

  function automatic inst_t encode_nop; begin
    encode_nop = '0;
  end endfunction

  function automatic inst_t encode_search_result(
      ob_pkg::search_result_t sr); begin
    // Encode search result operation.
    inst_t ret;

    ret                         = '0;
    ret.opcode                  = OP_SEARCH_RESULT;
    ret.oprand.search_result.sr = sr;
    return ret;
  end endfunction

  function automatic inst_t encode_emit_rsp(
    ob_pkg::uid_t uid, ob_pkg::status_t status, logic lm_bid_reject_pop = 'b0,
    logic lm_ask_reject_pop = 'b0); begin

    inst_t ret;
    ret                                   = '0;
    ret.opcode                            = OP_EMIT_RSP;
    ret.oprand.emit_rsp.uid               = uid;
    ret.oprand.emit_rsp.status            = status;
    ret.oprand.emit_rsp.lm_bid_reject_pop = lm_bid_reject_pop;
    ret.oprand.emit_rsp.lm_ask_reject_pop = lm_ask_reject_pop;
    return ret;
  end endfunction

  function automatic inst_t encode_emit_qry_result(
    ob_pkg::uid_t uid, ob_pkg::accum_quantity_t accum); begin
    inst_t ret;
    ret                      = encode_emit_rsp(
      .uid(uid), .status(ob_pkg::S_Okay));
    // Set oprand as appropriate.
    ret.oprand.emit_rsp.set_accum = 'b1;
    ret.oprand.emit_rsp.accum     = accum;
    return ret;
  end endfunction

  function automatic inst_t encode_reject_cmd(ob_pkg::uid_t uid); begin
    return encode_emit_rsp(.uid(uid), .status(ob_pkg::S_Reject));
  end endfunction

  function automatic inst_t encode_push_table(
    ob_pkg::cmd_t cmd, table_id_t table_id); begin
    inst_t ret;

    ret                            = '0;
    ret.opcode                     = OP_PUSH_TABLE;
    ret.oprand.push_table          = '0;
    ret.oprand.push_table.cmd      = cmd;
    ret.oprand.push_table.table_id = table_id;
    return ret;
  end endfunction

  function automatic inst_t encode_pop_table(
    ob_pkg::cmd_t cmd, table_id_t table_id); begin
    inst_t ret;

    ret                           = '0;
    ret.opcode                    = OP_POP_TABLE;
    ret.oprand.pop_table.table_id = table_id;
    return ret;
  end endfunction

  function automatic inst_t encode_reject_pop(
    ob_pkg::uid_t uid, logic is_ask = 'b0); begin
    inst_t ret;
    ret                          = '0;
    ret.opcode                   = OP_REJECT_POP;
    ret.oprand.reject_pop.uid    = uid;
    ret.oprand.reject_pop.is_ask = is_ask;
    return ret;
  end endfunction

  function automatic inst_t encode_issue_qry(
    bcd_pkg::price_t price, ob_pkg::quantity_t quantity,
    logic is_ask = 'b0); begin
    inst_t ret;
    ret                           = '0;
    ret.opcode                    = OP_ISSUE_QRY;
    ret.oprand.issue_qry.price    = price;
    ret.oprand.issue_qry.quantity = quantity;
    ret.oprand.issue_qry.is_ask   = is_ask;
    return ret;
  end endfunction

  function automatic inst_t encode_emit_cancel(
    ob_pkg::uid_t uid); begin
    inst_t ret;
    ret                         = '0;
    ret.opcode                  = OP_ISSUE_CANCEL;
    ret.oprand.issue_cancel.uid = uid;
    return ret;
  end endfunction

  function automatic inst_t encode_emit_rsp_qry_bid_ask(
    ob_pkg::uid_t uid, bcd_pkg::price_t bid_price, bcd_pkg::price_t ask_price,
    ob_pkg::status_t status); begin
    inst_t ret;
    ret                          = '0;
    ret.opcode                   = OP_ISSUE_RSP_QRY_BID_ASK;
    ret.oprand.bid_ask           = '0;
    ret.oprand.bid_ask.uid       = uid;
    ret.oprand.bid_ask.bid_price = bid_price;
    ret.oprand.bid_ask.ask_price = ask_price;
    ret.oprand.bid_ask.status    = status;
    return ret;
  end endfunction

  function automatic inst_t encode_poptop(
    table_id_t id, ob_pkg::table_t t, ob_pkg::status_t status, logic is_ask = 'b0); begin
    inst_t ret;

    ret        = '0;
    ret.oprand = OP_ISSUE_POP_TOP;
    // TODO
    return ret;
  end endfunction

endpackage // ob_cntrl_pkg

`endif
