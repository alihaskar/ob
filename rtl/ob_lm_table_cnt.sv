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
`include "macros_pkg.vh"

//`define OPT_EARLY_TERMINATION

module ob_lm_table_cnt #(parameter int N = 16, parameter bit is_ask = 'b1) (

  // ======================================================================== //
  // Command interface

    input                                         cmd_vld
  , input bcd_pkg::price_t                        cmd_price
  , input ob_pkg::quantity_t                      cmd_quantity
  //
  , output logic                                  rsp_attained_w
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

  typedef enum fsm_state_t { // FSM Idle state
                             FSM_IDLE  = 5'b0_0000,
                             // FSM Accumulating state.
                             FSM_ACCUM = 5'b1_0001,
                             // FSM Wait response 0.
                             FSM_WAIT0 = 5'b1_0010,
                             // FSM Wait response 1.
                             FSM_WAIT1 = 5'b1_0011
                             } fsm_state_enc_t;

  `LIBV_REG_EN_RST(fsm_state_t, fsm_state, FSM_IDLE);

  typedef struct packed {
    // Price for which to search.
    bcd_pkg::price_t price;
    // Quantity to find.
    ob_pkg::accum_quantity_t quantity;
  } fsm_context_t;

  `LIBV_REG_EN(fsm_context_t, fsm_context);

  // FSM Datapath wires:
  logic                                           fsm_mux_sel_init;
  logic                                           fsm_mux_sel_upt;
  logic                                           fsm_acc_init;
  logic                                           fsm_acc_upt;
  logic                                           fsm_mux_out_en;

  // The total number of multiplers required; two minus the CSA degree where the
  // 2 is derived from the two inputs because of the partial accumulated sums.
  localparam int MUX_N = CSA_DEGREE_N - 2;

  // For a fixed CSA_DEGREE_N (the number of inputs to the CSA tree), which
  // equals the total number of multiplexers requried plus 2 (for the accumulate
  // partial sums), compute the multiplexer degree.
  //
  localparam int MUX_IN_N = libv_pkg::ceil(N, MUX_N);

  // The number of accumulation rounds required to accumulate all values across
  // the entire table.
  //
  localparam int ACCUM_ROUNDS_N = MUX_IN_N;

  typedef struct packed {
    logic                vld;
    ob_pkg::table_t      tbl;
  } table_sel_t;

  table_sel_t [MUX_N - 1:0][MUX_IN_N - 1:0]       mux_in_tbl_sel;
  ob_pkg::quantity_t
    [MUX_N - 1:0][MUX_IN_N - 1:0]                 mux_in;
`ifdef OPT_EARLY_TERMINATION
  logic [MUX_N - 1:0][MUX_IN_N - 1:0]             mux_in_vld;
  logic                                           mux_in_all_vld;
`endif
  `LIBV_REG_EN(logic [MUX_IN_N - 1:0], mux_sel);
  logic                                           mux_sel_is_first;
  logic                                           mux_sel_is_last;
  ob_pkg::quantity_t [MUX_N - 1:0]                mux_out_w;
  ob_pkg::quantity_t [MUX_N - 1:0]                mux_out_r;
  logic                                           mux_out_en;

  // CSA partially accumulated results.
  ob_pkg::accum_quantity_t [CSA_DEGREE_N - 1:0]   csa_x;
  ob_pkg::accum_quantity_t                        csa_s;
  ob_pkg::accum_quantity_t                        csa_c;

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
    fsm_state_en     = 'b0;
    fsm_state_w      = fsm_state_r;

    // FSM (context):
    fsm_context_en   = 'b0;
    fsm_context_w    = fsm_context_r;

    // Accumulation flops
    fsm_acc_init     = 'b0;
    fsm_acc_upt      = 'b0;

    // Mux sel:
    fsm_mux_sel_init = 'b0;
    fsm_mux_sel_upt  = 'b0;

    // TBL -> MUX out latch enable
    fsm_mux_out_en   = 'b0;

    case (fsm_state_r)

      FSM_IDLE: begin

        if (cmd_vld) begin

          // Retain context
          fsm_context_en         = 'b1;
          fsm_context_w          = '0;
          fsm_context_w.price    = cmd_price;
          fsm_context_w.quantity = ob_pkg::accum_quantity_t'(cmd_quantity);

          // Zero accumulated state
          fsm_acc_init           = 'b1;

          // Initialize mux selection.
          fsm_mux_sel_init       = 'b1;

          // Transition to accumulating state.
          fsm_state_en           = 'b1;
          fsm_state_w            = FSM_ACCUM;
        end
      end // case: FSM_IDLE
      FSM_ACCUM: begin

        // Latch input to CSA.
        fsm_mux_out_en  = 'b1;

        // Advance mux selection
        fsm_mux_sel_upt = 'b1;

        // Update accumulator state. Do not update accumulator on the first mux
        // round (the first cycle in this state) as the mux_out_r is not yet
        // valid.
        fsm_acc_upt     = (~mux_sel_is_first);

        casez ({// This is the final round in the mux selection.
                  mux_sel_is_last
`ifdef OPT_EARLY_TERMINATION
                // The partially accumulated result already exceeds
                // the goal value as defined at the outset.
                , rsp_attained_w
