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
`include "bcd_pkg.vh"
`include "macros_pkg.vh"

module ob_mk_table #(parameter int N = 16) (

  // ======================================================================== //
  // Head Status
    input                                         head_pop
  , input                                         head_push
  , input ob_pkg::table_t                         head_push_tbl
  //
  , input                                         head_upt
  , input ob_pkg::table_t                         head_upt_tbl

  , output logic                                  head_vld_r
  , output logic                                  head_did_update_r
  , output ob_pkg::table_t                        head_r

  // ======================================================================== //
  // Control Interface
  , input                                         insert
  , input ob_pkg::table_t                         insert_tbl

  // ======================================================================== //
  // Cancel UID Interface
  , input                                         cancel
  , input ob_pkg::uid_t                           cancel_uid
  //
  , output logic                                  cancel_hit_w
  , output ob_pkg::table_t                        cancel_hit_tbl_w

  // ======================================================================== //
  // Status
  , output logic                                  full_w
  , output logic                                  empty_w

  // ======================================================================== //
  // Query Interface
  , input                                         qry_vld
  //
  , output logic                                  qry_rsp_vld_r
  , output ob_pkg::accum_quantity_t               qry_rsp_qty_r

  // ======================================================================== //
  // Clk/Reset
  , input                                         clk
  , input                                         rst
);

  // ======================================================================== //
  //                                                                          //
  // Helper functions                                                         //
  //                                                                          //
  // ======================================================================== //

  function automatic logic [N - 1:0] pri(logic [N - 1:0] x, bit lsb = 'b0); begin
    pri = '0;
    if (lsb) begin
      for (int i = 0; i < N; i++) begin
        if (x[i])
          pri  = ('b1 << i);
      end
    end else begin
      for (int i = N - 1; i >= 0; i--) begin
        if (x[i])
          pri  = ('b1 << i);
      end
    end
  end endfunction

  // Mux helper
  function automatic ob_pkg::table_t mux(
    logic [N - 1:0] sel, ob_pkg::table_t [N - 1:0] tbl); begin
    mux   = '0;
    for (int i = 0; i < N; i++)
      if (sel[i])
        mux |= tbl [i];
  end endfunction

  function automatic logic [N - 1:0] mask(
    logic [N - 1:0] x, bit inclusive = 'b1, bit lsb = 'b0); begin
    mask = 'b0;
    if (lsb) begin
      // Towards LSB; MSB -> LSB
      logic mask_enable  = 'b0;
      for (int i = N - 1; i >= 0; i--) begin
        if (i == N - 1)
          mask[i]  = (inclusive & x[i]);
        else
          mask[i]  = (inclusive & x[i]) | mask_enable;

        mask_enable |= x[i];
      end
    end else begin
      // Towards MSB; MSB <- LSB
      logic mask_enable  = 'b0;
      for (int i = 0; i < N; i++) begin
        if (i == 0)
          mask[i]  = (inclusive & x[i]);
        else
          mask[i]  = (inclusive & x[i]) | mask_enable;

        mask_enable |= x[i];
      end
    end
  end endfunction // mask

  // ======================================================================== //
  //                                                                          //
  // Table state                                                              //
  //                                                                          //
  // ======================================================================== //

  ob_pkg::table_t [N - 1:0]             tbl_r;
  ob_pkg::table_t [N - 1:0]             tbl_w;
  logic [N:0]                           tbl_en;
  `LIBV_REG_RST(logic [N - 1:0], tbl_vld, '0);

  // ------------------------------------------------------------------------ //
  //
  logic [N - 1:0]                       tbl_shift_dn;
  logic [N - 1:0]                       tbl_shift_up;
  logic [N - 1:0]                       tbl_ld;
  logic [N - 1:0]                       tbl_set_head;
  `LIBV_REG_RST_R(logic, full, 'b0);
  `LIBV_REG_RST_W(logic, head_did_update, '0);

  always_comb begin : tbl_update_PROC

    case ({head_pop, cancel_hit_w}) inside
      2'b1?:
        // Pop head, shift everything up one slot.
        tbl_shift_up = '1;
      2'b01:
        // On cancel hit, shift everything up from the cancel hit and
        // afterwards up (remove the cancelled item from the table).
        tbl_shift_up = mask(cancel_hit, .inclusive('b1), .lsb('b1));
      default:
        // Otherwise, do nothing.
        tbl_shift_up = '0;
    endcase // case ({head_pop, cancel_hit_w})

    // Shift down whenever an item is pushed to the head of the table.
    tbl_shift_dn = head_push ? '1 : '0;

    // Table load; when not full, load the first invalid slot relative
    // to the LSB; effectively pushing a new entry to the tail of the
    // table.
    tbl_ld       = full_r ? '0 : pri((~tbl_vld_r), .lsb('b1));

    // Update head value.
    tbl_set_head = head_upt ? ('b1  << (N - 1)) : '0;

    for (int i = 0; i < N; i++) begin

      case ({// Shift slot down
             tbl_shift_dn [i],
             // Shift slot up
             tbl_shift_up [i],
             // Load current slot
             tbl_ld [i],
             // Set head entry (set only for the head slot)
             tbl_set_head [i]}) inside
        4'b1???: begin
          // Table MSB -> LSB (pushing item to head)
          tbl_vld_w [i] = (i == (N - 1)) ? head_push : tbl_vld_r [i + 1];
          tbl_w [i]     = (i == (N - 1)) ? head_push_tbl : tbl_r [i + 1];
        end
        4'b01??: begin
          // Table LSB -> MSB (popping item from head)
          tbl_vld_w [i] = (i == 0) ? 'b0 : tbl_vld_r [i - 1];
          tbl_w [i]     = (i == 0) ?  '0 : tbl_r [i - 1];
        end
        4'b001?: begin
          // Table, append item to end.
          tbl_vld_w [i] = insert;
          tbl_w [i]     = insert_tbl;
        end
        4'b0001: begin
          tbl_vld_w [i] = 'b1;
          tbl_w [i]     = head_upt_tbl;
        end
        default: begin
          tbl_vld_w [i] = tbl_vld_r [i];
          tbl_w [i]     = tbl_r [i];
        end
      endcase // case ({head_pop, head_push, insert})

    end // for (int i = 0; i < N - 1; i++)

    // Table enables
    for (int i = 0; i < N; i++) begin
      // Enable slot on update.
      tbl_en [i] =
        (tbl_shift_dn [i] | tbl_shift_up [i] | tbl_ld [i] | tbl_set_head [i]);
    end

    // Flag denoting that the head entry was modified in the prior cycle.
    head_did_update_w = tbl_en [N - 1];

    // Table becomes full when all slots are becoming occupied.
    full_w            = (tbl_vld_w == '1);

    // Table becomes empty when all slots are unoccupied.
    empty_w           = (tbl_vld_w == '0);

    // Table head value is valid.
    head_vld_r        = tbl_vld_r [N - 1];

    // Emit head value.
    head_r            = tbl_r [N - 1];

  end // block: tbl_update_PROC

  // ------------------------------------------------------------------------ //
  //
  logic [N - 1:0]                       cancel_hit;

  always_comb begin : cancel_PROC

    // For a cancel operation, associatively search the current table for a
    // matching UID and notify on a hit. Additionally, deduct the quantity
    // retainde by the cancelled command from the overall quantity.
    //
    for (int i = 0; i < N; i++) begin
      cancel_hit [i] = cancel & tbl_vld_r [i] & (tbl_r [i].uid == cancel_uid);
    end

    // Cancel hit occurs on a match.
    cancel_hit_w     = (cancel_hit != '0);

    // Mux out hitting match.
    cancel_hit_tbl_w = mux(cancel_hit, tbl_r);

  end // block: cancel_PROC

  // ------------------------------------------------------------------------ //
  //
  logic                                 cnt_cmd_vld;
  ob_pkg::accum_quantity_t              cnt_rsp_quantity_w;
  `LIBV_REG_RST(logic, cnt_busy, 'b0);
  `LIBV_REG_RST_W(logic, qry_rsp_vld, 'b0);
  `LIBV_REG_EN_W(ob_pkg::accum_quantity_t, qry_rsp_qty);

  always_comb begin : qry_PROC

    // Issue count search operation.
    cnt_cmd_vld = qry_vld;

    // Simple set/reset code. Clear flop on incoming query and set
    // on the transition out of the busy state.
    case ({qry_vld, cnt_busy_r, cnt_busy_w}) inside
      3'b1_??: qry_rsp_vld_w = 'b0;
      3'b0_10: qry_rsp_vld_w = 'b1;
      default: qry_rsp_vld_w = qry_rsp_vld_r;
    endcase // case ({qry_vld, cnt_busy_r, cnt_busy_w})

    // Latch count on transition to valid state.
    qry_rsp_qty_en = cnt_busy_r & (~cnt_busy_w);
    qry_rsp_qty_w  = cnt_rsp_quantity_w;

  end // block: quantity_PROC

  // ======================================================================== //
  //                                                                          //
  // Flops                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk) begin : t_FLOP
    for (int i = 0; i < N + 1; i++)
	    if (tbl_en [i])
	      tbl_r [i] <= tbl_w [i];
  end // block: t_FLOP

  // ======================================================================== //
  //                                                                          //
  // Instances                                                                //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  ob_mk_table_cnt #(.N(N)) u_ob_mk_table_cnt (
    //
      .cmd_vld                (cnt_cmd_vld             )
    , .rsp_quantity_w         (cnt_rsp_quantity_w      )
    //
    , .tbl_r                  (tbl_r                   )
    , .tbl_vld_r              (tbl_vld_r               )
    //
    , .busy_w                 (cnt_busy_w              )
    //
    , .clk                    (clk                     )
    , .rst                    (rst                     )
  );

endmodule // ob_mk_table
