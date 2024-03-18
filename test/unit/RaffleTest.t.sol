// SPDX-License-Identifier: MIT

//check book.getfoundry.sh/cheatcodes   to get cheat codes needed for testing. 

pragma solidity ^0.8.20;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription} from "../../script/interactions.s.sol";

contract RaffleTest is Test {
  /* Events */ //Events cannot be impoerted like structs, enums etc we have to redefine them. 
  event EnteredRaffle(address indexed player);



  Raffle public raffle;
  HelperConfig public helperConfig;


 //State Variables
  uint256 entranceFee;
  uint256 interval;
  address vrfCoordinator;
  bytes32 gasLane;
  uint64 subscriptionId;
  uint32 callbackGasLimit;
  address link;
  

  address public PLAYER = makeAddr("player"); //Creating a starting player to interact for testing.
  uint256 public constant STARTING_USER_BALANCE = 10 ether; //And this is funding the starting user created.

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
         (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
            
            
          ) = helperConfig.activeNetworkConfig();
          vm.deal(PLAYER, STARTING_USER_BALANCE); //cheat code to give money to the test address(PLAYER) with the 10 ether above.
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); //RaffelState is a type(from Raffle.sol ln 75) 
    }


    /////////////////////////////
    // enterRaffle            //
    ////////////////////////////

    function testRaffleRevertWhenYouDontPayEnough() public { //test if it will revert if player does not pay enough eth. 
      //Arrange
      vm.prank(PLAYER);
      //Act/ Assert
      vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
      raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public { //we wanna test and make sure that our s_player array is being updated. 
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded =  raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventsOnEntrance() public { //This is to test Event making sure that it emits events.
        //Arrange
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); //we enter the raffle with test*PLAYER) like this. 
        vm.warp(block.timestamp + interval + 1); //this is to make sure the time passed. 
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); //This will make it be in a calculatiog state. 

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ///////////////////
    // checkUpKeep  //
    //////////////////
    function testCheckUpKeepReturnsFalseIfIthasNoBalance() public {
      //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Acc
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseRaffleNoOpen() public {
      //Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
      raffle.performUpkeep("");

      //Act
      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      //Assert
      assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
      //Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.roll(block.number + 1);

      //Account
      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      //assert
      assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
      // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    ///////////////////
    // performUpkeep //
    ///////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
      //Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);

      // Act / Assert
      raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
      //Arrange
      uint256 currentBalance = 0;
      uint256 numPlayers = 0;
      uint256 raffleState = 0; //raflestate open is 0 and calculating is 1
      // All this above tells checkUpkeep is false, check against performUpkeep function in Raffle.sol

      //Act / Assert 
      vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
      );
      raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee} ();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //What if I need to test using the output of an event?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public //this is testing events what it emit, output of an event.
      //Arrange 
      raffleEnteredAndTimePassed
    {   
        //Act
        vm.recordLogs(); //it is gonna automatically save all the log outputs into this data structure that we can view with getrecordsLogs().
        raffle.performUpkeep(""); //this is gonna emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); //it is gonna get all the values we recently emmit above. Vm.Logs[] is a special type that comes with foundry tests 
        bytes32 requestId = entries[1].topics[1]; //this will get the actual info we need from the list of arrays from the output above we know it is number 1 [1] by using debugger from vm resources.

        Raffle.RaffleState rState= raffle.getRaffleState();

        assert(uint256(requestId) > 0 );
        assert(uint256(rState) == 1);
    }

    ////////////////////////
    // fulfillRandomWords //
    ///////////////////////

    modifier skipFork() {
      if (block.chainid != 31337){ //31337 is anvil chainId. 
          return;
      }
      _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(  //we need to make sure this always fail. 
      uint256 randomRequestId
    ) 
      public raffleEnteredAndTimePassed skipFork
      {
        //Arrange   //this is where we gonna have the Mock actully call fullfillRandomwords and it should fail.
      /*  vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords( //we wanna make sure calling randowmwords in mock is always going to revert.
          0,
          address(raffle)
        ); */

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords( //we wanna make sure calling randowmwords in mock is always going to revert.
          randomRequestId, // we dpo this intstead of above to test all numbers 0, 1,2 3 etc intead of just 0 or rewritting code for all the numbers. Because of randomRequestId when we run the test it will create a random id number for this and call this test many times with many random numbers consistently checking that the nonexistent request happens. 
          address(raffle)
        );
      }

      function testFullfillRandomWordsPicksAWinnerResetsAndSendsMoney()  //This is testing the full contract here, what the entire contract is meant to do. 
        public 
        raffleEnteredAndTimePassed
        skipFork
        {
          //Arrange  this will create a whole bunch of pleaer to enter the raffle with some ether using hoax cheatcode.
          uint256 additionalEntrants = 5;
          uint256 startingIndex = 1;
          for(uint256 i = startingIndex; i< startingIndex + additionalEntrants; i++){
            address player = address(uint160(i)); // we took the uint256 i above to wrap it as a uint160 then wrap that as a player, this will make a whole bunch of random pple enter the raffle
            hoax(player, STARTING_USER_BALANCE);     //hoax is a cheatcode that setsup a prank from an address and then gives it some ether.
            raffle.enterRaffle{value: entranceFee}(); //now we are entering the raffle using hoax to pretend we are a player with 1 ether.
          }

          uint256 prize = entranceFee * (additionalEntrants + 1);

          vm.recordLogs(); 
          raffle.performUpkeep(""); 
          Vm.Log[] memory entries = vm.getRecordedLogs();
          bytes32 requestId = entries[1].topics[1];

          uint256 previousTimeStamp = raffle.getLastTimeStamp();

          //pretend to be chainlink vrf to get random number and pick winner. 
          VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords( 
            uint256 (requestId),
            address(raffle)  //we skipfork because we are pretending to be the VRFcoordinator and that will not work wiyh testnet
          );

          //Assert  list of all the contract does under fullfillRandWords functions
          assert(uint256 (raffle.getRaffleState()) == 0); //0 is open
          assert(raffle.getRecentWinner() != address(0));
          assert(raffle.getLengthOfPlayers() == 0);
          assert(previousTimeStamp < raffle.getLastTimeStamp());
          //10050000000000000000
          //console.log(raffle.getRecentWinner().balance);
          //10060000000000000000
          //console.log(prize + STARTING_USER_BALANCE);
          assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);
        }

}