`else
                // Otherwise, no dependency on this timing path.
                , 1'b0
`endif
`ifdef OPT_EARLY_TERMINATION
                // The accumulation is partial; that it's not all entries within
                // the CSA are value. By consequence of the strictly ordered
                // nature of the table, we know that no further entries can be
                // value and can now quit the search early.
                , mux_in_all_vld
`else
                // Otherwise, disable as this is a rather aggressive
                // timing-path.
                , 1'b0
`endif
                })
          3'b1??,
          3'b01?,
          3'b001: begin
            // Operation terminates, transition to wait state to
            // await the complexted accumulated result.
            fsm_state_en = 'b1;
            fsm_state_w  = FSM_WAIT0;
          end
          default: begin
            // Otherwise, continue accumulating.
          end
        endcase // casez ({...

      end

      FSM_WAIT0: begin
        // Accumulate the command issued in the preceeding cycle.
        fsm_acc_upt  = 'b1;

        // Transition to final (output) stage.
        fsm_state_en = 'b1;
        fsm_state_w  = FSM_WAIT1;
      end

      FSM_WAIT1: begin

        // rsp_* is now valid at this point, and with the tradition of busy_w
        // back to false, is now ready to be latched by the parent.
        fsm_state_en = 'b1;
        fsm_state_w  = FSM_IDLE;
      end

      default: begin
      end

    endcase // case (fsm_state_t)

    // Busy flag is MSB of state vector.
    busy_w = fsm_state_w.busy;

  end // block: fsm_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : fsm_dp_PROC

    // Update mux selection on initialization or update.
    mux_sel_en = (fsm_mux_sel_init | fsm_mux_sel_upt);

    casez ({fsm_mux_sel_init, fsm_mux_sel_upt})
      2'b1?:   mux_sel_w = 'b1;
      2'b01:   mux_sel_w = mux_sel_r << 1;
      default: mux_sel_w = mux_sel_r;
    endcase // casez ({fsm_mux_sel_init, fsm_mux_sel_upt})

    // Is first mux select round.
    mux_sel_is_first = mux_sel_r [0];

    // Is final mux select round.
    mux_sel_is_last  = mux_sel_r [MUX_IN_N - 1];

  end // block: fsm_dp_PROC

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

  always_comb begin : mux_in_PROC
    int tbl_idx = N;

    mux_in_tbl_sel  = '0;

    for (int in_idx = 0; in_idx < MUX_IN_N; in_idx++) begin

      for (int mux_id = 0; mux_id < MUX_N; mux_id++) begin

        if (tbl_idx >= 0) begin
          // Pipe table input approprate location in mux
          mux_in_tbl_sel [mux_id][in_idx] =
            '{vld: tbl_vld_r [tbl_idx], tbl: tbl_r [tbl_idx]};

          // Advance index.
          tbl_idx--;
        end
        // Otherwise, mux-input is driven zero.

      end // for (int mux_id = 0; mux_id < MUX_N; mux_id++)

    end // for (int in_idx = 0; in_idx < MUX_IN_N; in_idx++)

    for (int in_idx = 0; in_idx < MUX_IN_N; in_idx++) begin

      for (int mux_id = 0; mux_id < MUX_N; mux_id++) begin
        logic tbl_entry_vld         = mux_in_tbl_sel [mux_id][in_idx].vld;
        ob_pkg::table_t tbl_entry   = mux_in_tbl_sel [mux_id][in_idx].tbl;

`ifdef OPT_EARLY_TERMINATION
        mux_in_vld [in_idx][mux_id] = 'b0;
