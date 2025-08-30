// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibERC721} from "../libraries/LibERC721.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract NFTFacet is ERC165, IERC721, IERC721Metadata, IERC2981 {
    // Expose read methods
    function name() external view override returns (string memory) {
        return LibERC721.name();
    }

    function symbol() external view override returns (string memory) {
        return LibERC721.symbol();
    }

    function balanceOf(address owner) external view override returns (uint256) {
        return LibERC721.balanceOf(owner);
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        return LibERC721.ownerOf(tokenId);
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        return LibERC721.tokenURI(tokenId);
    }

    // Minting (internal access control recommended)
    function mintWithRoyalty(address to, string calldata uri, address royaltyReceiver, uint96 bps) external returns (uint256) {
        // Add access control (only facets you trust should call this). Example: check diamond owner
        uint256 tokenId = LibERC721._mintWithRoyalty(to, uri, royaltyReceiver, bps);
        return tokenId;
    }

    function mint(address to, string calldata uri) external returns (uint256) {
        uint256 tokenId = LibERC721._mint(to, uri);
        return tokenId;
    }

    // Approve / Transfer
    function approve(address to, uint256 tokenId) external override {
        LibERC721.approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        return LibERC721.getApproved(tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external override {
        LibERC721.setApprovalForAll(operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return LibERC721.isApprovedForAll(owner, operator);
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        LibERC721.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        LibERC721.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external override {
        LibERC721.safeTransferFrom(from, to, tokenId, data);
    }

    // EIP-2981
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address, uint256) {
        return LibERC721.royaltyInfo(tokenId, salePrice);
    }

    // ERC165 support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return LibERC721.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }

    // Optional administrative setup: set name & symbol once (callable by owner)
    function initializeMetadata(string calldata _name, string calldata _symbol) external {
        // enforce owner access: use LibDiamond.enforceIsContractOwner();
        LibERC721._setNameSymbol(_name, _symbol);
    }
}
