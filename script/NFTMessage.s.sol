// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {NFTMessage} from "../src/NFTMessage.sol";
import {console} from "forge-std/console.sol";

contract DeployNFTMessage is Script {
    // Constructor args
    string public name = "NFT Message Test";
    string public symbol = "MSGTEST";

    function run() external returns (NFTMessage) {
        vm.startBroadcast();

        // Deploy the contract with constructor args
        NFTMessage nftMessage = new NFTMessage(name, symbol);

        console.log("NFTMessage deployed to:", address(nftMessage));

        vm.stopBroadcast();

        return nftMessage;
    }
}
