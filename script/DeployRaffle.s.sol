// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./interactions.s.sol";

contract DeployRaffle is Script {
      function run() external returns (Raffle, HelperConfig) {
          HelperConfig helperConfig = new HelperConfig();
            (uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
            )
            = helperConfig.activeNetworkConfig();
          //NetworkConfig config = helperConfig.activeNetworkConfig(); //this is same as above if i imported NetworkConfig from Helperconfig but with above it is deconstructed. 
          

          //Create subscription
          if(subscriptionId == 1){
              //we are gonna need to create a subscription.
              CreateSubscription createsubscription = new CreateSubscription();
              subscriptionId = createsubscription.createSubscription(
                vrfCoordinator,
                deployerKey
              );

              //Funding subscription
              FundSubscription fundSubscription = new FundSubscription();
              fundSubscription.fundSubscription(
                vrfCoordinator, 
                subscriptionId, 
                link,
                deployerKey
                );
          }

          //Launch our raffle(SC)
          vm.startBroadcast(deployerKey);
          Raffle raffle = new Raffle(
              entranceFee,
              interval,
              vrfCoordinator,
              gasLane,
              subscriptionId,
              callbackGasLimit
          );
          vm.stopBroadcast();

          AddConsumer addConsumer = new AddConsumer();
          addConsumer.addConsumer(
                address(raffle), 
                vrfCoordinator, 
                subscriptionId,
                deployerKey
          );  
          return (raffle, helperConfig);
      }
}
