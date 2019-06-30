// Generated by CoffeeScript 2.3.2
(function() {
  var KRO_ADDR, MiniMeToken, managers_to_onboard;

  MiniMeToken = artifacts.require("MiniMeToken");

  managers_to_onboard = require("./migrate-managers.json");

  KRO_ADDR = "0xE5fEf62fEFc4555560088B389E5f4Df2D45df4b1";

  module.exports = async function(callback) {
    var Kairo, e, i, j, len, manager;
    Kairo = (await MiniMeToken.at(KRO_ADDR));
    i = 1;
    for (j = 0, len = managers_to_onboard.length; j < len; j++) {
      manager = managers_to_onboard[j];
      console.log(manager.address + ` onboarding... ${i}/${managers_to_onboard.length}`);
      i += 1;
      try {
        await Kairo.generateTokens(manager.address, manager.kro);
      } catch (error) {
        e = error;
        console.log(e.toString());
      }
    }
    callback();
  };

}).call(this);
