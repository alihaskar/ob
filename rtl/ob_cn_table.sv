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
    input                                         cmd_vld_r
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
  // Status Interface
  , output logic                                  full_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ------------------------------------------------------------------------ //
  //
  logic [N - 1:0]                       entry_busy_w;
  logic [N - 1:0]                       entry_mtr_vld_w;
  ob_pkg::cmd_t [N - 1:0]               entry_cmd_r;
  ob_pkg::cmd_t                         entry_cmd_sel;

  for (genvar g = 0; g < N; g++) begin

    ob_cn_table_entry u_ob_cn_table_entry (
      //
        .al_vld                    ()
      , .al_cmd_r                  (cmd_r                   )
      //
      , .dl_vld                    ()
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
      , .clk                       (clk                     )
      , .rst                       (rst                     )
    );

  end

  // ------------------------------------------------------------------------ //
  //
  logic [N - 1:0]                       rr_req;
  logic                                 rr_ack;
  logic [N - 1:0]                       rr_gnt;

  always_comb begin : rr_PROC

    // From set of matured entries:
    rr_req = entry_mtr_vld_w;

    // Advance arbiter state when currently nominated entry advances.
    rr_ack = mtr_vld_r & mtr_accept;

  end // block: rr_PROC

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
  `LIBV_REG_RST_W(logic, full, 'b0);
  `LIBV_REG_EN_RST_W(logic, mtr_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::cmd_t, mtr);

  always_comb begin : cntrl_PROC

    // All slots/entries in the conditional table are occupied.
    full_w     = (entry_busy_w == '1);

    // Maturity becomes full whenever one of the subordinate threads indicate
    // that they have matured.
    mtr_vld_w  = (entry_mtr_vld_w != '0);

    // Retention circuit for maturity validity. Sample validity for the machines
    // otherwise retain current validity until accepted.
    mtr_vld_en = (~mtr_vld_r) | mtr_accept;

    // Latch new matured command on new valid.
    mtr_en     = mtr_vld_en;

    // Latch nominated command from matured engine.
    mtr_w      = entry_cmd_sel;

  end // block: cntrl_PROC

  // ------------------------------------------------------------------------ //
  //
  libv_mux #(.N(N), .W($bits(ob_pkg::cmd_t))) u_libv_mux (
    //
      .in                     (entry_cmd_r             )
    , .sel                    (rr_gnt                  )
    //
    , .out                    (entry_cmd_sel           )
  );

endmodule // ob_cn_table