`endif

        casez ({ // Entry is valid
                 tbl_entry_vld,
                 // Price compares valid for the current Put/Ask operation.
                 price_compare(fsm_context_r.price, tbl_entry.price)
                })
          2'b1_1: begin
            // Current table entry can be considered in the count.
`ifdef OPT_EARLY_TERMINATION
            mux_in_vld [in_idx][mux_id] = 'b1;
`endif
            mux_in [mux_id][in_idx]      = tbl_entry.quantity;
          end
          default: begin
            // Otherwise, invalid and not considered in the current round.
            mux_in [mux_id][in_idx] = '0;
          end
        endcase

      end

    end // for (int mux_id = 0; mux_id < CSA_DEGREE_N - 2; mux_id++)

    // FSM enables latch at the output of the muxes and at the input to the CSA
    // chain.
    //
    mux_out_en = fsm_mux_out_en;
`ifdef OPT_EARLY_TERMINATION

    // Compute mux_out_all_vld, which is a flag which denotes if all the entires
    // into the CSA in the next cycle are valid. If false, this flag indicates
    // that the search operation can be quit.
    //
    mux_in_all_vld = 'b1;
    for (int mux_id = 0; mux_id < MUX_N; mux_id++) begin
      mux_in_all_vld &= ((mux_in_vld [mux_id] & mux_sel_r) != '0);
    end
`endif

  end // block: mux_in_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : csa_PROC

    // Inject entries from table.
    for (int i = 0; i < MUX_N; i++) begin
      csa_x [i] = ob_pkg::accum_quantity_t'(mux_out_r [i]);
    end

    // Inject prior accumulated result
    csa_x [CSA_DEGREE_N - 2] = acc_s_r;
    csa_x [CSA_DEGREE_N - 1] = acc_c_r;

    acc_s_en                 = (fsm_acc_init | fsm_acc_upt);
    acc_c_en                 = (fsm_acc_init | fsm_acc_upt);

    // Set to zero, or CSA output.
    acc_s_w                  = fsm_acc_init ? '0 : csa_s;
    acc_c_w                  = fsm_acc_init ? '0 : csa_c;

  end // block: csa_PROC

  // ------------------------------------------------------------------------ //
  // Form final accumulated sum.
  always_comb begin : rsp_PROC

    // Compute final CLA.
    rsp_quantity_w = acc_s_r + acc_c_r;

    // Flag indicating whether the targeted quantity has been attained.
    rsp_attained_w = (rsp_quantity_w >= fsm_context_r.quantity);

  end // block: rsp_PROC

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  generate for (genvar g = 0; g < MUX_N; g++) begin

    libv_mux #(.W($bits(ob_pkg::quantity_t)), .N(MUX_IN_N)) u_table_mux (
      //
        .in                     (mux_in [g]          )
      , .sel                    (mux_sel_r           )
      //
      , .out                    (mux_out_w [g]       )
    );

  end endgenerate

  // ------------------------------------------------------------------------ //
  //
  ob_lm_table_cnt_csa #(.W($bits(ob_pkg::accum_quantity_t)),
                     .N(CSA_DEGREE_N), .op(ob_pkg::CSA_3_2)) u_ob_table_cnt_csa (
    //
      .x                     (csa_x                 )
    //
    , .s_w                   (csa_s                 )
    , .c_w                   (csa_c                 )
  );

  // ======================================================================== //
  //                                                                          //
  // Flops                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk) begin
    if (mux_out_en)
      mux_out_r <= mux_out_w;
  end

endmodule // ob_table_cnt
