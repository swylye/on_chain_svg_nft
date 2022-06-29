// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract RandomSVG is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    bytes32 keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint64 s_subscriptionId;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256 public s_requestId;
    uint256 public tokenCounter;
    uint256 public maxPathCount;
    uint256 public minPathCount;
    uint256 public maxPathCommandCount;
    uint256 public size;
    string[] public colors;
    VRFCoordinatorV2Interface COORDINATOR;

    mapping(uint256 => address) internal requestIdToSender;
    mapping(uint256 => uint256) internal requestIdToTokenId;
    mapping(uint256 => uint256) internal tokenIdToRandomness;

    event RequestedRandomSVG(uint256 requestId, uint256 tokenId);
    event CreatedUnfinishedSVG(uint256 tokenId, uint256 randomNumber);
    event CompletedNFTMint(uint256 tokenId, string tokenURI);

    constructor(uint64 _subscriptionId, address _vrfCoordinator)
        ERC721("Random SVG", "rSVGNFT")
        VRFConsumerBaseV2(_vrfCoordinator)
    {
        s_subscriptionId = _subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        tokenCounter = 1;
        size = 500;
        maxPathCount = 10;
        minPathCount = 3;
        maxPathCommandCount = 4;
        colors = [
            "red",
            "blue",
            "green",
            "yellow",
            "black",
            "pink",
            "orange",
            "purple"
        ];
    }

    function create() external returns (uint256) {
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToSender[s_requestId] = msg.sender;
        requestIdToTokenId[s_requestId] = tokenCounter;
        emit RequestedRandomSVG(s_requestId, tokenCounter);
        tokenCounter += 1;
        return s_requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness)
        internal
        override
    {
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdToTokenId[requestId];
        _safeMint(nftOwner, tokenId);
        tokenIdToRandomness[tokenId] = randomness[0];
        emit CreatedUnfinishedSVG(tokenId, randomness[0]);
    }

    function completeMint(uint256 tokenId) external {
        require(
            bytes(tokenURI(tokenId)).length <= 0,
            "Mint already completed!"
        );
        require(tokenCounter > tokenId, "Token not minted yet!");
        require(
            tokenIdToRandomness[tokenId] > 0,
            "Still waiting for random number from Chainlink VRF"
        );

        uint256 randomNumber = tokenIdToRandomness[tokenId];
        string memory svg = _generateSVG(randomNumber);
        string memory imageURI = _svgToImageURI(svg);
        string memory tokenURI = _formatTokenURI(imageURI);
        _setTokenURI(tokenId, tokenURI);
        emit CompletedNFTMint(tokenId, tokenURI);
    }

    function _generateSVG(uint256 randomNumber)
        internal
        view
        returns (string memory finalSVG)
    {
        uint256 numberOfPaths = (randomNumber % (maxPathCount - minPathCount)) +
            1 +
            minPathCount;
        finalSVG = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' height='",
                uint2str(size),
                "' width='",
                uint2str(size),
                "'>"
            )
        );
        for (uint256 i = 0; i < numberOfPaths; i++) {
            uint256 newRNG = uint256(keccak256(abi.encode(randomNumber, i)));
            string memory pathSVG = _generatePath(newRNG);
            finalSVG = string(abi.encodePacked(finalSVG, pathSVG));
        }
        finalSVG = string(abi.encodePacked(finalSVG, "</svg>"));
        return finalSVG;
    }

    function _generatePath(uint256 randomNumber)
        internal
        view
        returns (string memory pathSVG)
    {
        uint256 numberOfPathCommands = (randomNumber % maxPathCommandCount) + 1;
        pathSVG = "<path d='";
        for (uint256 i = 0; i < numberOfPathCommands; i++) {
            uint256 newRNG = uint256(
                keccak256(abi.encode(randomNumber, size + i))
            );
            string memory pathCommand;
            if (i == 0) {
                pathCommand = _generatePathCommand(newRNG, true);
            } else {
                pathCommand = _generatePathCommand(newRNG, false);
            }
            pathSVG = string(abi.encodePacked(pathSVG, pathCommand));
        }
        string memory color = colors[randomNumber % colors.length];
        pathSVG = string(
            abi.encodePacked(
                pathSVG,
                "' fill='transparent' stroke-width='3' stroke='",
                color,
                "'/>"
            )
        );
        return pathSVG;
    }

    function _generatePathCommand(uint256 randomNumber, bool first)
        internal
        view
        returns (string memory pathCommand)
    {
        if (first) {
            pathCommand = "M";
        } else {
            pathCommand = "L";
        }
        uint256 param1 = (uint256(
            keccak256(abi.encode(randomNumber, size * 3))
        ) % size) + 1;
        uint256 param2 = (uint256(
            keccak256(abi.encode(randomNumber, size * 4))
        ) % size) + 1;
        pathCommand = string(
            abi.encodePacked(
                pathCommand,
                uint2str(param1),
                " ",
                uint2str(param2)
            )
        );
    }

    function _svgToImageURI(string memory svg)
        internal
        pure
        returns (string memory)
    {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(svg)))
        );
        string memory imageURI = string(
            abi.encodePacked(baseURL, svgBase64Encoded)
        );
        return imageURI;
    }

    function _formatTokenURI(string memory imageURI)
        internal
        pure
        returns (string memory)
    {
        string memory baseURL = "data:application/json;base64,";
        string memory tokenURL = Base64.encode(
            bytes(
                abi.encodePacked(
                    '{"name":"Random SVG NFT", "description": "An randomly created SVG NFT using Chainlink VRF", "attributes": "", "image": "',
                    imageURI,
                    '"}'
                )
            )
        );
        string memory tokenURI = string(abi.encodePacked(baseURL, tokenURL));
        return tokenURI;
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
