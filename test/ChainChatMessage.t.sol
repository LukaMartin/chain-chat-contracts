// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ChainChatMessage} from "../src/ChainChatMessage.sol";
import {BaseTest} from "./BaseTest.t.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";

contract ChainChatMessageTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_sendMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Assertions
        assertEq(chainChatMessage.ownerOf(tokenId), Bob);
        (address sender, address recipient, uint96 timestamp, string memory content) =
            chainChatMessage.messages(tokenId);
        assertEq(content, "Hello, Bob!");
        assertEq(sender, Alice);
        assertEq(recipient, Bob);
        assertEq(timestamp, block.timestamp);
    }

    function test_replyToMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Reply to message
        vm.prank(Bob);
        chainChatMessage.reply(tokenId, "Hello, Alice!");

        // Assertions
        assertEq(chainChatMessage.ownerOf(tokenId), Alice);
        (address sender, address recipient, uint96 timestamp, string memory content) =
            chainChatMessage.messages(tokenId);
        assertEq(content, "Hello, Alice!");
        assertEq(sender, Bob);
        assertEq(recipient, Alice);
        assertEq(timestamp, block.timestamp);
    }

    function test_blockAddress() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Block Alice
        vm.prank(Bob);
        chainChatMessage.blockUser(tokenId);

        // Try to send new message after being blocked
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.BlockedByRecipient.selector));
        chainChatMessage.sendMessage(Bob, "Hello, again Bob!");

        // Verify token was burned
        vm.expectRevert();
        chainChatMessage.ownerOf(tokenId);
    }

    function test_unblockAddress() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Block Alice
        vm.prank(Bob);
        chainChatMessage.blockUser(tokenId);

        // Unblock Alice
        vm.prank(Bob);
        chainChatMessage.unblockUser(Alice);

        // Try to send new message after being unblocked
        vm.prank(Alice);
        uint256 tokenId2 = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Assertions
        assertEq(chainChatMessage.ownerOf(tokenId2), Bob);
        (address sender, address recipient, uint96 timestamp, string memory content) =
            chainChatMessage.messages(tokenId2);
        assertEq(content, "Hello, Bob!");
        assertEq(sender, Alice);
        assertEq(recipient, Bob);
        assertEq(timestamp, block.timestamp);
    }

    function test_burnMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Burn message
        vm.prank(Bob);
        chainChatMessage.burnMessage(tokenId);

        // Verify message was burned
        vm.expectRevert();
        chainChatMessage.ownerOf(tokenId);

        // Verify message was burned
        (address sender, address recipient, uint96 timestamp, string memory content) =
            chainChatMessage.messages(tokenId);
        assertEq(content, "");
        assertEq(sender, address(0));
        assertEq(recipient, address(0));
        assertEq(timestamp, 0);
    }

    function test_multipleReplies() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Reply to message
        vm.prank(Bob);
        chainChatMessage.reply(tokenId, "Hello, Alice!");

        // Reply to message
        vm.prank(Alice);
        chainChatMessage.reply(tokenId, "How are you Bob?");

        // Reply to message
        vm.prank(Bob);
        chainChatMessage.reply(tokenId, "I'm good, thank you!");

        // Assertions
        (address sender, address recipient, uint96 timestamp, string memory content) =
            chainChatMessage.messages(tokenId);
        assertEq(content, "I'm good, thank you!");
        assertEq(sender, Bob);
        assertEq(recipient, Alice);
        assertEq(timestamp, block.timestamp);
    }

    function testFuzz_messageContent(string calldata content) public {
        // This will run hundreds of times with different random content
        vm.assume(bytes(content).length > 0 && bytes(content).length <= chainChatMessage.maxMessageLength());

        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, content);

        (,,, string memory storedContent) = chainChatMessage.messages(tokenId);
        // Verify ANY valid message is stored correctly
        assertEq(storedContent, content);
    }

    function test_setMaxMessageLength() public {
        // Set new max message length
        vm.prank(Deployer);
        chainChatMessage.setMaxMessageLength(100);

        // Assertions
        assertEq(chainChatMessage.maxMessageLength(), 100);
    }

    function test_setBatchBurnLimit() public {
        // Set new batch burn limit
        vm.prank(Deployer);
        chainChatMessage.setBatchBurnLimit(100);

        // Assertions
        assertEq(chainChatMessage.batchBurnLimit(), 100);
    }

    function test_getMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Get message
        (address sender, address recipient, uint96 timestamp, string memory content) =
            chainChatMessage.getMessage(tokenId);

        // Assertions
        assertEq(content, "Hello, Bob!");
        assertEq(sender, Alice);
        assertEq(recipient, Bob);
        assertEq(timestamp, block.timestamp);
    }

    function test_isBlocked() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Assertions
        vm.prank(Bob);
        bool isBlockedOne = chainChatMessage.isBlocked(Alice);
        assertEq(isBlockedOne, false);

        // Block Alice
        vm.prank(Bob);
        chainChatMessage.blockUser(tokenId);

        // Assertions
        vm.prank(Bob);
        bool isBlockedTwo = chainChatMessage.isBlocked(Alice);
        assertEq(isBlockedTwo, true);
    }

    function test_fail_sendMessage_invalidRecipient() public {
        // Send new message
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.InvalidRecipient.selector));
        chainChatMessage.sendMessage(address(0), "Hello, Bob!"); // Address(0) is not a valid recipient
    }

    function test_fail_sendMessage_blocked() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Block Alice
        vm.prank(Bob);
        chainChatMessage.blockUser(tokenId);

        // Try to send new message after being blocked
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.BlockedByRecipient.selector));
        chainChatMessage.sendMessage(Bob, "Hello, Bob!");
    }

    function test_fail_sendMessage_messageTooLong() public {
        // Send new message
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.MessageTooLong.selector));
        chainChatMessage.sendMessage(
            Bob,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
    }

    function test_fail_replyToMessage_messageTooLong() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Reply to message
        vm.prank(Bob);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.MessageTooLong.selector));
        chainChatMessage.reply(
            tokenId,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
    }

    function test_fail_replyToMessage_NotOwner() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to reply to message
        vm.prank(Charlie);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.NotMessageOwner.selector));
        chainChatMessage.reply(tokenId, "Hello, Alice!");
    }

    function test_fail_blockAddress_notMessageOwner() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to block message
        vm.prank(Charlie);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.NotMessageOwner.selector));
        chainChatMessage.blockUser(tokenId);
    }

    function test_fail_unblockAddress_invalidAddress() public {
        // Try to unblock invalid address
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.InvalidAddressToUnblock.selector));
        chainChatMessage.unblockUser(address(0));
    }

    function test_fail_unblockAddress_notBlocked() public {
        // Try to unblock Bob
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.AddressNotBlocked.selector));
        chainChatMessage.unblockUser(Bob);
    }

    function test_fail_burnMessage_notOwner() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to burn message
        vm.prank(Charlie);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.NotMessageOwner.selector));
        chainChatMessage.burnMessage(tokenId);
    }

    function test_fail_transferFrom_locked() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = chainChatMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to transfer message
        vm.prank(Bob);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.Locked.selector));
        chainChatMessage.transferFrom(Bob, Charlie, tokenId);

        // Try to safeTransferFrom message
        vm.prank(Bob);
        vm.expectRevert(abi.encodeWithSelector(ChainChatMessage.Locked.selector));
        chainChatMessage.safeTransferFrom(Bob, Charlie, tokenId);
    }
}
