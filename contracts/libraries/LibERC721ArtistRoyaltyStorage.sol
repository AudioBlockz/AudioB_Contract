//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibERC721ArtistRoyaltyStorage {
    bytes32 constant ERC721_STORAGE_POSITION = keccak256("audioblocks.diamond.standard.erc721.storage.artist.royalty");
    uint256 internal constant MAX_ROYALTY_BONUS = 500; // 5%

    // Optional mapping for token royalties
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
        mapping(uint256 => address) artists;
        mapping(uint256 => RoyaltyInfo) royalties;
        RoyaltyInfo defaultRoyalty;
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
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) internal {
        ERC721Storage storage es = erc721Storage();
        require(feeNumerator <= MAX_ROYALTY_BONUS, "Fee too high");
        es.royalties[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) internal {
        require(feeNumerator <= MAX_ROYALTY_BONUS, "Fee too high");
        require(receiver != address(0), "Invalid receiver");
        ERC721Storage storage es = erc721Storage();
        es.defaultRoyalty = RoyaltyInfo(receiver, feeNumerator);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) internal view returns (address, uint256) {
        ERC721Storage storage es = erc721Storage();
        RoyaltyInfo memory royalty = es.royalties[tokenId];

        if (royalty.receiver == address(0)) {
            royalty = es.defaultRoyalty;
        }

        uint256 royaltyAmount = (salePrice * royalty.royaltyFraction) / 10000;
        return (royalty.receiver, royaltyAmount);
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
