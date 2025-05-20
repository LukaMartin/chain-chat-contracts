// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ChainChatMessage is ERC721, ERC721Burnable, Ownable, ReentrancyGuard {
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
        address sender;
        address recipient;
        uint96 timestamp;
        string content;
    }

    // ========== STATE VARIABLES ==========

    uint256 public maxMessageLength = 280;
    uint256 public batchBurnLimit = 10;
    uint256 public nextTokenId = 1;

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

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) ReentrancyGuard() {}

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
        if (bytes(content).length > maxMessageLength) revert MessageTooLong();

        uint256 tokenId = nextTokenId;
        nextTokenId++;

        messages[tokenId] =
            Message({sender: msg.sender, recipient: to, timestamp: uint96(block.timestamp), content: content});

        _mint(to, tokenId);

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
        if (bytes(content).length > maxMessageLength) revert MessageTooLong();

        Message storage message = messages[tokenId];
        if (blocked[message.sender][msg.sender]) revert BlockedByRecipient();
        if (ownerOf(tokenId) != msg.sender) revert NotMessageOwner();

        address previousSender = message.sender;

        message.sender = msg.sender;
        message.recipient = previousSender;
        message.timestamp = uint96(block.timestamp);
        message.content = content;

        _safeTransfer(msg.sender, previousSender, tokenId);

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
        _burnToken(tokenId);
        emit MessageBurned(tokenId);
    }

    function batchBurnMessages(uint256[] calldata tokenIds) external {
        if (tokenIds.length > batchBurnLimit) revert BatchBurnLimitExceeded();
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
        maxMessageLength = newLength;
    }

    /**
     * @notice Set the batch burn limit
     * @param newLimit The new batch burn limit
     *
     */
    function setBatchBurnLimit(uint256 newLimit) external onlyOwner {
        batchBurnLimit = newLimit;
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Get the maximum message length
     * @return The maximum message length
     *
     */
    function getMaxMessageLength() external view returns (uint256) {
        return maxMessageLength;
    }

    /**
     * @notice Get the batch burn limit
     * @return The batch burn limit
     *
     */
    function getBatchBurnLimit() external view returns (uint256) {
        return batchBurnLimit;
    }

    /**
     * @notice Get the message
     * @param tokenId The token ID of the message
     * @return The message content, sender, recipient, and timestamp
     *
     */
    function getMessage(uint256 tokenId) external view returns (address, address, uint96, string memory) {
        return (
            messages[tokenId].sender,
            messages[tokenId].recipient,
            messages[tokenId].timestamp,
            messages[tokenId].content
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
     * @notice Generate the SVG for a message
     * @param message The message to generate the SVG for
     * @return The SVG
     *
     */
    function _generateSVG(Message memory message) internal pure returns (string memory) {
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
                '<rect width="500" height="500" rx="0" class="card"/>',
                '<g transform="translate(50, 40)">',
                '<g transform="translate(70, -6) scale(0.04)">',
                '<path d="M406 0H438L468 2L496 5L525 10L550 16L581 25L608 35L635 47L660 60L680 72L695 82L707 91L723 104L734 114L742 121L762 141L771 152L785 170L798 190L808 207L816 223L826 246L835 274L841 301L844 324L845 342V362L843 387L839 411L832 438L823 463L811 489L799 511L785 532L775 545L766 556L757 566L746 578L730 594L719 603L710 612L699 621L687 632L665 650L652 661L638 672L624 684L613 693L600 704L589 713L576 724L566 732L553 743L543 751L532 760L519 771L505 783L494 793L480 804L471 808L468 809H453L443 805L435 799L428 788L425 779L424 719L421 712L416 707L408 703L395 701L361 699L331 695L305 690L275 682L243 671L213 658L188 645L165 631L145 617L131 606L117 594L109 587L84 562L75 551L68 543L54 524L37 496L24 470L15 446L7 419L2 392L0 371V329L3 303L8 278L17 249L27 225L37 205L49 185L60 169L74 151L83 141L90 133L111 112L119 105L136 91L153 79L172 67L193 55L208 47L240 33L268 23L294 15L327 8L354 4L385 1L406 0Z" fill="#E3F31B"/>',
                '<path d="M455 196H584L604 199L624 205L645 215L660 225L673 236L686 249L697 264L707 281L715 301L720 321L722 336V362L719 382L713 403L702 426L690 443L678 456L670 464L654 476L636 486L621 492L601 497L588 499H472L455 496L435 490L419 482L405 473L392 462L382 452L372 439L363 424L355 407L349 388L346 373L345 364V337L348 318L353 303L359 292L363 289L372 290L384 296L394 305L400 312L406 324L407 328L408 364L411 379L417 394L425 406L434 416L444 424L459 432L472 436L490 438H564L584 437L601 433L618 425L630 416L640 406L650 391L656 377L659 364L660 357V340L657 324L651 308L643 295L632 283L623 275L610 267L594 261L585 259L576 258L502 257L485 232L474 219L454 199L455 196Z" fill="black"/>',
                '<path d="M262 196H371L388 199L409 206L428 216L439 224L449 233L461 245L473 262L483 280L490 298L495 318L497 337V350L495 369L491 385L483 401L479 404H472L460 399L450 391L442 382L437 372L435 361V336L433 321L429 309L423 297L413 284L402 274L387 265L372 260L358 258H269L250 261L234 267L224 273L214 281L203 292L194 306L188 320L185 332L184 339V358L187 373L193 389L202 403L211 413L220 421L233 429L249 435L259 437L272 438L339 439L346 448L358 465L370 479L382 491L388 496V499L386 500L255 499L233 495L217 490L199 482L185 473L175 465L165 456L155 445L144 429L134 410L128 393L124 377L122 361V335L125 315L131 294L142 271L150 259L161 245L173 233L189 221L204 212L223 204L241 199L262 196Z" fill="black"/>',
                "</g>",
                '<text x="220" y="20" class="heading" font-size="32">New Message</text>',
                "</g>",
                '<foreignObject x="50" y="140" width="400" height="200">',
                '<div xmlns="http://www.w3.org/1999/xhtml" style="width: 100%; height: 100%;">',
                '<p style="margin: 0; font-family: Inter, sans-serif; color: #ffffff; font-size: 28px; font-weight: 500; text-align: center;">',
                '"',
                message.content,
                '"',
                "</p></div></foreignObject>",
                '<text x="250" y="380" class="address" font-size="18">From: ',
                _truncateAddress(message.sender),
                "</text>",
                '<text x="250" y="440" class="url" font-size="16">Reply on chainchat.fun</text>',
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
    function _truncateAddress(address addr) internal pure returns (string memory) {
        string memory full = addr.toChecksumHexString();
        return string(
            abi.encodePacked(
                _substring(full, 0, 8), // 0x + first 6 chars
                "...",
                _substring(full, 38, 42) // last 4 chars
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
    function _substring(string memory str, uint256 startIndex, uint256 endIndex)
        internal
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    // ========== OVERRIDES ==========

    function transferFrom(address, address, uint256) public virtual override {
        revert Locked();
    }

    /**
     * @notice Burn a message
     * @param tokenId The token ID of the message to burn
     *
     */
    function _burnToken(uint256 tokenId) internal {
        super._burn(tokenId);
        delete messages[tokenId];
    }

    /**
     * @notice Get the token URI for a message
     * @param tokenId The token ID of the message
     * @return The token URI
     *
     */
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert MessageDoesNotExist();

        Message memory message = messages[tokenId];
        string memory svg = _generateSVG(message);

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
