var Test = require("../config/testConfig.js");
var BigNumber = require("bignumber.js");

contract("Flight Surety Tests", async (accounts) => {
  var config;
  const TIMESTAMP = Math.floor(Date.now() / 1000);

  let FLIGHT = {
    airline: accounts[2],
    flight: "ND1309",
    from: "SPS",
    to: "TGU",
    timestamp: TIMESTAMP,
  };

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
      newAirline,
      { from: config.flightSuretyApp.address }
    );

    let operational = await config.flightSuretyData.getAirlineOperational.call(
      newAirline,
      { from: config.flightSuretyApp.address }
    );

    // ASSERT
    assert.equal(registered, true, "Airline is registered");
    assert.equal(
      operational,
      false,
      "Airline should not be operational if doesnt have founds"
    );
  });

  it("(airline) add Funds to Airline", async () => {
    try {
      await config.flightSuretyApp.addFunds({ from: accounts[0], value: 1 });
    } catch (e) {
      console.log(e);
    }
    let funds = await config.flightSuretyData.getAirlineFunds.call(
      accounts[0],
      { from: config.flightSuretyApp.address }
    );

    // ASSERT
    assert.equal(funds, 1, "Airline should have just 1 funds");
  });

  it("(airline) Set as operational an Airline when them have more than 10 ether in founds", async () => {
    try {
      await config.flightSuretyApp.addFunds({ from: accounts[0], value: 9 });
    } catch (e) {
      console.log(e);
    }
    let operational = await config.flightSuretyData.getAirlineOperational.call(
      accounts[0],
      { from: config.flightSuretyApp.address }
    );

    // ASSERT
    assert.equal(operational, true, "Airline should be operational");
  });

  it("(airline) When there is more than 4 Airline put new airline on vote", async () => {
    let newAirline3 = accounts[2];
    let newAirline4 = accounts[3];
    let newAirline5 = accounts[4];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline3, {
        from: config.firstAirline,
      });

      await config.flightSuretyApp.addFunds({
        from: newAirline3,
        value: web3.utils.toWei("10"),
      });

      let operationalAirline3 =
        await config.flightSuretyData.getAirlineOperational.call(newAirline3, {
          from: config.flightSuretyApp.address,
        });

      let fundsAirline3 = await config.flightSuretyData.getAirlineFunds.call(
        newAirline3,
        { from: config.flightSuretyApp.address }
      );

      assert.equal(operationalAirline3, true, "Airline should be operational");
      assert.equal(fundsAirline3, web3.utils.toWei("10"), "Error in funds");

      await config.flightSuretyApp.registerAirline(newAirline4, {
        from: config.firstAirline,
      });

      await config.flightSuretyApp.addFunds({
        from: newAirline4,
        value: web3.utils.toWei("10"),
      });

      let operationalAirline4 =
        await config.flightSuretyData.getAirlineOperational.call(newAirline4, {
          from: config.flightSuretyApp.address,
        });

      assert.equal(operationalAirline4, true, "Airline should be operational");

      await config.flightSuretyApp.registerAirline(newAirline5, {
        from: config.firstAirline,
      });
    } catch (e) {
      console.log(e);
    }
    let length = await config.flightSuretyData.getAirlinesLength({
      from: config.firstAirline,
    });
    // Assert
    assert.equal(length, 4, "There is an error on airline length");

    // Vote for New Airline5
    await config.flightSuretyApp.registerAirline(newAirline5, {
      from: newAirline3,
    });
    let newlength = await config.flightSuretyData.getAirlinesLength({
      from: config.firstAirline,
    });

    // Assert
    assert.equal(newlength, 5, "There is an error on airline length");
  });

  it("(airline) Airline 2 can add a Flight", async () => {
    try {
      await config.flightSuretyApp.registerFlight(
        FLIGHT.flight,
        FLIGHT.from,
        FLIGHT.to,
        FLIGHT.timestamp,
        { from: FLIGHT.airline }
      );
    } catch (e) {}
    let isValidFlight = await config.flightSuretyData.isValidFlight.call(
      FLIGHT.flight,
      FLIGHT.airline,
      FLIGHT.timestamp,
      { from: config.flightSuretyApp.address }
    );

    // ASSERT
    assert.equal(isValidFlight, true, "Flight isn't valid");
  });

  it("(passenger) can buy flight inssurance for at most 1 ether", async () => {
    // ARRANGE
    let passenger6 = accounts[6];
    let InsuredPrice = web3.utils.toWei("1", "ether");

    try {
      await config.flightSuretyApp.buy(
        FLIGHT.flight,
        FLIGHT.airline,
        FLIGHT.timestamp,
        {
          from: passenger6,
          value: InsuredPrice,
        }
      );
    } catch (e) {}

    let result = await config.flightSuretyData.isOnPassengerOnFlight.call(
      FLIGHT.airline,
      FLIGHT.flight,
      FLIGHT.timestamp,
      passenger6
    );

    // ASSERT
    assert.equal(result, true, "Status is not true");
  });

  it("(passenger) Insured passenger can be credited if flight is delayed", async () => {
    // ARRANGE
    let passenger = accounts[6];
    let credit_status = true;
    let balance = 1.5;
    let credit_before = 0;
    let credit_after = 1.5;
    let STATUS_CODE_LATE_AIRLINE = 20;

    try {
      // Check credit before passenger was credited
      credit_before =
        await config.flightSuretyData.getPassengerInsuranceCredit.call(
          passenger
        );
      credit_before = web3.utils.fromWei(credit_before, "ether");
      // console.log(credit_before);

      // Credit the passenger
      await config.flightSuretyApp.processFlightStatus(
        FLIGHT.airline,
        FLIGHT.flight,
        FLIGHT.timestamp,
        STATUS_CODE_LATE_AIRLINE
      );

      // Get credit after passenger has been credited
      credit_after =
        await config.flightSuretyData.getPassengerInsuranceCredit.call(
          passenger
        );
      credit_after = web3.utils.fromWei(credit_after, "ether");
    } catch (e) {
      console.log(e);
      credit_status = false;
    }

    // ASSERT
    assert.equal(balance, credit_after, "Credited balance  not as expected");
    assert.equal(credit_status, true, "Passenger was not credited");
  });

  it("(passenger) Credited passenger can withdraw ether(transfer from airline to passenger)", async () => {
    // ARRANGE
    let passenger = accounts[6];
    let withdraw = true;
    let balance_before = 0;
    let balance_after = 0;
    let eth_balance_before = 0;
    let eth_balance_after = 0;
    let credit = 1.5;

    try {
      balance_before =
        await config.flightSuretyData.getPassengerInsuranceCredit.call(
          passenger
        );
      balance_before = web3.utils.fromWei(balance_before, "ether");

      eth_balance_before = await web3.eth.getBalance(passenger);
      eth_balance_before = web3.utils.fromWei(eth_balance_before, "ether");
      console.log("ETH balance before: ", eth_balance_before);

      await config.flightSuretyApp.withdraw({ from: passenger });

      // Check if credit has been redrawn
      balance_after =
      await config.flightSuretyData.getPassengerInsuranceCredit.call(
        passenger
      );
      balance_after = web3.utils.fromWei(balance_after, "ether");

      eth_balance_after = await web3.eth.getBalance(passenger);
      eth_balance_after = web3.utils.fromWei(eth_balance_after, "ether");
      console.log("ETH balance after: ", eth_balance_after);

      console.log("The difference is ", eth_balance_after - eth_balance_before);
    } catch (e) {
      withdraw = false;
    }

    // ASSERT
    assert.equal(withdraw, true, "Passenger could not withdraw");
    assert.equal(balance_before, credit, "Redrawn credit doesn't match");
    assert.equal(balance_after, 0, "Credit was't redrawn");
    assert.ok(
      eth_balance_after - eth_balance_before > 0,
      "Credited was not transfered to wallet"
    );
  });
});
