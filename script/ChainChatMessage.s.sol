// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ChainChatMessage} from "../src/ChainChatMessage.sol";
import {console} from "forge-std/console.sol";

contract DeployChainChatMessage is Script {
    // Constructor args
    string public name = "ChainChat Message Test";
    string public symbol = "MSGTEST";

    function run() external returns (ChainChatMessage) {
        vm.startBroadcast();

        // Deploy the contract with constructor args
        ChainChatMessage chainChatMessage = new ChainChatMessage(name, symbol);

        console.log("ChainChatMessage deployed to:", address(chainChatMessage));

        vm.stopBroadcast();

        return chainChatMessage;
    }
}
