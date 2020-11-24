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

module ob_table_cnt #(parameter int N = 16, parameter bit is_ask = 'b1) (

  // ======================================================================== //
  // Command interface

    input                                         cmd_vld
  , input bcd_pkg::price_t                        cmd_price
  //
  , output ob_pkg::accum_quantity_t               rsp_quantity_w

  // ======================================================================== //
  // Table state
  , input ob_pkg::table_t [N:0]                   tbl_r
  , input logic [N:0]                             tbl_vld_r

  // ======================================================================== //
  // Status
  , output logic                                  busy_w

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst

);

  // ======================================================================== //
  //                                                                          //
  // Parameterizations                                                        //
  //                                                                          //
  // ======================================================================== //

  localparam int CSA_DEGREE_N = 8; // Constant

  // ======================================================================== //
  //                                                                          //
  // Wires                                                                    //
  //                                                                          //
  // ======================================================================== //

  typedef struct packed {
    // FSM is busy
    logic                busy;
    //
    logic [3:0]          st;
  } fsm_state_t;

  typedef enum fsm_state_t { FSM_IDLE = 5'b0_00000
                             } fsm_state_enc_t;

  `LIBV_REG_EN_RST(fsm_state_t, fsm_state, FSM_IDLE);


  localparam int MUX_IN_N = libv_pkg::ceil(N, CSA_DEGREE_N - 2);
  typedef struct packed {
    logic                vld;
    ob_pkg::table_t      tbl;
  } table_sel_t;

  table_sel_t
    [MUX_IN_N - 1:0][CSA_DEGREE_N - 1:2]          mux_in_tbl_sel;
  ob_pkg::accum_quantity_t
    [MUX_IN_N - 1:0][CSA_DEGREE_N - 1:2]          mux_in;
  logic [CSA_DEGREE_N - 1:2]                      mux_all_vld;
  ob_pkg::accum_quantity_t [CSA_DEGREE_N - 1:2]   mux_out;


  // CSA partially accumulated results.
  ob_pkg::accum_quantity_t [CSA_DEGREE_N - 1:0]   csa_x;
  ob_pkg::accum_quantity_t                        csa_s_w;
  ob_pkg::accum_quantity_t                        csa_c_w;

  `LIBV_REG_EN(ob_pkg::accum_quantity_t, acc_s);
  `LIBV_REG_EN(ob_pkg::accum_quantity_t, acc_c);

  // ======================================================================== //
  //                                                                          //
  // Logic                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : fsm_PROC

    // Defaults:

    // FSM:
    fsm_state_en = 'b0;
    fsm_state_w  = fsm_state_r;

    // Accumulation flops

    // Sum:
    acc_s_w      = csa_s_w;
    acc_s_en     = 'b0;

    // Carry:
    acc_c_w      = csa_c_w;
    acc_c_en     = 'b0;

    case (fsm_state_r)

      FSM_IDLE: begin

        // Zero accumulated state

        // Sum:
        acc_s_w  = '0;
        acc_s_en = 'b1;

        // Carry:
        acc_c_w  = '0;
        acc_c_en = 'b1;
      end

      default: begin
      end

    endcase // case (fsm_state_t)

  end

  // ------------------------------------------------------------------------ //
  //
  function automatic logic price_compare(
    bcd_pkg::price_t c, bcd_pkg::price_t t); begin
    if (is_ask) begin
      // Ask: if the command (Buy) price is greater than or equal to the current
      // asking price, the transaction can take place.
      return (c >= t);
    end else begin
      // Put: if the command (Sell) price is lesser than or equal to the current
      // market price, the transaction can take place.
      return (c <= t);
    end
  end endfunction

  always_comb begin : mux_PROC
    int tbl_idx = 0;

    mux_in_tbl_sel  = '0;

    for (int in_idx = 0; in_idx < MUX_IN_N; in_idx++) begin

      for (int mux_id = 0; mux_id < CSA_DEGREE_N - 2; mux_id++) begin

        if (tbl_idx < N) begin
          // Pipe table input approprate location in mux
          mux_in_tbl_sel [mux_id][in_idx] =
            '{vld: tbl_vld_r [tbl_idx], tbl: tbl_r [tbl_idx]};

          // Advance index.
          tbl_idx++;
        end
        // Otherwise, mux-input is driven zero.

      end // for (int mux_id = 0; mux_id < CSA_DEGREE_N - 2; mux_id++)

    end // for (int in_idx = 0; in_idx < MUX_IN_N; in_idx++)

    for (int mux_id = 0; mux_id < CSA_DEGREE_N - 2; mux_id++) begin

      mux_all_vld [mux_id] = 'b1;

      for (int in_idx = 0; in_idx < MUX_IN_N; in_idx++) begin
        logic tbl_entry_vld       = mux_in_tbl_sel [mux_id][in_idx].vld;
        ob_pkg::table_t tbl_entry = mux_in_tbl_sel [mux_id][in_idx].tbl;

        casez ({ // Entry is valid
                 tbl_entry_vld,
                 // Price compares valid for the current Put/Ask operation.
                 price_compare(cmd_price, tbl_entry.price)
                })
          2'b1_1: begin
            // Current table entry can be considered in the count.
            mux_in [mux_id][in_idx] = ob_pkg::accum_quantity_t'(
              tbl_entry.quantity);
          end
          default: begin
            // Otherwise, invalid and not considered in the current round.
            mux_all_vld [mux_id]    = 'b0;
            mux_in [mux_id][in_idx] = '0;
          end
        endcase

      end

    end // for (int mux_id = 0; mux_id < CSA_DEGREE_N - 2; mux_id++)

  end // block: mux_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : csa_PROC

    // Inject prior accumulated result
    csa_x [0]  = acc_s_r;
    csa_x [1]  = acc_c_r;

    // Inject entries from table.
    for (int i = 2; i < CSA_DEGREE_N; i++) begin
      csa_x [i] = mux_out [i];
    end

  end // block: csa_PROC

  // ------------------------------------------------------------------------ //
  // Form final accumulated sum.
  always_comb rsp_quantity_w = csa_s_w + csa_c_w;

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  libv_mux #(.W($bits(ob_pkg::accum_quantity_t)),
             .N(MUX_IN_N)) u_mux [CSA_DEGREE_N - 1:2] (
    //
      .in                     (mux_in              )
    , .sel                    ()
    //
    , .out                    (mux_out             )
  );

  // ------------------------------------------------------------------------ //
  //
  ob_table_cnt_csa #(.W($bits(ob_pkg::accum_quantity_t)),
                     .N(CSA_DEGREE_N), .op(ob_pkg::CSA_3_2)) u_ob_table_cnt_csa (
    //
      .x                     (csa_x                 )
    //
    , .s_w                   (csa_s_w               )
    , .c_w                   (csa_c_w               )
  );

endmodule // ob_table_cnt
