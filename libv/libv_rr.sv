// ==================================================================== //
// Copyright (c) 2020, Stephen Henry
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in
//   the documentation and/or other materials provided with the
//   distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
// OF THE POSSIBILITY OF SUCH DAMAGE.
// ==================================================================== //

`default_nettype none
`timescale 1ns/1ps

`include "libv_pkg.vh"

module libv_rr #(parameter int W = 32) (

   //======================================================================== //
   //                                                                         //
   // Misc.                                                                   //
   //                                                                         //
   //======================================================================== //

   //
     input                              clk
   , input                              rst

   //======================================================================== //
   //                                                                         //
   // Control                                                                 //
   //                                                                         //
   //======================================================================== //

   , input        [W-1:0]               req
   , input                              ack
   , output logic [W-1:0]               gnt
   , output logic [$clog2(W)-1:0]       gnt_enc
);

  // ======================================================================== //
  //                                                                          //
  // Combinatorial Logic                                                      //
  //                                                                          //
  // ======================================================================== //

  //
  function automatic logic [W - 1:0] rll (logic [W - 1:0] w); begin
    return { w [W - 2:0], w [W - 1] };
  end endfunction

  //
  function automatic logic [W - 1:0] mask_left_inclusive(
      logic [W - 1:0] w); begin
    mask_left_inclusive  = '0;
    for (int i = 0; i < W; i++) begin
      if  (w [i])
        mask_left_inclusive [i]  = 'b1;

      if (i > 0)
        mask_left_inclusive [i]   |= mask_left_inclusive [i - 1];
    end
  end endfunction

  //
  function automatic logic [W - 1:0] ffs(logic [W - 1:0] w); begin
    ffs = 0;
    for (int i = W - 1; i >= 0; i--)
      if (w [i])
        ffs  = ('b1 << i);
  end endfunction

  //
  function automatic logic [$clog2(W)-1:0] encode(logic [W-1:0] in); begin
    encode      = '0;
    for (int i = W - 1; i >= 0; i--)
      if (in [i])
        encode  = i[$clog2(W)-1:0];
  end endfunction

  // ------------------------------------------------------------------------ //
  //
  logic [W - 1:0]                       rr_mask;
  logic [W - 1:0]                       rr_lsel;
  logic [W - 1:0]                       rr_rsel;
  logic [W - 1:0]                       rr_gsel;
  logic                                 rr_gnt_set;

  always_comb begin : rr_PROC

    rr_mask     = mask_left_inclusive(idx_r);

    rr_lsel     = req &   rr_mask;
    rr_rsel     = req & (~rr_mask);

    //
    rr_gsel     = (|rr_lsel) ? rr_lsel : rr_rsel;

    //
    gnt         = ffs(rr_gsel);
    gnt_enc     = encode(gnt);
    rr_gnt_set  = (gnt != '0);

    // Really shouldn't tie ack high even when there is no REQ as this
    // can push the arbiter into an invalid state.
`define ACK_ON_NGRANT

    idx_en    = ack;
`ifdef ACK_ON_NGRANT
    idx_w     = rr_gnt_set ? rll(gnt) : idx_r;
`else
    idx_w     = rll(gnt);
`endif

  end // block: rr_PROC

  `LIBV_REG_EN_RST(logic [W - 1:0], idx, 'b1);

endmodule // libv_rr
