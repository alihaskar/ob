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

module ob_table_cnt_csa #(

  // Width of each word in bits
    parameter int W = 32

  // Number of words to sum.
  , parameter int N = 8

  // Compression function to perform.
  , parameter ob_pkg::csa_op_t op = ob_pkg::CSA_3_2
) (

  // ======================================================================== //
  // CSA inputs
    input [N - 1:0][W - 1:0]                      x

  // ======================================================================== //
  // Next partial accumulation
  , output logic [W - 1:0]                        s_w
  , output logic [W - 1:0]                        c_w
);

  // Word type
  typedef logic [W - 1:0]               w_t;

  w_t [N - 1:0]                         s;

  // ------------------------------------------------------------------------ //
  //
  generate if (op == ob_pkg::CSA_3_2) begin

    function automatic logic [1:0] csa_3_to_2(logic a, logic b, logic c); begin
      csa_3_to_2 [0] = (a ^ b ^ c);
      csa_3_to_2 [1] = a & b | c  & (a | b);
    end endfunction

    function w_t [1:0] csa_3_to_2_v(w_t a, w_t b, w_t c); begin
      csa_3_to_2_v = '0;
      for (int i = 0 ; i < $bits(w_t); i++) begin
        { csa_3_to_2_v [1][i + 1], csa_3_to_2_v [0][i] } =
           csa_3_to_2(a[i], b[i], c[i]);
      end
    end endfunction

    always_comb begin : csa_PROC
      // Locals:
      int j = N;

      // Initial round:
      s     = x;

      while (j > 2) begin
        int i, last;

        last = j;
        j    = 0;
        for (i = 0; i < last; i += 3) begin
          w_t a = ((i + 0) < N) ? s [i + 0] : '0;
          w_t b = ((i + 1) < N) ? s [i + 1] : '0;
          w_t c = ((i + 2) < N) ? s [i + 2] : '0;

          { s[j + 1], s[j + 0] } = csa_3_to_2_v(a, b, c);

          j += 2;
        end
      end

      // Outputs are the final, unreduced, results.
      s_w     = s[0];
      c_w     = s[1];

    end // block: csa_PROC

  end endgenerate // if (op == ob_pkg::CSA_3_2)

endmodule // ob_table_cnt_csa
