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
`include "libv_pkg.vh"

module ob_cn_table #(parameter int N = 4) (

  // ======================================================================== //
  // Issue interface
    input                                         cmd_vld
  , input ob_pkg::cmd_t                           cmd_r

  // ======================================================================== //
  // Maturity interface
  , input                                         mtr_accept
  //
  , output                                        mtr_vld_r
  , output ob_pkg::cmd_t                          mtr_r

  // ======================================================================== //
  // Machine state
  //
  , input                                         cntrl_evt_texe_r
  //
  , input                                         lm_bid_table_vld_r
  , input ob_pkg::table_t                         lm_bid_table_r
  //
  , input                                         lm_ask_table_vld_r
  , input ob_pkg::table_t                         lm_ask_table_r

  // ======================================================================== //
  // Canel Interface
  , input                                         cancel
  , input ob_pkg::uid_t                           cancel_uid
  //
  , output logic                                  cancel_hit_w

  // ======================================================================== //
  // Status Interface
  , output logic                                  full_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  logic [N - 1:0]                       rr_req;
  logic                                 rr_ack;
  logic [N - 1:0]                       rr_gnt;
  logic [N - 1:0]                       cancel_hit_d;
  logic [N - 1:0]                       al_vld;
  logic [N - 1:0]                       dl_vld;
  `LIBV_REG_RST(logic [N - 1:0], entry_busy, 'b0);
  `LIBV_REG_RST(logic [N - 1:0], entry_mtr_vld, 'b0);
  ob_pkg::cmd_t [N - 1:0]               entry_cmd_r;
  ob_pkg::cmd_t                         entry_cmd_sel;
  `LIBV_REG_RST_W(logic, full, 'b0);
  `LIBV_REG_RST_W(logic, mtr_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::cmd_t, mtr);
  logic                                 cntrl_has_matured;

  for (genvar g = 0; g < N; g++) begin

    ob_cn_table_entry u_ob_cn_table_entry (
      //
        .al_vld                    (al_vld [g]              )
      , .al_cmd_r                  (cmd_r                   )
      //
      , .dl_vld                    (dl_vld [g]              )
      //
      , .busy_w                    (entry_busy_w [g]        )
      , .mtr_vld_w                 (entry_mtr_vld_w [g]     )
      //
      , .cmd_r                     (entry_cmd_r [g]         )
      //
      , .cntrl_evt_texe_r          (cntrl_evt_texe_r        )
      , .lm_bid_table_vld_r        (lm_bid_table_vld_r      )
      , .lm_bid_table_r            (lm_bid_table_r          )
      , .lm_ask_table_vld_r        (lm_ask_table_vld_r      )
      , .lm_ask_table_r            (lm_ask_table_r          )
      //
      , .cancel                    (cancel                  )
      , .cancel_uid                (cancel_uid              )
      , .cancel_hit                (cancel_hit_d [g]        )
      //
      , .clk                       (clk                     )
      , .rst                       (rst                     )
    );

  end

  // ------------------------------------------------------------------------ //
  //
  libv_rr #(.W(N)) u_libv_rr (
    //
      .req                    (rr_req                  )
    , .ack                    (rr_ack                  )
    , .gnt                    (rr_gnt                  )
    , .gnt_enc                ()
    //
    , .clk                    (clk                     )
    , .rst                    (rst                     )
  );

  // ------------------------------------------------------------------------ //
  //
  function automatic logic [N - 1:0] pri(logic [N - 1:0] x); begin
    pri        = '0;
    for (int i = 0; i < N; i++)
      if (x [i] == 'b1)
        pri = ('b1 << i);
  end endfunction

  function automatic ob_pkg::cmd_t mux(
    ob_pkg::cmd_t [N - 1:0] x, logic [N - 1:0] sel); begin
    mux        = '0;
    for (int i = 0; i < N; i++)
      if (sel [i])
        mux |= x [i];
  end endfunction

  always_comb begin : cntrl_PROC

    // Allocate to first non-busy entry.
    al_vld            = cmd_vld ? pri(~entry_busy_r) : '0;

    // Set on hit.
    cancel_hit_w       = cancel & (cancel_hit_d != '0);

    // All slots/entries in the conditional table are occupied.
    full_w            = (entry_busy_w == '1);

    // Matured engines are available.
    cntrl_has_matured = (entry_mtr_vld_r != '0);

    // From set of matured entries:
    rr_req            = entry_mtr_vld_r;

    // Advance arbiter state when currently nominated entry advances.
    rr_ack            = cntrl_has_matured & ((~mtr_vld_r) | mtr_accept);

    // Deallocate nominated matured entry on its transition to the 'mtr_' latch.
    dl_vld            = rr_ack ? rr_gnt : '0;

    // mtr vld set/reset.
    case ({rr_ack, mtr_accept}) inside
      2'b1_?:  mtr_vld_w = 'b1;
      2'b0_1:  mtr_vld_w = 'b0;
      default: mtr_vld_w = mtr_vld_r;
    endcase

    // Latch new matured command on new valid.
    mtr_en             = rr_ack;

    // Latch nominated command from matured engine.
    mtr_w              = mux(entry_cmd_r, rr_gnt);

  end // block: cntrl_PROC

endmodule // ob_cn_table
