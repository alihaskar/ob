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

TEST(Qry, BidBasic) {
  tb::Options opts;
  opts.trace_enable = true;
  opts.wave_enable = true;
  tb::TB tb{opts};

  // Issue Buy for: 100 @ $100.00
  tb::Command cmd;
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.quantity = 100;
  cmd.price = tb::Bcd::from_string("100.00").pack();
  tb.push_back(cmd);

  // Issue Buy for: 23 @ $110.23
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.quantity = 23;
  cmd.price = tb::Bcd::from_string("110.23").pack();
  tb.push_back(cmd);

  // Issue Qry for $99.99 -> Expect: 0
  cmd.valid = true;
  cmd.opcode = tb::Opcode::QryTblBidGe;
  cmd.price = tb::Bcd::from_string("99.99").pack();
  cmd.quantity = 0;
  tb.push_back(cmd);

  // Issue Qry for $100.00 -> Expect: 100
  cmd.valid = true;
  cmd.opcode = tb::Opcode::QryTblBidGe;
  cmd.price = tb::Bcd::from_string("100.00").pack();
  cmd.quantity = 0;
  tb.push_back(cmd);

  // Issue Qry for $100.01 -> Expect: 100
  cmd.valid = true;
  cmd.opcode = tb::Opcode::QryTblBidGe;
  cmd.price = tb::Bcd::from_string("100.01").pack();
  cmd.quantity = 0;
  tb.push_back(cmd);

  // Issue Qry for $120.00 -> Expect: 123
  cmd.valid = true;
  cmd.opcode = tb::Opcode::QryTblBidGe;
  cmd.price = tb::Bcd::from_string("120.00").pack();
  cmd.quantity = 0;
  tb.push_back(cmd);

  tb.run();
}

/*
TEST(Qry, Bid) {
  tb::Options opts;
  tb::TB tb{opts};

  tb.run();
}
*/

int main(int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
