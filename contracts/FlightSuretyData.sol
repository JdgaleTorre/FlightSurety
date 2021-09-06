// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.8;

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

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

    struct Passenger {
        address wallet;
        uint256 insuranceCredit;
        uint256 amount;
        bool isCredited;
    }

    struct Flight {
        bool isRegistered;
        string from;
        string destination;
        string flightCode;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        uint256 multiplier;
        address[] passengersList;
    }

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    uint256 private airLinesCount = 0; // counter of airlines
    address private authorizeCallerAddress; // set the account authorized to call this contract

    mapping(bytes32 => Flight) private flights; // set the list of flights
    mapping(address => airlineStruct) airlines; //set the list of airlines
    mapping(address => address[]) votesRegistration; // set the list of votes for the address
    mapping(address => Passenger) private passengers; // set list of passengers
    // mapping(address => Passenger[]) passengersInsurance;

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
    event FundingAirline(address account, uint256 value);
    event FlightRegistered(bytes32 flightKey, address airline);
    event FlightInsuranceBought(address account, string flightKey);
    event InsureeCredited(address account, uint256 value);
    event AccountWithdrawn(address account, uint256 value);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() {
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

    function setVoteAirline(address airline) public requireCallerAuthorized {
        votesRegistration[airline].push(msg.sender);
    }

    function getAirlineRegistered(address airline)
        public
        view
        requireCallerAuthorized
        returns (bool)
    {
        return (airlines[airline].isRegistered);
    }

    function getAirlineOperational(address airline)
        public
        view
        requireCallerAuthorized
        returns (bool)
    {
        return (airlines[airline].isOperational);
    }

    function getAirlineFunds(address airline)
        public
        view
        requireCallerAuthorized
        returns (uint256)
    {
        return (airlines[airline].funds);
    }

    function authorizeCaller(address caller) public {
        authorizeCallerAddress = caller;
    }

    function getAirlineVotes(address airline)
        public
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
    function buy(
        address passenger,
        string memory flightCode,
        uint256 value,
        address airline,
        uint256 timestamp
    ) external requireCallerAuthorized {
        Flight storage flightData = flights[
            keccak256(abi.encodePacked(airline, flightCode, timestamp))
        ];

        flightData.passengersList.push(passenger);

        Passenger storage flightPassengerInsurance = passengers[passenger];

        flightPassengerInsurance.wallet = passenger;
        flightPassengerInsurance.insuranceCredit = 0;
        flightPassengerInsurance.amount = value;
        flightPassengerInsurance.isCredited = false;

        emit FlightInsuranceBought(passenger, flightCode);
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(
        string memory flightCode,
        address airline,
        uint256 timestamp
    ) internal requireIsOperational requireCallerAuthorized {
        Flight storage flightData = flights[
            keccak256(abi.encodePacked(airline, flightCode, timestamp))
        ];

        for (uint256 i = 0; i < flightData.passengersList.length; i++) {
            Passenger memory passenger = passengers[
                flightData.passengersList[i]
            ];

            if (passenger.isCredited == false) {
                passenger.isCredited = true;
                uint256 amount = passenger
                    .amount
                    .mul(flightData.multiplier)
                    .div(100);
                passenger.insuranceCredit += amount;

                emit InsureeCredited(passenger.wallet, amount);
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(address passenger)
        external
        requireIsOperational
        requireCallerAuthorized
    {
        require(passenger == tx.origin, "Contracts not allowed");
        require(
            passengers[passenger].insuranceCredit > 0,
            "No fund available for withdrawal"
        );

        uint256 amount = passengers[passenger].insuranceCredit;
        passengers[passenger].insuranceCredit = 0;
        passengers[passenger].amount = 0;
        passengers[passenger].isCredited = false;

        payable(passenger).transfer(amount);

        emit AccountWithdrawn(passenger, amount);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fundAirline(address airline, uint256 amount) public {
        airlines[airline].funds = airlines[airline].funds + amount;
        if (airlines[airline].funds >= 10 ether) {
            airlines[airline].isOperational = true;
        }
        emit FundingAirline(airline, amount);
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getAirlinesLength() public view returns (uint256) {
        return airLinesCount;
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string memory destination,
        string memory from,
        string memory flight,
        address airline,
        uint256 timestamp,
        uint256 multiplier
    ) external {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        require(!flights[key].isRegistered, "Flight is already registered.");
        require(
            getAirlineOperational(airline) == true,
            "Airline isn't operational."
        );

        Flight storage flightData = flights[key];
        flightData.isRegistered = true;
        flightData.flightCode = flight;
        flightData.destination = destination;
        flightData.from = from;
        flightData.statusCode = STATUS_CODE_UNKNOWN;
        flightData.updatedTimestamp = timestamp;
        flightData.airline = airline;
        flightData.multiplier = multiplier;

        emit FlightRegistered(key, airline);
    }

    function isValidFlight(
        string memory flightCode,
        address airline,
        uint256 timestamp
    ) external view requireCallerAuthorized returns(bool isValid) {
        
        bytes32 key = keccak256(abi.encodePacked(airline, flightCode, timestamp));
        isValid = flights[key].isRegistered;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     */
    function fund() public payable requireIsOperational {}

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {
        fund();
    }

    receive() external payable {}
}
