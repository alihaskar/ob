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

module ob_mk_table #(parameter int N = 16, parameter bit is_ask = 'b1) (

  // ======================================================================== //
  // Head Status
    input                                         head_pop
  , input                                         head_push
  , input ob_pkg::table_t                         head_push_tbl

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
  , output ob_pkg::quantity_t                     quantity_r

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

  // is_ask == 'b0; Buy-Table; order entries such that greatest are at head.
  // is_ask == 'b1; Ask-Table; order entries such that smallest are at head.

  // Table ordered according to is_ask/!is_ask: Nth entry is the head
  // entry, the zeroth entry is the reject.
  ob_pkg::table_t [N - 1:0]             tbl_r;
  ob_pkg::table_t [N - 1:0]             tbl_w;
  logic [N:0]                           tbl_en;
  `LIBV_REG_RST(logic [N - 1:0], tbl_vld, '0);

  // ------------------------------------------------------------------------ //
  //
  logic [N - 1:0]                       tbl_shift_dn;
  logic [N - 1:0]                       tbl_shift_up;
  logic [N - 1:0]                       tbl_ld;
  `LIBV_REG_RST_R(logic, full, 'b0);

  always_comb begin : tbl_update_PROC

    case ({head_pop, cancel_hit_w}) inside
      2'b1?:
        // Pop head, shift everything up one slot.
        tbl_shift_up = '1;
      2'b01:
        // On cancel hit, shift everything up from the cancel hit and
        // afterwards up (remove the cancelled item from the table).
        tbl_shift_up = mask(cancel_hit, .inclusive('b1), .lsb('b0));
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

    for (int i = 0; i < N - 1; i++) begin

      case ({tbl_shift_dn [i], tbl_shift_up [i], tbl_ld [i]}) inside
        3'b1??: begin
          // Table MSB -> LSB (pushing item to head)
          tbl_vld_w [i] = (i == (N - 1)) ? head_push : tbl_vld_r [i + 1];
          tbl_w [i]     = (i == (N - 1)) ? head_push_tbl : tbl_r [i + 1];
        end
        3'b01?: begin
          // Table LSB -> MSB (popping item from head)
          tbl_vld_w [i] = (i == 0) ? 'b0 : tbl_vld_r [i - 1];
          tbl_w [i]     = (i == 0) ?  '0 : tbl_r [i - 1];
        end
        3'b001: begin
          // Table, append item to end.
          tbl_vld_w [i] = insert;
          tbl_w [i]     = insert_tbl;
        end
        default: begin
          tbl_w [i]     = tbl_r [i];
        end
      endcase // case ({head_pop, head_push, insert})

    end // for (int i = 0; i < N - 1; i++)

    // Table enables
    for (int i = 0; i < N; i++) begin
      // Enable slot on update.
      tbl_en [i] = (tbl_shift_dn [i] | tbl_shift_up [i] | tbl_ld [i]);
    end

    // Table becomes full when all slots are becoming occupied.
    full_w  = (tbl_vld_w == 'b1);

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
  `LIBV_REG_EN_RST_W(ob_pkg::quantity_t, quantity, '0);

  always_comb begin : quantity_PROC

    // The interface definition does not disallow this but implicitly only
    // one modification to the table may occur during a given clock cycle.
    //
    priority case ({insert, head_push, head_pop, cancel_hit_w}) inside
      4'b1???: begin
        // On insert (to tail), increment the quantity.
        quantity_w = quantity_r + insert_tbl.quantity;
      end
      4'b01??: begin
        // On a push (to head), increment the quantity in the head entry.
        quantity_w = quantity_r + head_push_tbl.quantity;
      end
      4'b001?: begin
        // On a pop, deduct the quantity from the head entry.
        quantity_w = quantity_r - head_r.quantity;
      end
      4'b0001: begin
        // On cancel hit, deduct the quantity retained by the table entry.
        quantity_w = quantity_r - cancel_hit_tbl_w.quantity;
      end
      default: begin
        quantity_w = quantity_r;
      end
    endcase // case ({insert, head_push, head_pop})

    // Enable on update.
    quantity_en = (insert | head_push | head_pop);

  end // block: quantity_PROC

  // ======================================================================== //
  //                                                                          //
  // Flops                                                                    //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk) begin : t_FLOP
    if (rst) begin
      for (int i = 0; i < N + 1; i++)
	      tbl_r [i] <= is_ask ? ob_pkg::TABLE_ASK_INIT : ob_pkg::TABLE_BID_INIT;
    end else begin
      for (int i = 0; i < N + 1; i++)
	      if (tbl_en [i])
	        tbl_r [i] <= tbl_w [i];
    end
  end // block: t_FLOP

endmodule // ob_mk_table
