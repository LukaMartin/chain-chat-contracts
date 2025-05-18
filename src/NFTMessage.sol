// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
import {ERC721ABurnable} from "erc721a/contracts/extensions/ERC721ABurnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract NFTMessage is ERC721A, ERC721ABurnable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Strings for address;

    // ========== EVENTS ==========

    event MessageSent(
        uint256 indexed tokenId, address indexed from, address indexed to, string message, uint256 timestamp
    );
    event MessageReplied(
        uint256 indexed tokenId, address indexed from, address indexed to, string message, uint256 timestamp
    );
    event AddressBlocked(address indexed blocker, address indexed blocked);
    event AddressUnblocked(address indexed unblocker, address indexed unblocked);
    event MessageBurned(uint256 indexed tokenId);

    // ========== STRUCTS ==========

    struct Message {
        string content;
        address sender;
        address recipient;
        uint256 timestamp;
    }

    // ========== STATE VARIABLES ==========

    bool private _isMessageOperation;
    uint256 public MAX_MESSAGE_LENGTH = 280;
    uint256 public BATCH_BURN_LIMIT = 10;

    // ========== MAPPINGS ==========

    mapping(uint256 => Message) public messages;
    mapping(address => mapping(address => bool)) public blocked;

    // ========== ERRORS ==========

    error Locked();
    error InvalidRecipient();
    error BlockedByRecipient();
    error MessageTooLong();
    error NotMessageOwner();
    error InvalidAddressToBlock();
    error AddressAlreadyBlocked();
    error InvalidAddressToUnblock();
    error AddressNotBlocked();
    error MessageDoesNotExist();
    error BatchBurnLimitExceeded();

    // ========== CONSTRUCTOR ==========

    constructor(string memory name, string memory symbol) ERC721A(name, symbol) Ownable(msg.sender) ReentrancyGuard() {}

    // ========== PUBLIC FUNCTIONS ==========

    /**
     * @notice Send a new message to a recipient
     * @param to The address of the recipient
     * @param content The content of the message
     * @return The token ID of the message
     *
     */
    function sendMessage(address to, string calldata content) external returns (uint256) {
        if (to == address(0)) revert InvalidRecipient();
        if (blocked[to][msg.sender]) revert BlockedByRecipient();
        if (bytes(content).length > MAX_MESSAGE_LENGTH) revert MessageTooLong();

        _isMessageOperation = true;
        uint256 tokenId = _nextTokenId();
        _mint(to, 1);
        _isMessageOperation = false;

        messages[tokenId] = Message({content: content, sender: msg.sender, recipient: to, timestamp: block.timestamp});

        emit MessageSent(tokenId, msg.sender, to, content, block.timestamp);
        return tokenId;
    }

    /**
     * @notice Reply to a message
     * @param tokenId The token ID of the message to reply to
     * @param content The content of the reply
     *
     */
    function reply(uint256 tokenId, string calldata content) external nonReentrant {
        if (bytes(content).length > MAX_MESSAGE_LENGTH) revert MessageTooLong();

        Message storage message = messages[tokenId];
        if (blocked[message.sender][msg.sender]) revert BlockedByRecipient();
        if (ownerOf(tokenId) != msg.sender) revert NotMessageOwner();

        address previousSender = message.sender;
        _isMessageOperation = true;
        safeTransferFrom(msg.sender, previousSender, tokenId);
        _isMessageOperation = false;

        message.content = content;
        message.sender = msg.sender;
        message.recipient = previousSender;
        message.timestamp = block.timestamp;

        emit MessageReplied(tokenId, msg.sender, previousSender, content, block.timestamp);
    }

    /**
     * @notice Block an address
     * @param tokenId The token ID of the message to block
     *
     */
    function blockUser(uint256 tokenId) external {
        Message storage message = messages[tokenId];
        if (message.recipient != msg.sender) revert NotMessageOwner();
        address userToBlock = message.sender;

        if (userToBlock == address(0)) revert InvalidAddressToBlock();
        if (blocked[msg.sender][userToBlock]) revert AddressAlreadyBlocked();

        blocked[msg.sender][userToBlock] = true;

        delete messages[tokenId];
        burn(tokenId);

        emit AddressBlocked(msg.sender, userToBlock);
        emit MessageBurned(tokenId);
    }

    /**
     * @notice Unblock an address
     * @param user The address to unblock
     *
     */
    function unblockUser(address user) external {
        if (user == address(0)) revert InvalidAddressToUnblock();
        if (!blocked[msg.sender][user]) revert AddressNotBlocked();
        blocked[msg.sender][user] = false;
        emit AddressUnblocked(msg.sender, user);
    }

    /**
     * @notice Burn a message
     * @param tokenId The token ID of the message to burn
     *
     */
    function burnMessage(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotMessageOwner();
        _burn(tokenId);
        emit MessageBurned(tokenId);
    }

    function batchBurnMessages(uint256[] calldata tokenIds) external {
        if (tokenIds.length > BATCH_BURN_LIMIT) revert BatchBurnLimitExceeded();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (ownerOf(tokenIds[i]) != msg.sender) revert NotMessageOwner();
            _burn(tokenIds[i]);
            emit MessageBurned(tokenIds[i]);
        }
    }

    // ========== OWNER FUNCTIONS ==========

    /**
     * @notice Set the maximum message length
     * @param newLength The new maximum message length
     *
     */
    function setMaxMessageLength(uint256 newLength) external onlyOwner {
        MAX_MESSAGE_LENGTH = newLength;
    }

    /**
     * @notice Set the batch burn limit
     * @param newLimit The new batch burn limit
     *
     */
    function setBatchBurnLimit(uint256 newLimit) external onlyOwner {
        BATCH_BURN_LIMIT = newLimit;
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Get the maximum message length
     * @return The maximum message length
     *
     */
    function getMaxMessageLength() external view returns (uint256) {
        return MAX_MESSAGE_LENGTH;
    }

    /**
     * @notice Get the batch burn limit
     * @return The batch burn limit
     *
     */
    function getBatchBurnLimit() external view returns (uint256) {
        return BATCH_BURN_LIMIT;
    }

    /**
     * @notice Get the message
     * @param tokenId The token ID of the message
     * @return The message content, sender, recipient, and timestamp
     *
     */
    function getMessage(uint256 tokenId) external view returns (string memory, address, address, uint256) {
        return (
            messages[tokenId].content,
            messages[tokenId].sender,
            messages[tokenId].recipient,
            messages[tokenId].timestamp
        );
    }

    /**
     * @notice Check if an address is blocked
     * @param user The address to check
     * @return True if the address is blocked, false otherwise
     *
     */
    function isBlocked(address user) external view returns (bool) {
        return blocked[msg.sender][user];
    }

    // ========== INTERNAL FUNCTIONS ==========

    /**
     * @notice Burn a message
     * @param tokenId The token ID of the message to burn
     *
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        delete messages[tokenId];
    }

    /**
     * @notice Generate the SVG for a message
     * @param message The message to generate the SVG for
     * @return The SVG
     *
     */
    function generateSVG(Message memory message) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500">',
                "<defs>",
                '<linearGradient id="cardGradient" x1="0%" y1="0%" x2="100%" y2="100%">',
                '<stop offset="0%" style="stop-color:#1a1b1e"/>',
                '<stop offset="100%" style="stop-color:#131313"/>',
                "</linearGradient>",
                "<style>",
                ".card { fill: url(#cardGradient); }",
                ".heading { font-family: Inter, sans-serif; font-weight: bold; fill: #e3f31b; text-anchor: middle; }",
                ".message { font-family: Inter, sans-serif; fill: #ffffff; }",
                ".address { font-family: Inter, sans-serif; fill: #9ba1a6; text-anchor: middle; }",
                ".url { font-family: Inter, sans-serif; fill: #4a4a4a; text-anchor: middle; }",
                "</style>",
                "</defs>",
                '<rect width="500" height="500" rx="40" class="card"/>',
                '<g transform="translate(50, 60)">',
                '<text x="200" y="20" class="heading" font-size="32">New Message</text>',
                "</g>",
                '<foreignObject x="50" y="140" width="400" height="200">',
                '<div xmlns="http://www.w3.org/1999/xhtml" style="width: 100%; height: 100%;">',
                '<p style="margin: 0; font-family: Inter, sans-serif; color: #ffffff; font-size: 28px; font-weight: 500; text-align: center;">',
                '"',
                message.content,
                '"',
                "</p></div></foreignObject>",
                '<text x="250" y="380" class="address" font-size="18">From: ',
                truncateAddress(message.sender),
                "</text>",
                '<text x="250" y="440" class="url" font-size="16">Reply on chainchat.xyz</text>',
                "</svg>"
            )
        );
    }

    /**
     * @notice Truncate an address
     * @param addr The address to truncate
     * @return The truncated address
     *
     */
    function truncateAddress(address addr) internal pure returns (string memory) {
        string memory full = addressToString(addr);
        return string(
            abi.encodePacked(
                substring(full, 0, 8), // 0x + first 6 chars
                "...",
                substring(full, 38, 42) // last 4 chars
            )
        );
    }

    /**
     * @notice Substring a string
     * @param str The string to substring
     * @param startIndex The start index
     * @param endIndex The end index
     * @return The substring
     *
     */
    function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    /**
     * @notice Convert an address to a string
     * @param addr The address to convert
     * @return The string representation of the address
     *
     */
    function addressToString(address addr) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", toAsciiString(addr)));
    }

    /**
     * @notice Convert an address to an ASCII string
     * @param x The address to convert
     * @return The ASCII string representation of the address
     *
     */
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    /**
     * @notice Convert a bytes1 to a character
     * @param b The bytes1 to convert
     * @return c The character
     */
    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    // ========== OVERRIDES ==========

    /**
     * @notice Transfer a message
     * @param from The address of the sender
     * @param to The address of the recipient
     * @param tokenId The token ID of the message to transfer
     *
     */
    function transferFrom(address from, address to, uint256 tokenId) public payable override(ERC721A, IERC721A) {
        if (!_isMessageOperation && to != address(0)) {
            revert Locked();
        }
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Safe transfer a message
     * @param from The address of the sender
     * @param to The address of the recipient
     * @param tokenId The token ID of the message to transfer
     *
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override(ERC721A, IERC721A) {
        if (!_isMessageOperation && to != address(0)) {
            revert Locked();
        }
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Safe transfer a message
     * @param from The address of the sender
     * @param to The address of the recipient
     * @param tokenId The token ID of the message to transfer
     * @param data The data to pass to the recipient
     *
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override(ERC721A, IERC721A)
    {
        if (!_isMessageOperation && to != address(0)) {
            revert Locked();
        }
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Get the token URI for a message
     * @param tokenId The token ID of the message
     * @return The token URI
     *
     */
    function tokenURI(uint256 tokenId) public view override(ERC721A, IERC721A) returns (string memory) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert MessageDoesNotExist();

        Message memory message = messages[tokenId];
        string memory svg = generateSVG(message);

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name": "Message #',
                            tokenId.toString(),
                            '", "description": "An NFT Message", "image": "data:image/svg+xml;base64,',
                            Base64.encode(bytes(svg)),
                            '"}'
                        )
                    )
                )
            )
        );
    }
}
