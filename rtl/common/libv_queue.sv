// ==================================================================== //
// Copyright (c) 2017, Stephen Henry
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

`include "macros_pkg.vh"

module libv_queue #(
     parameter integer W = 32
   , parameter integer N = 16
) (

   //======================================================================== //
   //                                                                         //
   // Misc.                                                                   //
   //                                                                         //
   //======================================================================== //

     input                                   clk
   , input                                   rst

   //======================================================================== //
   //                                                                         //
   // Push Interface                                                          //
   //                                                                         //
   //======================================================================== //

   , input                                   push
   , input [W-1:0]                           push_data

   //======================================================================== //
   //                                                                         //
   // Pop Interface                                                           //
   //                                                                         //
   //======================================================================== //

   , input                                   pop

   , output logic [W-1:0]                    pop_data

   //======================================================================== //
   //                                                                         //
   // Control/Status Interface                                                //
   //                                                                         //
   //======================================================================== //

   , input                                   flush
   , input                                   commit
   , input                                   replay
   //
   , output logic                            empty_w
   , output logic                            full_w
);

  // ======================================================================== //
  //                                                                          //
  // Wires                                                                    //
  //                                                                          //
  // ======================================================================== //

  //
  typedef struct packed {
    logic                 w;
    logic [$clog2(N)-1:0] a;
  } addr_t;

  typedef logic [W-1:0]   w_t;

  //
  logic [N - 1:0][W - 1:0]              mem_r;

  // ======================================================================== //
  //                                                                          //
  // Combinatorial Logic                                                      //
  //                                                                          //
  // ======================================================================== //

  // ------------------------------------------------------------------------ //
  //
  `LIBV_REG_RST_R(logic, empty, 'b1);
  `LIBV_REG_RST_R(logic, full, 'b0);
  `LIBV_REG_EN_RST(addr_t, rd_ptr_arch, '0);
  `LIBV_REG_EN_RST(addr_t, rd_ptr_spec, '0);
  `LIBV_REG_EN_RST(addr_t, wr_ptr, '0);

  always_comb
    begin :  fifo_cntrl_PROC

      // Architectural read pointer update
      //
      casez ({flush, commit})
        2'b1_?:  rd_ptr_arch_w  = '0;
        2'b0_1:  rd_ptr_arch_w  = rd_ptr_arch_r + 'b1;
        default: rd_ptr_arch_w  = rd_ptr_arch_r;
      endcase

      rd_ptr_arch_en  = (flush | commit);

      // Speculative read pointer update
      //
      casez ({flush, replay, pop})
        3'b1??:  rd_ptr_spec_w  = '0;
        3'b01?:  rd_ptr_spec_w  = rd_ptr_arch_r;
        3'b001:  rd_ptr_spec_w  = rd_ptr_spec_r + 'b1;
        default: rd_ptr_spec_w  = rd_ptr_spec_r;
      endcase

      // Pop enable
      //
      rd_ptr_spec_en  = (flush | replay | pop);

      // Write pointer update
      //
      casez ({flush, push})
        2'b1_?:  wr_ptr_w  = '0;
        2'b0_1:  wr_ptr_w  = wr_ptr_r + 'b1;
        default: wr_ptr_w  = wr_ptr_r;
      endcase

      // Push enable
      //
      wr_ptr_en  = (flush | push);

      // Empty when pointers match
      //
      empty_w    = (rd_ptr_spec_w == wr_ptr_w);

      // Full when pointers alias but do not match.
      //
      full_w     = (rd_ptr_arch_w.w ^ wr_ptr_w.w) &
                   (rd_ptr_arch_w.a == wr_ptr_w.a);

    end // block: fifo_cntrl_PROC

  // ------------------------------------------------------------------------ //
  //
  always_comb begin : pop_data_PROC

    pop_data  = mem_r [rd_ptr_spec_r.a];

  end // block: pop_data_PROC
  
  // ======================================================================== //
  //                                                                          //
  // Flops                                                                    //
  //                                                                          //
  // ======================================================================== //
  
  // ------------------------------------------------------------------------ //
  //
  always_ff @(posedge clk)
    if (push)
      mem_r [wr_ptr_r.a] <= push_data;

endmodule // libv_queue
