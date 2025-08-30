// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibNFTStorage {
    struct NFTStorage {
        string name;
        string symbol;
        uint256 tokenIdCounter;
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        mapping(uint256 => string) tokenURIs; // songCID / artistCID
    }

    bytes32 constant NFT_STORAGE_POSITION = keccak256("audioblocks.nft.storage");

    function nftStorage() internal pure returns (NFTStorage storage ns) {
        bytes32 position = NFT_STORAGE_POSITION;
        assembly {
            ns.slot := position
        }
    }
}
