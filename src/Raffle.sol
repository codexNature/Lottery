// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//Best practice write test as you code each function. 




//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title A sample Raffle Contract
 * @author Olusola Jaiyeola
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {console} from "forge-std/console.sol";  //delete this before you deploy to mainnet or testnet.

contract Raffle is VRFConsumerBaseV2 {
  //Errors
  error Raffle__NotEnoughEthSent();
  error Raffle__TransferFailed();
  error Raffle__RaffleNotOpen();
  error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
  );

  enum RaffleState {
      OPEN,         //0
      CALCULATING   //1
  } //This is to tell which state the contract is at Open meaning you can play, Calculatin meaning contract is at the process of selcting a winner and cannot enter a new player. 


/**State Variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3; //This is how many confirmations before transaction goes through.
  uint32 private constant NUM_WORDS = 1;


  uint256 private immutable i_entranceFee; //with immutable we will only able to save our entrance fee once, it will also be cheap om gas.
  //@dev Duration of the lottery in seconds.
  uint256 private immutable i_interval; 
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  //address private immutable i_vrfCoordinator;
  bytes32 private immutable i_gasLane;
  uint64 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;

/** Storage Variables */
  address payable[] private s_players; //this is a storage variable because it is going to change the number of players in this array
  uint256 private s_lastTimeStamp;
  address private s_recentWinner;
  RaffleState private s_raffleState;



  /**Events */  //events are not accesseble by smart contracts
  event EnteredRaffle(address indexed player);
  event PickedWinner(address indexed winner);
  event RequestedRaffleWinner(uint256 indexed requestId);


 /**Constructors */
  constructor(
      uint256 entranceFee,
      uint256 interval,
      address vrfCoordinator,
      bytes32 gasLane,
      uint64 subscriptionId,
      uint32 callbackGasLimit
  ) VRFConsumerBaseV2(vrfCoordinator)  {
      i_entranceFee = entranceFee;
      i_interval = interval;
      i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
      i_gasLane = gasLane;
      i_subscriptionId = subscriptionId;
      i_callbackGasLimit = callbackGasLimit;

      s_lastTimeStamp = block.timestamp;
      s_raffleState = RaffleState.OPEN;  //testRaffleInitializesInOpenState
  }
    function enterRaffle() public payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent!"); //we use custom error instead as require is not gas efficient, hence below code, same thig as this.
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent(); //testRaffleRevertWhenYouDontPayEnough  
        }
          if (s_raffleState != RaffleState.OPEN){
              revert Raffle__RaffleNotOpen(); //This is to be sure raffle is not calculating a winner, you can only enter when raffle not open. 
              } // the test  testCantEnterWhenRaffleIsCalculating
        console.log(msg.value); //This is a way we can print out degugging statements in our tests.
        s_players.push(payable(msg.sender)); //TPush will add the entered player address to the array using msg.sender to get the address. testRaffleRecordsPlayerWhenTheyEnter
        //Event makes migratio and front end indexing easier. //events are a way for smart contracts to communicate with external applications and clients. They allow contracts to emit messages about certain occurrences or state changes during contract execution.
        emit EnteredRaffle(msg.sender); //Event above is emmitted from here.
    }

     
    //1. Get a random number
    //2. Use the random number to pick a player
    //3. Automatically call the function.

    // When is the winner supposed to be picked?
    /**
     * 
     * @dev This is the function that the chainlink automation nodes call to see if it's time to per=form an upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle3 is the OPEN state
     * 3. The contract has ETH (aka, players)
     * 4. (Implicit) The subscription is funded with LINK.
     * This is what we want our checkupkeep to do. we want it to return the upKeepNeeded as true if all of these comnditions are met, otherwise return false.
     */
    function checkUpkeep(
      bytes memory /*checkData */)  //if a function requires a input parameter and for the chainlink nodes to recognize this function we need an input parameter but we are not gonna use the input parameter we ignoreit by wrapping it in a comment like /* checkData */ 
      public view returns 
      (bool upkeepNeeded, 
      bytes memory /* performData */) {
        bool isOpen = RaffleState.OPEN == s_raffleState; //Condition 2. met here.
        bool timeHasPassed = ( (block.timestamp - s_lastTimeStamp) >= i_interval); //Condition 1 above met
        bool hasPlayers = s_players.length > 0; //condition 3(players) met here.
        bool hasBalance = address(this).balance > 0; //condition 3(ETH) met here. 
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers); //if any in the brackets are false upkeepNeeded returns false, all must be true for upkeepNeeded to be true. 
        return (upkeepNeeded, "0x0"); //0x0 is how we say it is a blank bytes object. If this is true it called performUpkeep. 
      }  

    function performUpkeep(bytes calldata /* performData */) external {  //performdata same as above with checkData. 
          (bool upkeepNeeded, ) = checkUpkeep(""); //we call our checkUpkeep function in our perfomUpkeep function to make sure it is time to do an upkeep. 
          if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
              address(this).balance,
              s_players.length,
              uint256(s_raffleState) //The error message could be empty but with this inside it helps with debugging
            );
          }
      //Check to see if enough time has passed, this is done usimg the i_interval statevariable created.
     /* if( (block.timestamp - s_lastTimeStamp) < i_interval) {
          revert(); */ //this two lines of code is moved up to become timeHasPassed. 
      //} //if it get passed this point it means enough time has passed. 

      //Chainlink VRF is a two transaction
      //1. Request the RNG
      //2. Get the random number
        s_raffleState = RaffleState.CALCULATING;  //Before we send the below requestId we set s_raffleState to calculatate.  
        //uint256 requestId = 
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,  // changedd keyHash into i_gasLane
            i_subscriptionId, 
            REQUEST_CONFIRMATIONS, 
            i_callbackGasLimit, //max gas that we want the callback to do.
            NUM_WORDS //number of random numbers we want.
        ); //code copied from chainlink VRF for getting random numbers
        emit RequestedRaffleWinner(requestId); //This is redunded because it already gonna be done in the vrfcoodinatorV2Mock. In normal ssmart contract we caan never get value that this emmmited however in tests we can. 
    }

    //CEI: Checks, Effects, Interactions we code using the style called CEI. 
      function fulfillRandomWords(
        uint256 /*requestId */ ,
        uint256[] memory randomWords
      ) internal override {
          //s_player = 10
          //rng = 12
          //Checks
          //Effects (Our own contract)
          uint256 indexOfWinner = randomWords[0] % s_players.length; //this is how we pick a random winner
          address payable winner = s_players[indexOfWinner]; 
          s_recentWinner = winner;
          s_raffleState =  RaffleState.OPEN; //Once winner is picked we wanna flip the s_raffleState back to open. 
          s_players = new address payable[](0);  // This will reset the array for the new players and purge old players from the array above. starting at 0
          s_lastTimeStamp = block.timestamp;  // Restart the timestamp of the new players. Start the clock over.
          emit PickedWinner(winner); //good idea to emit a winner picked log. It is better to place your emit before interactions. 

          //Interactions with(other contracts)
          (bool success,) = winner.call{value: address(this).balance}(""); //pays the winner all ticket sales amount goes to winner's address
          if (!success) {
            revert Raffle__TransferFailed(); //making sure transaction goes through. 
          }
      }


    /**Getter Functions */
    function getEntranceFee() external view returns(uint256){  //we want people to get the entrance fee.
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) { //This is how we access the s_players array for the test script. 
      return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
      return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
      return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
      return s_lastTimeStamp;
    }
}

