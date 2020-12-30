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
  logic                                 cmd_in_vld;
  ob_pkg::cmd_t                         cmd_in;
  logic                                 cmd_in_pop;
  //
  logic                                 rsp_out_full_r;
  logic                                 rsp_out_vld_r;
  ob_pkg::rsp_t                         rsp_out_r;
  //
  logic                                 lm_bid_table_vld_r;
  ob_pkg::table_t                       lm_bid_table_r;
  logic                                 lm_bid_reject_vld_r;
  ob_pkg::table_t                       lm_bid_reject_r;
  logic                                 lm_bid_reject_pop;
  logic                                 lm_bid_insert;
  ob_pkg::table_t                       lm_bid_insert_tbl;
  logic                                 lm_bid_pop;
  logic                                 lm_bid_update_vld;
  ob_pkg::table_t                       lm_bid_update;
  logic                                 lm_bid_cancel_hit_w;
  ob_pkg::table_t                       lm_bid_cancel_hit_tbl_w;
  logic                                 lm_bid_cancel;
  ob_pkg::uid_t                         lm_bid_cancel_uid;
  logic                                 lm_bid_qry_rsp_vld_r;
  logic                                 lm_bid_qry_rsp_is_ge_r;
  ob_pkg::accum_quantity_t              lm_bid_qry_rsp_qty_r;
  logic                                 lm_bid_qry_vld;
  bcd_pkg::price_t                      lm_bid_qry_price;
  ob_pkg::quantity_t                    lm_bid_qry_quantity;
  //
  logic                                 lm_ask_table_vld_r;
  ob_pkg::table_t                       lm_ask_table_r;
  logic                                 lm_ask_reject_vld_r;
  logic                                 lm_ask_reject_pop;
  ob_pkg::table_t                       lm_ask_reject_r;
  logic                                 lm_ask_insert;
  ob_pkg::table_t                       lm_ask_insert_tbl;
  logic                                 lm_ask_pop;
  logic                                 lm_ask_update_vld;
  ob_pkg::table_t                       lm_ask_update;
  logic                                 lm_ask_cancel_hit_w;
  ob_pkg::table_t                       lm_ask_cancel_hit_tbl_w;
  logic                                 lm_ask_cancel;
  ob_pkg::uid_t                         lm_ask_cancel_uid;
  logic                                 lm_ask_qry_rsp_vld_r;
  logic                                 lm_ask_qry_rsp_is_ge_r;
  ob_pkg::accum_quantity_t              lm_ask_qry_rsp_qty_r;
  logic                                 lm_ask_qry_vld;
  bcd_pkg::price_t                      lm_ask_qry_price;
  ob_pkg::quantity_t                    lm_ask_qry_quantity;
  //
  logic                                 mk_bid_head_pop;
  logic                                 mk_bid_head_push;
  ob_pkg::table_t                       mk_bid_head_push_tbl;
  logic                                 mk_bid_head_upt;
  ob_pkg::table_t                       mk_bid_head_upt_tbl;
  logic                                 mk_bid_head_vld_r;
  logic                                 mk_bid_head_did_update_r;
  ob_pkg::table_t                       mk_bid_head_r;
  logic                                 mk_bid_insert;
  ob_pkg::table_t                       mk_bid_insert_tbl;
  logic                                 mk_bid_cancel;
  ob_pkg::uid_t                         mk_bid_cancel_uid;
  logic                                 mk_bid_cancel_hit_w;
  ob_pkg::table_t                       mk_bid_cancel_hit_tbl_w;
  logic                                 mk_bid_full_w;
  logic                                 mk_bid_empty_w;
  logic                                 mk_bid_qry_vld;
  logic                                 mk_bid_qry_rsp_vld_r;
  ob_pkg::accum_quantity_t              mk_bid_qry_rsp_qty_r;
  //
  logic                                 mk_ask_head_pop;
  logic                                 mk_ask_head_push;
  ob_pkg::table_t                       mk_ask_head_push_tbl;
  logic                                 mk_ask_head_upt;
  ob_pkg::table_t                       mk_ask_head_upt_tbl;
  logic                                 mk_ask_head_vld_r;
  logic                                 mk_ask_head_did_update_r;
  ob_pkg::table_t                       mk_ask_head_r;
  logic                                 mk_ask_insert;
  ob_pkg::table_t                       mk_ask_insert_tbl;
  logic                                 mk_ask_cancel;
  ob_pkg::uid_t                         mk_ask_cancel_uid;
  logic                                 mk_ask_cancel_hit_w;
  ob_pkg::table_t                       mk_ask_cancel_hit_tbl_w;
  logic                                 mk_ask_full_w;
  logic                                 mk_ask_empty_w;
  logic                                 mk_ask_qry_vld;
  logic                                 mk_ask_qry_rsp_vld_r;
  ob_pkg::accum_quantity_t              mk_ask_qry_rsp_qty_r;
  //
  logic                                 cn_cmd_vld;
  ob_pkg::cmd_t                         cn_cmd_r;
  logic                                 cn_mtr_accept;
  logic                                 cn_cancel_hit_w;
  logic                                 cn_cancel;
  ob_pkg::uid_t                         cn_cancel_uid;
  logic                                 cn_mtr_vld_r;
  ob_pkg::cmd_t                         cn_mtr_r;
  logic                                 cn_full_r;
  //
  logic                                 cntrl_evt_texe_r;

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
    ingress_queue_push      = cmd_vld_r;
    ingress_queue_push_data = cmd_r;

    ingress_queue_flush     = 'b0;
    ingress_queue_commit    = cmd_in_pop;
    ingress_queue_replay    = 'b0;

    cmd_full_r              = ingress_queue_full_r;

  end // block: in_PROC

  libv_queue #(.W($bits(ob_pkg::cmd_t)), .N(4)) u_ingress_queue (
    //
      .push                   (ingress_queue_push      )
    , .push_data              (ingress_queue_push_data )
    //
    , .pop                    (ingress_queue_pop       )
    , .pop_data               (ingress_queue_pop_data  )
    //
    , .flush                  (ingress_queue_flush     )
    , .commit                 (ingress_queue_commit    )
    , .replay                 (ingress_queue_replay    )
    //
    , .empty_w                (ingress_queue_empty_w   )
    , .full_w                 (ingress_queue_full_w    )
    //
    , .clk                    (clk                     )
    , .rst                    (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_lm_table #(.N(cfg_pkg::BID_TABLE_DEPTH_N), .is_ask('b0)) u_lm_table_bid (
    //
      .head_pop               (lm_bid_pop                )
      //
    , .head_upt               (lm_bid_update_vld         )
    , .head_upt_tbl           (lm_bid_update             )
    //
    , .head_vld_r             (lm_bid_table_vld_r        )
    , .head_did_update_r      ()
    , .head_r                 (lm_bid_table_r            )
    //
    , .insert                 (lm_bid_insert             )
    , .insert_tbl             (lm_bid_insert_tbl         )
    //
    , .cancel                 (lm_bid_cancel             )
    , .cancel_uid             (lm_bid_cancel_uid         )
    //
    , .cancel_hit_w           (lm_bid_cancel_hit_w       )
    , .cancel_hit_tbl_w       (lm_bid_cancel_hit_tbl_w   )
    //
    , .reject_pop             (lm_bid_reject_pop         )
    , .reject_vld_r           (lm_bid_reject_vld_r       )
    , .reject_r               (lm_bid_reject_r           )
    //
    , .qry_vld                (lm_bid_qry_vld            )
    , .qry_price              (lm_bid_qry_price          )
    , .qry_quantity           (lm_bid_qry_quantity       )
    //
    , .qry_rsp_vld_r          (lm_bid_qry_rsp_vld_r      )
    , .qry_rsp_is_ge_r        (lm_bid_qry_rsp_is_ge_r    )
    , .qry_rsp_qty_r          (lm_bid_qry_rsp_qty_r      )
    //
    , .clk                    (clk                       )
    , .rst                    (rst                       )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_lm_table #(.N(cfg_pkg::ASK_TABLE_DEPTH_N), .is_ask('b1)) u_lm_table_ask (
    //
      .head_pop               (lm_ask_pop                )
      //
    , .head_upt               (lm_ask_update_vld         )
    , .head_upt_tbl           (lm_ask_update             )
    //
    , .head_vld_r             (lm_ask_table_vld_r        )
    , .head_did_update_r      ()
    , .head_r                 (lm_ask_table_r            )
    //
    , .insert                 (lm_ask_insert             )
    , .insert_tbl             (lm_ask_insert_tbl         )
    //
    , .cancel                 (lm_ask_cancel             )
    , .cancel_uid             (lm_ask_cancel_uid         )
    //
    , .cancel_hit_w           (lm_ask_cancel_hit_w       )
    , .cancel_hit_tbl_w       (lm_ask_cancel_hit_tbl_w   )
    //
    , .reject_pop             (lm_ask_reject_pop         )
    , .reject_vld_r           (lm_ask_reject_vld_r       )
    , .reject_r               (lm_ask_reject_r           )
    //
    , .qry_vld                (lm_ask_qry_vld            )
    , .qry_price              (lm_ask_qry_price          )
    , .qry_quantity           (lm_ask_qry_quantity       )
    //
    , .qry_rsp_vld_r          (lm_ask_qry_rsp_vld_r      )
    , .qry_rsp_is_ge_r        (lm_ask_qry_rsp_is_ge_r    )
    , .qry_rsp_qty_r          (lm_ask_qry_rsp_qty_r      )
    //
    , .clk                    (clk                       )
    , .rst                    (rst                       )
  );

  always_comb begin : ob_cntrl_PROC

    // Ingress Queue -> Ob. Cntrl.
    cmd_in_vld             = (~ingress_queue_empty_r);
    cmd_in                 = ingress_queue_pop_data;
    ingress_queue_pop      = cmd_in_pop;

    // Ob. Cntrl. -> Egress Queue
    egress_queue_push      = rsp_out_vld_r;
    egress_queue_push_data = rsp_out_r;

  end // block: ob_cntrl_PROC

  // ------------------------------------------------------------------------ //
  //
  ob_cntrl u_ob_cntrl (
    //
      .cmd_in_vld                  (cmd_in_vld                   )
    , .cmd_in                      (cmd_in                       )
    , .cmd_in_pop                  (cmd_in_pop                   )
    //
    , .rsp_out_full_r              (rsp_out_full_r               )
    , .rsp_out_vld_r               (rsp_out_vld_r                )
    , .rsp_out_r                   (rsp_out_r                    )
    //
    , .evt_texe_r                  (cntrl_evt_texe_r             )
    //
    , .lm_bid_table_vld_r          (lm_bid_table_vld_r           )
    , .lm_bid_table_r              (lm_bid_table_r               )
    , .lm_bid_reject_vld_r         (lm_bid_reject_vld_r          )
    , .lm_bid_reject_r             (lm_bid_reject_r              )
    , .lm_bid_cancel_hit_w         (lm_bid_cancel_hit_w          )
    , .lm_bid_cancel_hit_tbl_w     (lm_bid_cancel_hit_tbl_w      )
    , .lm_bid_reject_pop           (lm_bid_reject_pop            )
    , .lm_bid_insert               (lm_bid_insert                )
    , .lm_bid_insert_tbl           (lm_bid_insert_tbl            )
    , .lm_bid_pop                  (lm_bid_pop                   )
    , .lm_bid_update_vld           (lm_bid_update_vld            )
    , .lm_bid_update               (lm_bid_update                )
    , .lm_bid_cancel               (lm_bid_cancel                )
    , .lm_bid_cancel_uid           (lm_bid_cancel_uid            )
    , .lm_bid_qry_rsp_vld_r        (lm_bid_qry_rsp_vld_r         )
    , .lm_bid_qry_rsp_is_ge_r      (lm_bid_qry_rsp_is_ge_r       )
    , .lm_bid_qry_rsp_qty_r        (lm_bid_qry_rsp_qty_r         )
    , .lm_bid_qry_vld              (lm_bid_qry_vld               )
    , .lm_bid_qry_price            (lm_bid_qry_price             )
    , .lm_bid_qry_quantity         (lm_bid_qry_quantity          )
    //
    , .lm_ask_table_vld_r          (lm_ask_table_vld_r           )
    , .lm_ask_table_r              (lm_ask_table_r               )
    , .lm_ask_reject_vld_r         (lm_ask_reject_vld_r          )
    , .lm_ask_reject_r             (lm_ask_reject_r              )
    , .lm_ask_cancel_hit_w         (lm_ask_cancel_hit_w          )
    , .lm_ask_cancel_hit_tbl_w     (lm_ask_cancel_hit_tbl_w      )
    , .lm_ask_reject_pop           (lm_ask_reject_pop            )
    , .lm_ask_insert               (lm_ask_insert                )
    , .lm_ask_insert_tbl           (lm_ask_insert_tbl            )
    , .lm_ask_pop                  (lm_ask_pop                   )
    , .lm_ask_update_vld           (lm_ask_update_vld            )
    , .lm_ask_update               (lm_ask_update                )
    , .lm_ask_cancel               (lm_ask_cancel                )
    , .lm_ask_cancel_uid           (lm_ask_cancel_uid            )
    , .lm_ask_qry_rsp_vld_r        (lm_ask_qry_rsp_vld_r         )
    , .lm_ask_qry_rsp_is_ge_r      (lm_ask_qry_rsp_is_ge_r       )
    , .lm_ask_qry_rsp_qty_r        (lm_ask_qry_rsp_qty_r         )
    , .lm_ask_qry_vld              (lm_ask_qry_vld               )
    , .lm_ask_qry_price            (lm_ask_qry_price             )
    , .lm_ask_qry_quantity         (lm_ask_qry_quantity          )
    //
    , .mk_bid_head_pop             (mk_bid_head_pop              )
    , .mk_bid_head_push            (mk_bid_head_push             )
    , .mk_bid_head_push_tbl        (mk_bid_head_push_tbl         )
    , .mk_bid_head_upt             (mk_bid_head_upt              )
    , .mk_bid_head_upt_tbl         (mk_bid_head_upt_tbl          )
    , .mk_bid_head_vld_r           (mk_bid_head_vld_r            )
    , .mk_bid_head_did_update_r    (mk_bid_head_did_update_r     )
    , .mk_bid_head_r               (mk_bid_head_r                )
    , .mk_bid_insert               (mk_bid_insert                )
    , .mk_bid_insert_tbl           (mk_bid_insert_tbl            )
    , .mk_bid_cancel               (mk_bid_cancel                )
    , .mk_bid_cancel_uid           (mk_bid_cancel_uid            )
    , .mk_bid_cancel_hit_w         (mk_bid_cancel_hit_w          )
    , .mk_bid_cancel_hit_tbl_w     (mk_bid_cancel_hit_tbl_w      )
    , .mk_bid_full_w               (mk_bid_full_w                )
    , .mk_bid_empty_w              (mk_bid_empty_w               )
    , .mk_bid_qry_vld              (mk_bid_qry_vld               )
    , .mk_bid_qry_rsp_vld_r        (mk_bid_qry_rsp_vld_r         )
    , .mk_bid_qry_rsp_qty_r        (mk_bid_qry_rsp_qty_r         )
    //
    , .mk_ask_head_pop             (mk_ask_head_pop              )
    , .mk_ask_head_push            (mk_ask_head_push             )
    , .mk_ask_head_push_tbl        (mk_ask_head_push_tbl         )
    , .mk_ask_head_upt             (mk_ask_head_upt              )
    , .mk_ask_head_upt_tbl         (mk_ask_head_upt_tbl          )
    , .mk_ask_head_vld_r           (mk_ask_head_vld_r            )
    , .mk_ask_head_did_update_r    (mk_ask_head_did_update_r     )
    , .mk_ask_head_r               (mk_ask_head_r                )
    , .mk_ask_insert               (mk_ask_insert                )
    , .mk_ask_insert_tbl           (mk_ask_insert_tbl            )
    , .mk_ask_cancel               (mk_ask_cancel                )
    , .mk_ask_cancel_uid           (mk_ask_cancel_uid            )
    , .mk_ask_cancel_hit_w         (mk_ask_cancel_hit_w          )
    , .mk_ask_cancel_hit_tbl_w     (mk_ask_cancel_hit_tbl_w      )
    , .mk_ask_full_w               (mk_ask_full_w                )
    , .mk_ask_empty_w              (mk_ask_empty_w               )
    , .mk_ask_qry_vld              (mk_ask_qry_vld               )
    , .mk_ask_qry_rsp_vld_r        (mk_ask_qry_rsp_vld_r         )
    , .mk_ask_qry_rsp_qty_r        (mk_ask_qry_rsp_qty_r         )
    //
    , .cn_cmd_vld                  (cn_cmd_vld                   )
    , .cn_cmd_r                    (cn_cmd_r                     )
    , .cn_mtr_accept               (cn_mtr_accept                )
    , .cn_cancel_hit_w             (cn_cancel_hit_w              )
    , .cn_cancel                   (cn_cancel                    )
    , .cn_cancel_uid               (cn_cancel_uid                )
    , .cn_mtr_vld_r                (cn_mtr_vld_r                 )
    , .cn_mtr_r                    (cn_mtr_r                     )
    , .cn_full_r                   (cn_full_r                    )
    //
    , .clk                         (clk                          )
    , .rst                         (rst                          )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_mk_table #(.N(cfg_pkg::MARKET_BID_DEPTH_N)) u_mk_table_bid (
    //
      .head_pop                    (mk_bid_head_pop              )
    //
    , .head_push                   (mk_bid_head_push             )
    , .head_push_tbl               (mk_bid_head_push_tbl         )
    //
    , .head_upt                    (mk_bid_head_upt              )
    , .head_upt_tbl                (mk_bid_head_upt_tbl          )
    //
    , .head_vld_r                  (mk_bid_head_vld_r            )
    , .head_did_update_r           (mk_bid_head_did_update_r     )
    , .head_r                      (mk_bid_head_r                )
    //
    , .insert                      (mk_bid_insert                )
    , .insert_tbl                  (mk_bid_insert_tbl            )
    //
    , .cancel                      (mk_bid_cancel                )
    , .cancel_uid                  (mk_bid_cancel_uid            )
    , .cancel_hit_w                (mk_bid_cancel_hit_w          )
    , .cancel_hit_tbl_w            (mk_bid_cancel_hit_tbl_w      )
    //
    , .full_w                      (mk_bid_full_w                )
    , .empty_w                     (mk_bid_empty_w               )
    //
    , .qry_vld                     (mk_bid_qry_vld               )
    , .qry_rsp_vld_r               (mk_bid_qry_rsp_vld_r         )
    , .qry_rsp_qty_r               (mk_bid_qry_rsp_qty_r         )
    //
    , .clk                         (clk                          )
    , .rst                         (rst                          )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_mk_table #(.N(cfg_pkg::MARKET_ASK_DEPTH_N)) u_mk_table_ask (
    //
      .head_pop                    (mk_ask_head_pop              )
    //
    , .head_push                   (mk_ask_head_push             )
    , .head_push_tbl               (mk_ask_head_push_tbl         )
    //
    , .head_upt                    (mk_ask_head_upt              )
    , .head_upt_tbl                (mk_ask_head_upt_tbl          )
    //
    , .head_vld_r                  (mk_ask_head_vld_r            )
    , .head_did_update_r           (mk_ask_head_did_update_r     )
    , .head_r                      (mk_ask_head_r                )
    //
    , .insert                      (mk_ask_insert                )
    , .insert_tbl                  (mk_ask_insert_tbl            )
    //
    , .cancel                      (mk_ask_cancel                )
    , .cancel_uid                  (mk_ask_cancel_uid            )
    , .cancel_hit_w                (mk_ask_cancel_hit_w          )
    , .cancel_hit_tbl_w            (mk_ask_cancel_hit_tbl_w      )
    //
    , .full_w                      (mk_ask_full_w                )
    , .empty_w                     (mk_ask_empty_w               )
    //
    , .qry_vld                     (mk_ask_qry_vld               )
    , .qry_rsp_vld_r               (mk_ask_qry_rsp_vld_r         )
    , .qry_rsp_qty_r               (mk_ask_qry_rsp_qty_r         )
    //
    , .clk                         (clk                          )
    , .rst                         (rst                          )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_cn_table #(.N(cfg_pkg::CN_DEPTH_N)) u_ob_cn_table (
    //
      .cmd_vld                     (cn_cmd_vld                   )
    , .cmd_r                       (cn_cmd_r                     )
    //
    , .mtr_accept                  (cn_mtr_accept                )
    , .mtr_vld_r                   (cn_mtr_vld_r                 )
    , .mtr_r                       (cn_mtr_r                     )
    //
    , .cntrl_evt_texe_r            (cntrl_evt_texe_r             )
    //
    , .lm_bid_table_vld_r          (lm_bid_table_vld_r           )
    , .lm_bid_table_r              (lm_bid_table_r               )
    //
    , .lm_ask_table_vld_r          (lm_ask_table_vld_r           )
    , .lm_ask_table_r              (lm_ask_table_r               )
    //
    , .cancel_hit_w                (cn_cancel_hit_w              )
    , .cancel                      (cn_cancel                    )
    , .cancel_uid                  (cn_cancel_uid                )
    //
    , .full_r                      (cn_full_r                    )
    //
    , .clk                         (clk                          )
    , .rst                         (rst                          )
  );

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : out_PROC

    rsp_vld          = (~egress_queue_empty_r);
    rsp              = egress_queue_pop_data;

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
