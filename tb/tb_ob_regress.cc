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

#include "gtest/gtest.h"
#include "tb.h"

TEST(Regress, Basic) {
  // Initialize random seed for reproducibility.
  tb::Random::init(1);

  // Generate stimulus.
  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::Nop, 1);
  bg.push_back(tb::Opcode::QryBidAsk, 1);
  bg.push_back(tb::Opcode::Buy, 10);
  bg.push_back(tb::Opcode::Sell, 10);
  bg.push_back(tb::Opcode::PopTopBid, 1);
  bg.push_back(tb::Opcode::PopTopAsk, 1);
  bg.push_back(tb::Opcode::Cancel, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  // Construct testbench environment.
  tb::Options opts;
  opts.wave_enable = true;
  opts.trace_enable = true;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(115)) {
    tb.push_back(cmd);
  }

  // Run simulation.
  tb.run();
}

int main(int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
