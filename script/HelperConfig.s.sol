// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";


contract HelperConfig is Script {
      struct NetworkConfig {   //we input parameters here from the constructor pf the main contract Raffle. 
          uint256 entranceFee;
          uint256 interval;
          address vrfCoordinator;
          bytes32 gasLane;
          uint64 subscriptionId;
          uint32 callbackGasLimit;
          address link;
          uint256 deployerKey;
      }

      uint256 public constant DEFAULT_ANVIL_KEY =
          0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
      NetworkConfig public activeNetworkConfig;

      constructor() {
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        }else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
      }

      function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
          return 
          NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, //address gotten from chainlink under vrf, supported network, sepolia, VRF coordinator. 
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, //address get from chainlink under vrf, support network, sepolia, gwei Key Hash. 
            subscriptionId: 10278, //Will update this with our subId!
            callbackGasLimit: 500000, // 500,000 gas!
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, //Link token address. 
            deployerKey: vm.envUint("PRIVATE_KEY")
          });
      }

      function getOrCreateAnvilEthConfig() 
          public 
          returns(NetworkConfig 
          memory){
            if (activeNetworkConfig.vrfCoordinator != address(0)) {
                return activeNetworkConfig;
            }

            uint96 baseFee = 0.25 ether; //0.25 LINK
            uint96 gasPriceLink = 1e9; // 1 gwei     // both are gotten from the contructor(its payments parameters) of VRFCoordinatorV2Mock.sol

            vm.startBroadcast();
            VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
                baseFee,
                gasPriceLink
            );
            LinkToken link = new LinkToken();
            vm.stopBroadcast();  //for anvil we deploy a mock link token
            

            return 
              NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorMock), //address gotten from chainlink under vrf, supported network, sepolia, VRF coordinator. 
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, //address get from chainlink under vrf, support network, sepolia, gwei Key Hash. 
                subscriptionId: 1, //our script will add this. 
                callbackGasLimit: 500000, // 500,000 gas!
                link: address(link),
                deployerKey: DEFAULT_ANVIL_KEY
              }); //similar to pour sepolia with main diff VRFCoordinatorMock
      }
}