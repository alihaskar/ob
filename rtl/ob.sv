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
`include "cfg_pkg.vh"

module ob (
  // ======================================================================== //
  // Command Interface
    input                                         cmd_vld_r
  , input ob_pkg::cmd_t                           cmd_r
  //
  , output logic                                  cmd_full_r

  // ======================================================================== //
  // Response Interface
  , input                                         rsp_accept
  //
  , output logic                                  rsp_vld
  , output ob_pkg::rsp_t                          rsp

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);
   
  // ------------------------------------------------------------------------ //
  //
  `LIBV_QUEUE_WIRES(ingress_queue_, ob_pkg::cmd_t);

  `LIBV_REG_RST_R(logic, ingress_queue_empty, 'b1);
  `LIBV_REG_RST_R(logic, ingress_queue_full, 'b0);

  always_comb begin : in_PROC

    // -> OB interface
    ingress_queue_push 	    = cmd_vld_r;
    ingress_queue_push_data = cmd_r;

    ingress_queue_flush     = 'b0;
    ingress_queue_commit    = ingress_queue_push;
    ingress_queue_replay    = 'b0;

    cmd_full_r 		    = ingress_queue_full_r;

  end // block: in_PROC

  libv_queue #(.W($bits(ob_pkg::cmd_t)), .N(4)) u_ingress_queue (
    //
      .push              (ingress_queue_push      )
    , .push_data         (ingress_queue_push_data )
    //
    , .pop               (ingress_queue_pop       )
    , .pop_data          (ingress_queue_pop_data  )
    //
    , .flush             (ingress_queue_flush     )
    , .commit            (ingress_queue_commit    )
    , .replay            (ingress_queue_replay    )
    //
    , .empty_w           (ingress_queue_empty_w   )
    , .full_w            (ingress_queue_full_w    )
    //
    , .clk               (clk                     )
    , .rst               (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_table #(.N(cfg_pkg::BID_TABLE_N), .is_ask('b0)) u_bid_table (
    //
      .head_pop          ()
      //
    , .head_upt          ()
    , .head_upt_tbl      ()
    //
    , .head_vld_r        ()
    , .head_did_update_r ()
    , .head_r            ()
    //
    , .insert            ()
    , .insert_tbl        ()
    //
    , .delete            ()
    , .delete_uid        ()
    //
    , .delete_hit        ()
    , .delete_hit_tbl    ()
    //
    , .reject_pop        ()
    , .reject_valid_r    ()
    , .reject_r          ()
    //
    , .clk               (clk                     )
    , .rst               (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_table #(.N(cfg_pkg::ASK_TABLE_N), .is_ask('b1)) u_ask_table (
    //
      .head_pop          ()
      //
    , .head_upt          ()
    , .head_upt_tbl      ()
    //
    , .head_vld_r        ()
    , .head_did_update_r ()
    , .head_r            ()
    //
    , .insert            ()
    , .insert_tbl        ()
    //
    , .delete            ()
    , .delete_uid        ()
    //
    , .delete_hit        ()
    , .delete_hit_tbl    ()
    //
    , .reject_pop        ()
    , .reject_valid_r    ()
    , .reject_r          ()
    //
    , .clk               (clk                     )
    , .rst               (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl u_ob_cntrl (
    //
      .cmd_in_vld        ()
    , .cmd_in            ()
    //
    , .cmd_in_pop        ()
    //
    , .rsp_out_full_r    ()
    //
    , .rsp_out_vld       ()
    , .rsp_out           ()
    //
    , .bid_table_vld_r   ()
    , .bid_table_r       ()
    //
    , .bid_reject_vld_r  ()
    , .bid_reject_r      ()
    //
    , .bid_reject_pop    ()
    //
    , .bid_insert        ()
    , .bid_insert_tbl    ()
    //
    , .bid_pop           ()
    //
    , .bid_update_vld    ()
    , .bid_update        ()
    //
    , .ask_table_vld_r   ()
    , .ask_table_r       ()
    //
    , .ask_reject_vld_r  ()
    , .ask_reject_r      ()
    //
    , .ask_reject_pop    ()
    //
    , .ask_insert        ()
    , .ask_insert_tbl    ()
    //
    , .ask_pop           ()
    //
    , .ask_update_vld    ()
    , .ask_update        ()
    //
    , .clk               (clk                     )
    , .rst               (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  `LIBV_QUEUE_WIRES(egress_queue_, ob_pkg::rsp_t);

  `LIBV_REG_RST_R(logic, egress_queue_empty, 'b0);
  `LIBV_REG_RST_R(logic, egress_queue_full, 'b1);

  always_comb begin : out_PROC

    rsp_vld 	     = (~egress_queue_empty_r);
    rsp 	     = egress_queue_pop_data;

    egress_queue_pop = rsp_vld & rsp_accept;

  end // block: out_PROC

  libv_queue #(.W($bits(ob_pkg::rsp_t)), .N(4)) u_egress_queue (
    //
      .push              (egress_queue_push       )
    , .push_data         (egress_queue_push_data  )
    //
    , .pop               (egress_queue_pop        )
    , .pop_data          (egress_queue_pop_data   )
    //
    , .flush             (egress_queue_flush      )
    , .commit            (egress_queue_commit     )
    , .replay            (egress_queue_replay     )
    //
    , .empty_w           (egress_queue_empty_w    )
    , .full_w            (egress_queue_full_w     )
    //
    , .clk               (clk                     )
    , .rst               (rst                     )
  );

endmodule // ob
