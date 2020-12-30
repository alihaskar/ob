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

TEST(TbObCn, ConditionalCancel) {
  tb::Options opts;
  tb::TB tb{opts};

  tb::Command cmd;
  vluint32_t uid = 0;
  const tb::Bcd bcd = tb::Bcd::from_string("200.00");
  const vluint32_t price = bcd.pack();

  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyStopLoss;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = price;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellStopLoss;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = price;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyStopLimit;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = price;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellStopLimit;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = price;
  tb.push_back(cmd);

  // Issue cancels:
  for (int i = 0; i < 4; i++) {
    cmd.opcode = tb::Opcode::Cancel;
    cmd.uid = uid++;
    cmd.uid1 = i;
    tb.push_back(cmd);
  }

  // Run simulation
  tb.run();
}

TEST(TbObCn, ConditionalReject) {
  tb::Options opts;
  tb::TB tb{opts};

  tb::Command cmd;
  vluint32_t uid = 0;
  const tb::Bcd bcd = tb::Bcd::from_string("200.00");
  const vluint32_t price = bcd.pack();

  // Pass many commands to CN which are never executed and expect a bunch of
  // rejections from the controller.
  for (int i = 0; i < 100; i++) {
    cmd.valid = true;
    cmd.opcode = tb::Opcode::BuyStopLoss;
    cmd.uid = uid++;
    cmd.quantity = 100;
    cmd.price = price;
    tb.push_back(cmd);
  }

  // Run simulation
  tb.run();
}
TEST(TbObCn, ConditionalBuyStopLoss1) {
  tb::Options opts;
  tb::TB tb{opts};

  vluint32_t uid = 0;

  tb::Command cmd;
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyStopLoss;
  cmd.uid = uid++;
  cmd.quantity = 100;
  // The price at which to mature once the 'ask' has reached this value.
  cmd.price = tb::Bcd::from_string("100.00").pack();
  // The price at which to buy once matured.
  cmd.price1 = tb::Bcd::from_string("90.00").pack();
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  // Buying at 95.
  cmd.price = tb::Bcd::from_string("95.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  // Selling for 85.
  cmd.price = tb::Bcd::from_string("85.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // UID = 0 should now mature into a market buy for: 100 @ $100.00

  // Issue limit order to set market rate.
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  // Now, selling at 99, which should now take place as the CN
  // is buying at 100.
  cmd.price = tb::Bcd::from_string("99.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // Insert NOP to flush final trades (required by the testbench).
  cmd.valid = true;
  cmd.opcode = tb::Opcode::Nop;
  cmd.uid = uid++;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObCn, ConditionalSellStopLoss1) {
  tb::Options opts;
  tb::TB tb{opts};

  vluint32_t uid = 0;

  tb::Command cmd;
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellStopLoss;
  cmd.uid = uid++;
  cmd.quantity = 100;
  // The price at which to mature once the 'ask' has reached this value.
  cmd.price = tb::Bcd::from_string("100.00").pack();
  // The price at which to buy once matured.
  cmd.price1 = tb::Bcd::from_string("90.00").pack();
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  // Buying at 95.
  cmd.price = tb::Bcd::from_string("95.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  // Selling for 85.
  cmd.price = tb::Bcd::from_string("85.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // UID = 0 should now mature into a market buy for: 100 @ $100.00

  // Issue limit order to set market rate.
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  // Now, selling at 99, which should now take place as the CN
  // is buying at 100.
  cmd.price = tb::Bcd::from_string("99.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // Insert NOP to flush final trades (required by the testbench).
  cmd.valid = true;
  cmd.opcode = tb::Opcode::Nop;
  cmd.uid = uid++;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObCn, ConditionalBuyStopLimit1) {
  tb::Options opts;
  tb::TB tb{opts};

  vluint32_t uid = 0;

  tb::Command cmd;
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyStopLimit;
  cmd.uid = uid++;
  cmd.quantity = 100;
  // The price at which to mature once the 'ask' has reached this value.
  cmd.price = tb::Bcd::from_string("100.00").pack();
  // The price at which to buy once matured.
  cmd.price1 = tb::Bcd::from_string("90.00").pack();
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  // Buying at 95.
  cmd.price = tb::Bcd::from_string("95.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  // Selling for 85.
  cmd.price = tb::Bcd::from_string("85.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // UID = 0 should now mature into a market buy for: 100 @ $100.00

  // Issue limit order to set market rate.
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  // Now, selling at 99, which should now take place as the CN
  // is buying at 100.
  cmd.price = tb::Bcd::from_string("99.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // Insert NOP to flush final trades (required by the testbench).
  cmd.valid = true;
  cmd.opcode = tb::Opcode::Nop;
  cmd.uid = uid++;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObCn, ConditionalSellStopLimit1) {
  tb::Options opts;
  tb::TB tb{opts};

  vluint32_t uid = 0;

  tb::Command cmd;
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellStopLimit;
  cmd.uid = uid++;
  cmd.quantity = 100;
  // The price at which to mature once the 'ask' has reached this value.
  cmd.price = tb::Bcd::from_string("100.00").pack();
  // The price at which to buy once matured.
  cmd.price1 = tb::Bcd::from_string("90.00").pack();
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  // Buying at 95.
  cmd.price = tb::Bcd::from_string("95.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  // Selling for 85.
  cmd.price = tb::Bcd::from_string("85.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // UID = 0 should now mature into a market buy for: 100 @ $100.00

  // Issue limit order to set market rate.
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  // Now, selling at 99, which should now take place as the CN
  // is buying at 100.
  cmd.price = tb::Bcd::from_string("99.00").pack();
  cmd.quantity = 100;
  tb.push_back(cmd);

  // Insert NOP to flush final trades (required by the testbench).
  cmd.valid = true;
  cmd.opcode = tb::Opcode::Nop;
  cmd.uid = uid++;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

int main (int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
