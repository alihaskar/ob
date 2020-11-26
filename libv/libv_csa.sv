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

`include "libv_pkg.vh"

`define OPT_DEBUG

module libv_csa #(

  // Width of each word in bits
    parameter int W = 32

  // Number of words to sum.
  , parameter int N = 8

  // Compression function to perform.
  , parameter libv_pkg::csa_op_t op = libv_pkg::CSA_3_2
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

  function automatic logic [1:0] fa(logic a, logic b, logic c); begin
    fa[0] = a ^ b ^ c;
    fa[1] = (a & b) | (c  & (a | b));
  end endfunction

  // ------------------------------------------------------------------------ //
  //
  generate if (op == libv_pkg::CSA_3_2) begin

    // 3:2 CSA reduction network

    // Procedurally generate a CSA reduction tree using 3:2 operators.

    function w_t [1:0] csa_3_2(w_t [2:0] in); begin
      csa_3_2 = '0;
      for (int i = 0 ; i < $bits(w_t); i++) begin
        logic co, sum;
        { co, sum } =  fa(in[2][i], in[1][i], in[0][i]);
        csa_3_2 [0][i] = sum;
        if (i < W - 1)
          csa_3_2 [1][i + 1] = co;
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
          int remain_n = (last - i);

          case (remain_n)
            1: begin
              // Round with only 1 entry; forgo the CSA operation
              // and simply reduce input into output.
              s[j + 0] = s[i + 0];

              j        += 1;
            end
            default: begin
              // Round with 3 entries; perform 3:2 reduction.
              w_t a                  = ((i + 0) < last) ? s[i + 0] : '0;
              w_t b                  = ((i + 1) < last) ? s[i + 1] : '0;
              w_t c                  = ((i + 2) < last) ? s[i + 2] : '0;

              { s[j + 1], s[j + 0] } = csa_3_2({a, b, c});

              j                      += 2;
            end
          endcase // case (remain_n)
        end
      end

      // Outputs are the final, unreduced, results.
      s_w     = s[0];
      c_w     = s[1];

    end // block: csa_PROC

  end else if (op == libv_pkg::CSA_7_2) begin // if (op == libv_pkg::CSA_3_2)

    // 7:2 CSA reduction network

    function automatic logic [6:0] reduce_7_2(logic [6:0] w, logic [4:0] c); begin
      logic [4:0][1:0] cs;

      reduce_7_2 = '0;

      // 7:2 reduction network as defined in "Digital Arithmetic" by Ercegovac,
      // pg. 147.
      cs [0]     = fa(w[2], w[1], w[0]);
      cs [1]     = fa(w[5], w[4], w[3]);
      cs [2]     = fa(w[6], cs[1][0], cs[0][0]);
      cs [3]     = fa(cs[2][0], c[1], c[0]);
      cs [4]     = fa(cs[3][0], c[3], c[2]);

      reduce_7_2 = {
                    // Carry-outs:
                    cs[4][1], cs[3][1], cs[2][1], cs[0][1], cs[1][1],
                    // Reduced Carry/Save
                    cs[4][0], c[4]
                    };
    end endfunction

    function automatic w_t [1:0] csa_7_2(w_t [6:0] in); begin
      logic [4:0] cin = '0;
      for (int i = 0; i < $bits(w_t); i++) begin
        logic [4:0] cout;
        logic [6:0] w;

        w = { in [6][i], in [5][i], in [4][i], in [3][i], in [2][i],
              in [1][i], in [0][i] };
        { cout, csa_7_2 [1][i], csa_7_2 [0][i] } = reduce_7_2(w, cin);
        cin = cout;
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
        for (i = 0; i < last; i += 7) begin
          int remain_n = (last - i - 1);

          case (remain_n)
            1: begin
              // Round with only 1 entry; forgo the CSA operation
              // and simply reduce input into output.
              s[j] = s[i];

              j    += 1;
            end
            default: begin
              // Perform 7:2 reduction.
              w_t a                  = ((i + 0) < last) ? s [i + 0] : '0;
              w_t b                  = ((i + 1) < last) ? s [i + 1] : '0;
              w_t c                  = ((i + 2) < last) ? s [i + 2] : '0;
              w_t d                  = ((i + 3) < last) ? s [i + 3] : '0;
              w_t e                  = ((i + 4) < last) ? s [i + 4] : '0;
              w_t f                  = ((i + 5) < last) ? s [i + 5] : '0;
              w_t g                  = ((i + 6) < last) ? s [i + 6] : '0;

              { s[j + 1], s[j + 0] } = csa_7_2({a, b, c, d, e, f, g});

              j                      += 2;
            end
          endcase // case (remain_n)
        end
      end

      // Outputs are the final, unreduced, results.
      s_w     = s[0];
      c_w     = s[1];

    end // block: csa_PROC

  end else begin // if (op == libc_pkg::CSA_7_2)

    // Use infered CSA chain

    always_comb begin : csa_PROC

      c_w = '0;

      s_w = '0;
      for (int i = 0; i < N; i++)
        s_w += x[i];

    end // block: csa_PROC

  end endgenerate // else: !if(op == libc_pkg::CSA_7_2)

endmodule // libv_csa
