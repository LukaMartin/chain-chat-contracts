// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTMessage} from "../../src/NFTMessage.sol";
import {BaseTest} from "./BaseTest.t.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";

contract NFTMessageTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_sendMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Assertions
        assertEq(nftMessage.ownerOf(tokenId), Bob);
        (string memory content, address sender, address recipient, uint256 timestamp) = nftMessage.messages(tokenId);
        assertEq(content, "Hello, Bob!");
        assertEq(sender, Alice);
        assertEq(recipient, Bob);
        assertEq(timestamp, block.timestamp);
    }

    function test_replyToMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Reply to message
        vm.prank(Bob);
        nftMessage.reply(tokenId, "Hello, Alice!");

        // Assertions
        assertEq(nftMessage.ownerOf(tokenId), Alice);
        (string memory content, address sender, address recipient, uint256 timestamp) = nftMessage.messages(tokenId);
        assertEq(content, "Hello, Alice!");
        assertEq(sender, Bob);
        assertEq(recipient, Alice);
        assertEq(timestamp, block.timestamp);
    }

    function test_blockAddress() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Block Alice
        vm.prank(Bob);
        nftMessage.blockUser(tokenId);

        // Try to send new message after being blocked
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.BlockedByRecipient.selector));
        nftMessage.sendMessage(Bob, "Hello, again Bob!");

        // Verify token was burned
        vm.expectRevert();
        nftMessage.ownerOf(tokenId);
    }

    function test_unblockAddress() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Block Alice
        vm.prank(Bob);
        nftMessage.blockUser(tokenId);

        // Unblock Alice
        vm.prank(Bob);
        nftMessage.unblockUser(Alice);

        // Try to send new message after being unblocked
        vm.prank(Alice);
        uint256 tokenId2 = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Assertions
        assertEq(nftMessage.ownerOf(tokenId2), Bob);
        (string memory content, address sender, address recipient, uint256 timestamp) = nftMessage.messages(tokenId2);
        assertEq(content, "Hello, Bob!");
        assertEq(sender, Alice);
        assertEq(recipient, Bob);
        assertEq(timestamp, block.timestamp);
    }

    function test_burnMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Burn message
        vm.prank(Bob);
        nftMessage.burnMessage(tokenId);

        // Verify message was burned
        vm.expectRevert();
        nftMessage.ownerOf(tokenId);

        // Verify message was burned
        (string memory content, address sender, address recipient, uint256 timestamp) = nftMessage.messages(tokenId);
        assertEq(content, "");
        assertEq(sender, address(0));
        assertEq(recipient, address(0));
        assertEq(timestamp, 0);
    }

    function test_multipleReplies() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Reply to message
        vm.prank(Bob);
        nftMessage.reply(tokenId, "Hello, Alice!");

        // Reply to message
        vm.prank(Alice);
        nftMessage.reply(tokenId, "How are you Bob?");

        // Reply to message
        vm.prank(Bob);
        nftMessage.reply(tokenId, "I'm good, thank you!");

        // Assertions
        (string memory content, address sender, address recipient, uint256 timestamp) = nftMessage.messages(tokenId);
        assertEq(content, "I'm good, thank you!");
        assertEq(sender, Bob);
        assertEq(recipient, Alice);
        assertEq(timestamp, block.timestamp);
    }

    function testFuzz_messageContent(string calldata content) public {
        // This will run hundreds of times with different random content
        vm.assume(bytes(content).length > 0 && bytes(content).length <= nftMessage.MAX_MESSAGE_LENGTH());

        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, content);

        (string memory storedContent,,,) = nftMessage.messages(tokenId);
        // Verify ANY valid message is stored correctly
        assertEq(storedContent, content);
    }

    function test_setMaxMessageLength() public {
        // Set new max message length
        vm.prank(Deployer);
        nftMessage.setMaxMessageLength(100);

        // Assertions
        assertEq(nftMessage.MAX_MESSAGE_LENGTH(), 100);
    }

    function test_setBatchBurnLimit() public {
        // Set new batch burn limit
        vm.prank(Deployer);
        nftMessage.setBatchBurnLimit(100);

        // Assertions
        assertEq(nftMessage.BATCH_BURN_LIMIT(), 100);
    }

    function test_getMessage() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Get message
        (string memory content, address sender, address recipient, uint256 timestamp) = nftMessage.getMessage(tokenId);

        // Assertions
        assertEq(content, "Hello, Bob!");
        assertEq(sender, Alice);
        assertEq(recipient, Bob);
        assertEq(timestamp, block.timestamp);
    }

    function test_fail_sendMessage_invalidRecipient() public {
        // Send new message
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.InvalidRecipient.selector));
        nftMessage.sendMessage(address(0), "Hello, Bob!"); // Address(0) is not a valid recipient
    }

    function test_fail_sendMessage_blocked() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Block Alice
        vm.prank(Bob);
        nftMessage.blockUser(tokenId);

        // Try to send new message after being blocked
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.BlockedByRecipient.selector));
        nftMessage.sendMessage(Bob, "Hello, Bob!");
    }

    function test_fail_sendMessage_messageTooLong() public {
        // Send new message
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.MessageTooLong.selector));
        nftMessage.sendMessage(
            Bob,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
    }

    function test_fail_replyToMessage_messageTooLong() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Reply to message
        vm.prank(Bob);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.MessageTooLong.selector));
        nftMessage.reply(
            tokenId,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
    }

    function test_fail_replyToMessage_NotOwner() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to reply to message
        vm.prank(Charlie);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.NotMessageOwner.selector));
        nftMessage.reply(tokenId, "Hello, Alice!");
    }

    function test_fail_blockAddress_notMessageOwner() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to block message
        vm.prank(Charlie);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.NotMessageOwner.selector));
        nftMessage.blockUser(tokenId);
    }

    function test_fail_unblockAddress_invalidAddress() public {
        // Try to unblock invalid address
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.InvalidAddressToUnblock.selector));
        nftMessage.unblockUser(address(0));
    }

    function test_fail_unblockAddress_notBlocked() public {
        // Try to unblock Bob
        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.AddressNotBlocked.selector));
        nftMessage.unblockUser(Bob);
    }

    function test_fail_burnMessage_notOwner() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to burn message
        vm.prank(Charlie);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.NotMessageOwner.selector));
        nftMessage.burnMessage(tokenId);
    }

    function test_fail_transferFrom_locked() public {
        // Send new message
        vm.prank(Alice);
        uint256 tokenId = nftMessage.sendMessage(Bob, "Hello, Bob!");

        // Try to transfer message
        vm.prank(Bob);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.Locked.selector));
        nftMessage.transferFrom(Bob, Charlie, tokenId);

        // Try to safeTransferFrom message
        vm.prank(Bob);
        vm.expectRevert(abi.encodeWithSelector(NFTMessage.Locked.selector));
        nftMessage.safeTransferFrom(Bob, Charlie, tokenId);
    }
}
