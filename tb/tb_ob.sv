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

module tb_ob (

  // ======================================================================== //
  // Command Interface
    input                                         cmd_vld_r
  , input ob_pkg::opcode_t                        cmd_opcode_r
  , input ob_pkg::uid_t                           cmd_uid_r
  , input ob_pkg::quantity_t                      cmd_quantity_r
  , input bcd_pkg::price_t                        cmd_price_r
  , input ob_pkg::uid_t                           cmd_uid1_r
  //
  , output logic                                  cmd_full_r

  // ======================================================================== //
  // Response Interface
  , input                                         rsp_accept
  //
  , output logic                                  rsp_vld
  , output ob_pkg::uid_t                          rsp_uid
  , output ob_pkg::status_t                       rsp_status

  // Query Bid/Ask:
  , output bcd_pkg::price_t                       rsp_qry_bid
  , output bcd_pkg::price_t                       rsp_qry_ask

  // Pop top Bid/Ask:
  , output bcd_pkg::price_t                       rsp_pop_price
  , output ob_pkg::quantity_t                     rsp_pop_quantity
  , output ob_pkg::uid_t                          rsp_pop_uid

  // Trade:
  , output ob_pkg::uid_t                          rsp_trade_bid_uid
  , output ob_pkg::uid_t                          rsp_trade_ask_uid
  , output ob_pkg::quantity_t                     rsp_trade_quantity

  // ======================================================================== //
  // TB support
  , output logic [63:0]                           tb_cycle

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  initial tb_cycle  = '0;

  always_ff @(posedge clk)
    tb_cycle += 'b1;

  // ------------------------------------------------------------------------ //
  //
  ob_pkg::cmd_t                         cmd_r;

  always_comb begin : cmd_PROC

    cmd_r          = '0;
    cmd_r.opcode   = cmd_opcode_r;
    cmd_r.uid      = cmd_uid_r;
    cmd_r.quantity = cmd_quantity_r;
    cmd_r.price    = cmd_price_r;
    cmd_r.uid1     = cmd_uid1_r;

  end // block: cmd_PROC

  // ------------------------------------------------------------------------ //
  //
  ob_pkg::rsp_t                         rsp;

  always_comb begin : rsp_PROC

    //
    rsp_uid 	       = rsp.uid;
    rsp_status 	       = rsp.status;

    // Query Bid/Ask:
    rsp_qry_bid        = rsp.result.qrybidask.bid;
    rsp_qry_ask        = rsp.result.qrybidask.ask;

    // Pop top Bid/Ask:
    rsp_pop_price      = rsp.result.poptop.price;
    rsp_pop_quantity   = rsp.result.poptop.quantity;
    rsp_pop_uid        = rsp.result.poptop.uid;

    // Trade:
    rsp_trade_bid_uid  = rsp.result.trade.bid_uid;
    rsp_trade_ask_uid  = rsp.result.trade.ask_uid;
    rsp_trade_quantity = rsp.result.trade.quantity;

  end // block: rsp_PROC

  // ------------------------------------------------------------------------ //
  //
  ob u_ob (
    //
      .cmd_vld_r              (cmd_vld_r               )
    , .cmd_r                  (cmd_r                   )
    , .cmd_full_r             (cmd_full_r              )
    //
    , .rsp_accept             (rsp_accept              )
    , .rsp_vld                (rsp_vld                 )
    , .rsp                    (rsp                     )
    //
    , .clk                    (clk                     )
    , .rst                    (rst                     )
  );

endmodule // ob
