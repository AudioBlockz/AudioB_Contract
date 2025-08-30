// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibERC721Storage {
    struct ERC721Layout {
        string name;
        string symbol;
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        mapping(uint256 => string) tokenURIs;
        uint256 tokenIdCounter;

        // EIP-2981 royalty info
        // royaltyReceiver and royaltyFraction are per-token in this simple model,
        // you can also implement a global default + per-token override.
        mapping(uint256 => address) royaltyReceiver;
        mapping(uint256 => uint96) royaltyFraction; // in basis points (parts per 10,000)
        uint96 royaltyDenominator; // normally 10000
    }

    // Unique slot — change if creating additional independent collections
    bytes32 internal constant STORAGE_SLOT = keccak256("audioblocks.erc721.storage.v1");

    function s() internal pure returns (ERC721Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
