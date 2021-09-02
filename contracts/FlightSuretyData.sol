// SPDX-License-Identifier: MIT
pragma solidity >0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    struct airlineStruct {
        bool isRegistered;
        bool isOperational;
        uint256 funds;
    }
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    struct Passenger {
        address wallet;
        mapping(string => uint256) boughtFlight;
        uint256 insuranceCredit;
    }

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    uint256 private airLinesCount = 0; // counter of airlines
    address private authorizeCallerAddress; // set the account authorized to call this contract

    mapping(bytes32 => Flight) private flights; // set the list of flights
    mapping(address => airlineStruct) airlines; //set the list of airlines
    mapping(address => address[]) votesRegistration; // set the list of votes for the address
    mapping(address => Passenger) private passengers; // set list of passengers

    // Flight status codeesregisterAirline
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event RegisterAirline(address account);
    event FoundingAirline(address account, uint256 value);
    event FlightRegistered(bytes32 flightKey, address airline);
    event FlightInsuranceBought(address account, bytes32 flightKey);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireCallerAuthorized() {
        require(
            msg.sender == authorizeCallerAddress,
            "Caller is not authorized"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function setVoteAirline(address airline) requireCallerAuthorized {
        votesRegistration[airline].push(msg.sender);
    }

    function getAirlineRegistered(address airline)
        view
        requireCallerAuthorized
        returns (bool)
    {
        return (airlines[airline].isRegistered);
    }

    function getAirlineOperational(address airline)
        view
        requireCallerAuthorized
        returns (bool)
    {
        return (airlines[airline].isOperational);
    }

    function getAirlineFunds(address airline)
        view
        requireCallerAuthorized
        returns (uint256)
    {
        return (airlines[airline].funds);
    }

    function authorizeCaller(address caller) {
        authorizeCallerAddress = caller;
    }

    function getAirlineVotes(address airline)
        view
        requireCallerAuthorized
        returns (uint256)
    {
        return votesRegistration[airline].length;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address airline, bool isAirlineOperational)
        external
    {
        // Register the airline as Registered, but is Operational unitl they submit 10 ether
        airlines[airline] = airlineStruct({
            isRegistered: true,
            isOperational: isAirlineOperational,
            funds: 0
        });
        airLinesCount = airLinesCount + 1;
        emit RegisterAirline(airline);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(address passenger, string flightCode, uint256 value)
        external
        payable
        requireCallerAuthorized
    {
        passengers[passenger] = Passenger({
            passengerWallet: passenger,
            credit: 0
        });
        passengers[passenger].boughtFlight[flightCode] = value;

        emit FlightBought(passenger, flightCode);
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund(address airline, uint256 amount) public {
        airlines[airline].funds = airlines[airline].funds + amount;
        if (airlines[airline].funds >= 10 ether) {
            airlines[airline].isOperational = true;
        }
        emit FoundingAirline(airline, amount);
    }

    function createFlight(string memory flight) public {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getAirlinesLength() returns (uint256) {
        return airLinesCount;
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string destination,
        string flight,
        address airline
    ) external {
        bytes32 key = getFlightKey(airline, flight, now);
        require(!flights[key].isRegistered, "Flight is already registered.");
        require(
            getAirlineOperational(airline) == true,
            "Airline isn't operational."
        );

        flights[key] = Flight({
            isRegistered: true,
            flightCode: flight,
            destination: destination,
            statusCode: STATUS_CODE_UNKNOWN,
            updatedTimestamp: timestamp,
            airline: airline
        });
        emit FlightRegistered(key, airline);
    }

    function getFlights() external {
        return flights;
    }
    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    // function() external payable {
    //     fund();
    // }
}
