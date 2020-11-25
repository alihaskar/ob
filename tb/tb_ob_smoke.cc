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

TEST(Smoke, SimpleTableSort) {
  tb::Options opts;

  tb::TB tb{opts};

  tb::Command cmd;
  tb::Bcd bcd;

  // Cmd 0:
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = 0;
  bcd = tb::Bcd::from_string("100.55");
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Cmd 1:
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = 1;
  bcd = tb::Bcd::from_string("100.60");
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Cmd 2:
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = 2;
  bcd = tb::Bcd::from_string("100.40");
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);


  // Cmd 3: Remove top bid
  cmd.valid = true;
  cmd.opcode = tb::Opcode::PopTopBid;
  cmd.uid = 3;
  tb.push_back(cmd);

  // Cmd 4: Remove top bid
  cmd.valid = true;
  cmd.opcode = tb::Opcode::PopTopBid;
  cmd.uid = 4;
  tb.push_back(cmd);

  // Cmd 5: Remove top bid
  cmd.valid = true;
  cmd.opcode = tb::Opcode::PopTopBid;
  cmd.uid = 5;
  tb.push_back(cmd);

  // Run simulation.
  tb.run();
}

TEST(Smoke, SimpleTrade) {
  tb::Options opts;
  tb::TB tb{opts};

  tb::Command cmd;
  tb::Bcd bcd;

  // Cmd 0: Buy 100 shares at $200.00
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = 0;
  bcd = tb::Bcd::from_string("200.00");
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Cmd 2: Sell 100 shares at $100.00
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = 1;
  bcd = tb::Bcd::from_string("100.00");
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Run simulation.
  tb.run();
}

TEST(Smoke, Cancel) {
  tb::Options opts;
  tb::TB tb{opts};

  tb::Command cmd;

  // Cmd 0: issue Buy for 100 at $200.00
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = 0x20;
  const tb::Bcd bcd = tb::Bcd::from_string("200.00");
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Cmd 1: issue cancel for Buy command.
  cmd.valid = true;
  cmd.opcode = tb::Opcode::Cancel;
  cmd.uid = 0x30;
  cmd.uid1 = 0x20;
  tb.push_back(cmd);

  // Cmd 2: issue cancel for Buy command.
  cmd.valid = true;
  cmd.opcode = tb::Opcode::Cancel;
  cmd.uid = 0x31;
  cmd.uid1 = 0x20;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

int main(int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
