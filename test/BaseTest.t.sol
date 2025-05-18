// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {NFTMessage} from "../src/NFTMessage.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract BaseTest is Test {
    // NFT Message contract
    NFTMessage nftMessage;

    // User addresses
    address Alice;
    address Bob;
    address Charlie;
    address Dave;
    address Eve;
    address Deployer;

    // Default ETH balance
    uint256 defaultETHBalance = 100 ether;

    // RPC
    uint256 hyperEvmFork;
    string HYPER_EVM_RPC_URL = vm.envString("HYPER_EVM_RPC_URL");

    function setUp() public virtual {
        // Create fork
        hyperEvmFork = vm.createSelectFork(HYPER_EVM_RPC_URL);
        assertEq(vm.activeFork(), hyperEvmFork);

        // Create users
        _createUsers();

        // Deploy NFT Message contract
        vm.prank(Deployer);
        nftMessage = new NFTMessage("NFT Messages", "MSG");
    }

    function _createUsers() internal virtual {
        Alice = address(1);
        vm.label(address(1), "Alice");
        vm.deal(payable(address(1)), defaultETHBalance);

        Bob = address(2);
        vm.label(address(2), "Bob");
        vm.deal(payable(address(2)), defaultETHBalance);

        Charlie = address(3);
        vm.label(address(3), "Charlie");
        vm.deal(payable(address(3)), defaultETHBalance);

        Dave = address(4);
        vm.label(address(4), "Dave");
        vm.deal(payable(address(4)), defaultETHBalance);

        Eve = address(5);
        vm.label(address(5), "Eve");
        vm.deal(payable(address(5)), defaultETHBalance);

        Deployer = address(6);
        vm.label(address(6), "Deployer");
        vm.deal(payable(address(6)), defaultETHBalance);
    }
}
