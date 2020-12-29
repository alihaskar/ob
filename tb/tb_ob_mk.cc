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

const std::size_t LONG_N = (1 << 16);

TEST(TbObMk, RejectBuy) {
  tb::Options opts;
  tb::TB tb{opts};

  tb::Command cmd;

  vluint32_t uid = 0;

  // Populate market table; expect some number of rejections as the
  // table becomes full.
  for (int i = 0; i < 1024; i++) {
    cmd.valid = true;
    cmd.opcode = tb::Opcode::BuyMarket;
    cmd.uid = uid++;
    const tb::Bcd bcd = tb::Bcd::from_string("200.00");
    cmd.quantity = 100;
    cmd.price = bcd.pack();
    tb.push_back(cmd);
  }

  // Cancel items that we expect to be in the table.
  for (int i = 0; i < tb::MARKET_BID_DEPTH_N; i++) {
    cmd.valid = true;
    cmd.opcode = tb::Opcode::Cancel;
    cmd.uid = uid++;
    cmd.uid1 = i;
    tb.push_back(cmd);
  }

  // Run simulation
  tb.run();
}

TEST(TbObMk, RejectSell) {
  tb::Options opts;
  tb::TB tb{opts};
  tb::Command cmd;

  vluint32_t uid = 0;

  for (int i = 0; i < 1024; i++) {
    cmd.valid = true;
    cmd.opcode = tb::Opcode::SellMarket;
    cmd.uid = uid++;
    const tb::Bcd bcd = tb::Bcd::from_string("200.00");
    cmd.quantity = 100;
    cmd.price = bcd.pack();
    tb.push_back(cmd);
  }

  // Cancel items that we expect to be in the table.
  for (int i = 0; i < tb::MARKET_ASK_DEPTH_N; i++) {
    cmd.valid = true;
    cmd.opcode = tb::Opcode::Cancel;
    cmd.uid = uid++;
    cmd.uid1 = i;
    tb.push_back(cmd);
  }

  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesMkMk1) {
  tb::Options opts;
  tb::TB tb{opts};
  tb::Command cmd;

  vluint32_t uid = 0;

  const tb::Bcd bcd = tb::Bcd::from_string("200.00");

  // Issue market trade buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyMarket;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  for (int i = 0; i < 11; i++) {
    // Issue market trade sell
    cmd.valid = true;
    cmd.opcode = tb::Opcode::SellMarket;
    cmd.uid = uid++;
    cmd.quantity = 10;
    cmd.price = bcd.pack();
    tb.push_back(cmd);
  }

  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesMkMkN) {
  // Initialization randomisation seed.
  tb::Random::init(1);

  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::BuyMarket, 1);
  bg.push_back(tb::Opcode::SellMarket, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  tb::Options opts;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(LONG_N)) {
    tb.push_back(cmd);
  }
  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesMkLm1) {
  tb::Options opts;
  tb::TB tb{opts};
  tb::Command cmd;

  vluint32_t uid = 0;

  const tb::Bcd bcd = tb::Bcd::from_string("200.00");

  // Issue market trade buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyMarket;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Issue market trade sell
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  cmd.quantity = 10;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesMkLmN) {
  // Initialization randomisation seed.
  tb::Random::init(1);

  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::BuyMarket, 1);
  bg.push_back(tb::Opcode::SellLimit, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  tb::Options opts;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(LONG_N)) {
    tb.push_back(cmd);
  }
  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesLmMk1) {
  tb::Options opts;
  tb::TB tb{opts};
  tb::Command cmd;

  vluint32_t uid = 0;

  const tb::Bcd bcd = tb::Bcd::from_string("200.00");

  // Issue limit buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Issue market sell
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellMarket;
  cmd.uid = uid++;
  cmd.quantity = 10;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesLmMkN) {
  // Initialization randomisation seed.
  tb::Random::init(1);

  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::BuyLimit, 1);
  bg.push_back(tb::Opcode::SellMarket, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  tb::Options opts;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(LONG_N)) {
    tb.push_back(cmd);
  }
  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketBidCnt1) {
  tb::Options opts;
  tb::TB tb{opts};
  tb::Command cmd;

  vluint32_t uid = 0;

  const tb::Bcd bcd = tb::Bcd::from_string("200.00");

  // Issue limit buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyMarket;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Issue limit buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::BuyLimit;
  cmd.uid = uid++;
  cmd.quantity = 32;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Issue market sell
  cmd.valid = true;
  cmd.opcode = tb::Opcode::QryTblBidGe;
  cmd.uid = uid++;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketAskCnt1) {
  tb::Options opts;
  tb::TB tb{opts};
  tb::Command cmd;

  vluint32_t uid = 0;

  const tb::Bcd bcd = tb::Bcd::from_string("200.00");

  // Issue limit buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellMarket;
  cmd.uid = uid++;
  cmd.quantity = 100;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Issue limit buy
  cmd.valid = true;
  cmd.opcode = tb::Opcode::SellLimit;
  cmd.uid = uid++;
  cmd.quantity = 32;
  cmd.price = bcd.pack();
  tb.push_back(cmd);

  // Issue market sell
  cmd.valid = true;
  cmd.opcode = tb::Opcode::QryTblAskLe;
  cmd.uid = uid++;
  tb.push_back(cmd);

  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesMkMkNCnt) {
  // Initialization randomisation seed.
  tb::Random::init(1);

  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::BuyMarket, 1);
  bg.push_back(tb::Opcode::SellMarket, 1);
  bg.push_back(tb::Opcode::QryTblBidGe, 1);
  bg.push_back(tb::Opcode::QryTblAskLe, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  tb::Options opts;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(LONG_N)) {
    tb.push_back(cmd);
  }
  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesMkLmNCnt) {
  // Initialization randomisation seed.
  tb::Random::init(1);

  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::BuyMarket, 1);
  bg.push_back(tb::Opcode::SellLimit, 1);
  bg.push_back(tb::Opcode::QryTblBidGe, 1);
  bg.push_back(tb::Opcode::QryTblAskLe, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  tb::Options opts;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(LONG_N)) {
    tb.push_back(cmd);
  }
  // Run simulation
  tb.run();
}

TEST(TbObMk, MarketMarketTradesLmMkNCnt) {
  // Initialization randomisation seed.
  tb::Random::init(1);

  tb::Bag<vluint8_t> bg;
  bg.push_back(tb::Opcode::BuyLimit, 1);
  bg.push_back(tb::Opcode::SellMarket, 1);
  bg.push_back(tb::Opcode::QryTblBidGe, 1);
  bg.push_back(tb::Opcode::QryTblAskLe, 1);
  tb::StimulusGenerator gen(bg, 100.0, 10.0);

  tb::Options opts;
  tb::TB tb{opts};
  for (const tb::Command& cmd : gen.generate(LONG_N)) {
    tb.push_back(cmd);
  }
  // Run simulation
  tb.run();
}

int main (int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
