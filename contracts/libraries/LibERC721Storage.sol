//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "./LibAppStorage.sol";

library LibERC721Storage {
    bytes32 constant ERC721_STORAGE_POSITION = keccak256("audioblocks.diamond.standard.erc721.storage.royalty");

    // Token Mapping for Royalties
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction; // e.g. 500 = 5%
    }

    struct ERC721Storage {
        // Token name
        string name;
        // Token symbol
        string symbol;
        // Mapping from token ID to owner address
        mapping(uint256 => address) owners;
        // Mapping owner address to token count
        mapping(address => uint256) balances;
        // Mapping from token ID to approved address
        mapping(uint256 => address) tokenApprovals;
        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) operatorApprovals;
        // Counter for token IDs
        uint256 currentTokenId;
        // Mapping from token ID to token URI
        mapping(uint256 => string) tokenURIs;
        // Royalty information Mapping
        mapping(uint256 => address) tokenRoyaltyReceivers; // <== NEW: tokenId → splitter contract
        mapping(uint256 => address) artists; // each token's artist
        RoyaltyInfo platformRoyalty; // platform receiver + %
        uint96 artistRoyaltyFraction; // artist % (e.g. 900 = 9%)
    }

    function erc721Storage() internal pure returns (ERC721Storage storage es) {
        bytes32 position = ERC721_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }

    // ---------------------------------
    // Royalty Management Functions
    // ---------------------------------

    function setTokenRoyaltyReceiver(uint256 tokenId, address receiver) internal {
        ERC721Storage storage es = erc721Storage();
        require(receiver != address(0), "Invalid receiver");
        require(exists(tokenId), "Nonexistent token");

        es.tokenRoyaltyReceivers[tokenId] = receiver;
    }

    // Set global platform royalty share
    function setPlatformRoyalty(address receiver, uint96 feeNumerator) internal {
        require(receiver != address(0), "Invalid receiver");
        require(feeNumerator <= LibAppStorage.MAX_ROYALTY_BONUS, "Fee too high");
        ERC721Storage storage es = erc721Storage();
        es.platformRoyalty = RoyaltyInfo(receiver, feeNumerator);
    }

    // Set artist royalty share (the rest of the split)
    function setArtistRoyaltyFraction(uint96 feeNumerator) internal {
        require(feeNumerator <= LibAppStorage.MAX_ROYALTY_BONUS, "Fee too high");
        ERC721Storage storage es = erc721Storage();
        es.artistRoyaltyFraction = feeNumerator;
    }

    // Register artist on mint
    function setTokenArtist(uint256 tokenId, address artist) internal {
        ERC721Storage storage es = erc721Storage();
        es.artists[tokenId] = artist;
    }

    // Royalty Info (EIP-2981)
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        internal
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        ERC721Storage storage es = erc721Storage();

        address splitter = es.tokenRoyaltyReceivers[tokenId];
        require(splitter != address(0), "Royalty receiver not set");

        // calculate total royalty (artist + platform combined)
        uint256 artistFraction = es.artistRoyaltyFraction;
        uint256 platformFraction = es.platformRoyalty.royaltyFraction;
        uint256 totalFraction = artistFraction + platformFraction;

        royaltyAmount = (salePrice * totalFraction) / 10000;
        receiver = splitter; // splitter handles the internal split
    }

    function getPlatformRoyalty() internal view returns (address receiver, uint96 fraction) {
        ERC721Storage storage es = erc721Storage();
        receiver = es.platformRoyalty.receiver;
        fraction = es.platformRoyalty.royaltyFraction;
    }

    // Royalty Info returns full royalty breakdown details for off-chain use
    function royaltyFullInfo(uint256 tokenId, uint256 salePrice)
        internal
        view
        returns (address[] memory receivers, uint256[] memory amounts)
    {
        ERC721Storage storage es = erc721Storage();
        address artist = es.artists[tokenId];
        require(artist != address(0), "Artist not set");

        // calculate artist + platform royalties
        uint256 artistAmt = (salePrice * es.artistRoyaltyFraction) / 10000;
        uint256 platformAmt = (salePrice * es.platformRoyalty.royaltyFraction) / 10000;

        // create arrays with fixed length 2
        receivers = new address[](2);
        amounts = new uint256[](2);

        receivers[0] = artist;
        amounts[0] = artistAmt;

        receivers[1] = es.platformRoyalty.receiver;
        amounts[1] = platformAmt;
    }

    // Internal mint function - cleaner than cross-facet calls
    function mint(address to, uint256 tokenId, string memory tokenURI) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!exists(tokenId), "ERC721: token already minted");

        ERC721Storage storage es = erc721Storage();

        es.balances[to] += 1;
        es.owners[tokenId] = to;
        es.tokenURIs[tokenId] = tokenURI;

        // Note: Events should be emitted in the calling facet
    }

    function exists(uint256 tokenId) internal view returns (bool) {
        return erc721Storage().owners[tokenId] != address(0);
    }

    function setTokenURI(uint256 tokenId, string memory uri) internal {
        require(exists(tokenId), "ERC721: URI set of nonexistent token");
        erc721Storage().tokenURIs[tokenId] = uri;
    }
}
