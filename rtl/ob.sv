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
  logic                                 cntrl_cmd_in_vld;
  ob_pkg::cmd_t                         cntrl_cmd_in;
  logic                                 cntrl_cmd_in_pop;
  //
  logic 				cntrl_rsp_out_full_r;
  logic                                 cntrl_rsp_out_vld;
  ob_pkg::rsp_t                         cntrl_rsp_out;
  //
  logic 				cntrl_bid_table_vld_r;
  ob_pkg::table_t                       cntrl_bid_table_r;
  logic 				cntrl_bid_reject_vld_r;
  ob_pkg::table_t                       cntrl_bid_reject_r;
  logic 				cntrl_bid_reject_pop;
  logic 				cntrl_bid_insert;
  ob_pkg::table_t                       cntrl_bid_insert_tbl;
  logic                                 cntrl_bid_pop;
  logic 				cntrl_bid_update_vld;
  ob_pkg::table_t                       cntrl_bid_update;
  logic                                 cntrl_bid_cancel_hit_w;
  ob_pkg::table_t                       cntrl_bid_cancel_hit_tbl_w;
  logic                                 cntrl_bid_cancel;
  ob_pkg::uid_t                         cntrl_bid_cancel_uid;
  //
  logic 				cntrl_ask_table_vld_r;
  ob_pkg::table_t                       cntrl_ask_table_r;
  logic 				cntrl_ask_reject_vld_r;
  logic 				cntrl_ask_reject_pop;
  ob_pkg::table_t                       cntrl_ask_reject_r;
  logic 				cntrl_ask_insert;
  ob_pkg::table_t                       cntrl_ask_insert_tbl;
  logic                                 cntrl_ask_pop;
  logic 				cntrl_ask_update_vld;
  ob_pkg::table_t                       cntrl_ask_update;
  logic                                 cntrl_ask_cancel_hit_w;
  ob_pkg::table_t                       cntrl_ask_cancel_hit_tbl_w;
  logic                                 cntrl_ask_cancel;
  ob_pkg::uid_t                         cntrl_ask_cancel_uid;
   
  // ------------------------------------------------------------------------ //
  //
  `LIBV_QUEUE_WIRES(ingress_queue_, ob_pkg::cmd_t);
  `LIBV_REG_RST_R(logic, ingress_queue_empty, 'b1);
  `LIBV_REG_RST_R(logic, ingress_queue_full, 'b0);

  `LIBV_QUEUE_WIRES(egress_queue_, ob_pkg::rsp_t);
  `LIBV_REG_RST_R(logic, egress_queue_empty, 'b0);
  `LIBV_REG_RST_R(logic, egress_queue_full, 'b1);

  always_comb begin : in_PROC

    // -> OB interface
    ingress_queue_push 	    = cmd_vld_r;
    ingress_queue_push_data = cmd_r;

    ingress_queue_flush     = 'b0;
    ingress_queue_commit    = cntrl_cmd_in_pop;
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
      .head_pop          (cntrl_bid_pop                )
      //
    , .head_upt          (cntrl_bid_update_vld         )
    , .head_upt_tbl      (cntrl_bid_update             )
    //
    , .head_vld_r        (cntrl_bid_table_vld_r        )
    , .head_did_update_r ()
    , .head_r            (cntrl_bid_table_r            )
    //
    , .insert            (cntrl_bid_insert             )
    , .insert_tbl        (cntrl_bid_insert_tbl         )
    //
    , .cancel            (cntrl_bid_cancel             )
    , .cancel_uid        (cntrl_bid_cancel_uid         )
    //
    , .cancel_hit_w      (cntrl_bid_cancel_hit_w       )
    , .cancel_hit_tbl_w  (cntrl_bid_cancel_hit_tbl_w   )
    //
    , .reject_pop        (cntrl_bid_reject_pop         )
    , .reject_vld_r      (cntrl_bid_reject_vld_r       )
    , .reject_r          (cntrl_bid_reject_r           )
    //
    , .clk               (clk                          )
    , .rst               (rst                          )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_table #(.N(cfg_pkg::ASK_TABLE_N), .is_ask('b1)) u_ask_table (
    //
      .head_pop          (cntrl_ask_pop                )
      //
    , .head_upt          (cntrl_ask_update_vld         )
    , .head_upt_tbl      (cntrl_ask_update             )
    //
    , .head_vld_r        (cntrl_ask_table_vld_r        )
    , .head_did_update_r ()
    , .head_r            (cntrl_ask_table_r            )
    //
    , .insert            (cntrl_ask_insert             )
    , .insert_tbl        (cntrl_ask_insert_tbl         )
    //
    , .cancel            (cntrl_ask_cancel             )
    , .cancel_uid        (cntrl_ask_cancel_uid         )
    //
    , .cancel_hit_w      (cntrl_ask_cancel_hit_w       )
    , .cancel_hit_tbl_w  (cntrl_ask_cancel_hit_tbl_w   )
    //
    , .reject_pop        (cntrl_ask_reject_pop         )
    , .reject_vld_r      (cntrl_ask_reject_vld_r       )
    , .reject_r          (cntrl_ask_reject_r           )
    //
    , .clk               (clk                          )
    , .rst               (rst                          )
  );
  
  always_comb begin : ob_cntrl_PROC

    // Ingress Queue -> Ob. Cntrl.
    cntrl_cmd_in_vld 	   = (~ingress_queue_empty_r);
    cntrl_cmd_in 	   = ingress_queue_pop_data;
    ingress_queue_pop 	   = cntrl_cmd_in_pop;

    // Ob. Cntrl. -> Egress Queue 
    egress_queue_push 	   = cntrl_rsp_out_vld;
    egress_queue_push_data = cntrl_rsp_out;

  end // block: ob_cntrl_PROC

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl u_ob_cntrl (
    //
      .cmd_in_vld        (cntrl_cmd_in_vld             )
    , .cmd_in            (cntrl_cmd_in                 )
    //
    , .cmd_in_pop        (cntrl_cmd_in_pop             )
    //
    , .rsp_out_full_r    (cntrl_rsp_out_full_r         )
    //
    , .rsp_out_vld       (cntrl_rsp_out_vld            )
    , .rsp_out           (cntrl_rsp_out                )
    //
    , .bid_table_vld_r   (cntrl_bid_table_vld_r        )
    , .bid_table_r       (cntrl_bid_table_r            )
    //
    , .bid_reject_vld_r  (cntrl_bid_reject_vld_r       )
    , .bid_reject_r      (cntrl_bid_reject_r           )
    //
    , .bid_cancel_hit_w  (cntrl_bid_cancel_hit_w       )
    , .bid_cancel_hit_tbl_w (cntrl_bid_cancel_hit_tbl_w)
    //
    , .bid_reject_pop    (cntrl_bid_reject_pop         )
    //
    , .bid_insert        (cntrl_bid_insert             )
    , .bid_insert_tbl    (cntrl_bid_insert_tbl         )
    //
    , .bid_pop           (cntrl_bid_pop                )
    //
    , .bid_update_vld    (cntrl_bid_update_vld         )
    , .bid_update        (cntrl_bid_update             )
    //
    , .bid_cancel        (cntrl_bid_cancel             )
    , .bid_cancel_uid    (cntrl_bid_cancel_uid         )
    //
    , .ask_table_vld_r   (cntrl_ask_table_vld_r        )
    , .ask_table_r       (cntrl_ask_table_r            )
    //
    , .ask_reject_vld_r  (cntrl_ask_reject_vld_r       )
    , .ask_reject_r      (cntrl_ask_reject_r           )
    //
    , .ask_cancel_hit_w  (cntrl_ask_cancel_hit_w       )
    , .ask_cancel_hit_tbl_w(cntrl_ask_cancel_hit_tbl_w )
    //
    , .ask_reject_pop    (cntrl_ask_reject_pop         )
    //
    , .ask_insert        (cntrl_ask_insert             )
    , .ask_insert_tbl    (cntrl_ask_insert_tbl         )
    //
    , .ask_pop           (cntrl_ask_pop                )
    //
    , .ask_update_vld    (cntrl_ask_update_vld         )
    , .ask_update        (cntrl_ask_update             )
    //
    , .ask_cancel        (cntrl_ask_cancel             )
    , .ask_cancel_uid    (cntrl_ask_cancel_uid         )
    //
    , .clk               (clk                          )
    , .rst               (rst                          )
  );

  // ------------------------------------------------------------------------ //
  //
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
