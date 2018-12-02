// Generated by CoffeeScript 2.3.2
(function() {
  var BETOKEN_ADDR, Betoken, BetokenFund, managers_to_onboard;

  BetokenFund = artifacts.require("BetokenFund");

  managers_to_onboard = require("./managers_to_onboard.json");

  BETOKEN_ADDR = "0x5910d5abd4d5fd58b39957664cd9735cbfe42bf0";

  Betoken = BetokenFund.at(BETOKEN_ADDR);

  module.exports = async function(callback) {
    var i, j, len, manager;
    i = 1;
    for (j = 0, len = managers_to_onboard.length; j < len; j++) {
      manager = managers_to_onboard[j];
      console.log(manager.address + ` onboarding... ${i}/${managers_to_onboard.length}`);
      i += 1;
      await Betoken.airdropKairo([manager.address], manager.kro);
    }
  };

}).call(this);
