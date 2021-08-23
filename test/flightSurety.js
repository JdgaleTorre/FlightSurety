var Test = require("../config/testConfig.js");
var BigNumber = require("bignumber.js");

contract("Flight Surety Tests", async (accounts) => {
  var config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(
      config.flightSuretyApp.address
    );
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: config.testAddresses[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(
      accessDenied,
      false,
      "Access not restricted to Contract Owner"
    );
  });

  // TODO: This test doesnt work
  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try {
      await config.flightSurety.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);
  });

  it("(airline) can register an Airline using registerAirline() is registered but not operational", async () => {
    // ARRANGE
    let newAirline = accounts[1];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline,
      });
    } catch (e) {
      console.log(e);
    }
    let registered = await config.flightSuretyData.getAirlineRegistered.call(
      newAirline, {from: config.flightSuretyApp.address}
    );

    let operational = await config.flightSuretyData.getAirlineOperational.call(
      newAirline, {from: config.flightSuretyApp.address}
    );

    // ASSERT
    assert.equal(registered, true, "Airline is registered");
    assert.equal(operational, false, "Airline should not be operational if doesnt have founds");
  });

  it("(airline) add Founds to Airline", async () => {

    try {
      await config.flightSuretyApp.addFunds({from: accounts[0], value: 1});
    } catch (e) {
      console.log(e);
    }
    let funds = await config.flightSuretyData.getAirlineFunds.call(
      accounts[0], {from: config.flightSuretyApp.address}
    );

    // ASSERT
    assert.equal(funds, 1, "Airline should have just 1 funds");
  });

  it("(airline) Set as operational an Airline when them have more than 10 ether in founds", async () => {

    try {
      await config.flightSuretyApp.addFunds({from: accounts[0], value: 9});
    } catch (e) {
      console.log(e);
    }
    let operational = await config.flightSuretyData.getAirlineOperational.call(
      accounts[0], {from: config.flightSuretyApp.address}
    );

    // ASSERT
    assert.equal(operational, true, "Airline should be operational");
  });
});
