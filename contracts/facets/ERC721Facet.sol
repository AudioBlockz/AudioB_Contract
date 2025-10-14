//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC2981} from "../interfaces/IERC2981.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";

contract ERC721Facet is IERC721, IERC2981 {
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    modifier onlyTokenExists(uint256 tokenId) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        _;
    }

    function name() external view returns (string memory) {
        return LibERC721Storage.erc721Storage().name;
    }

    function symbol() external view returns (string memory) {
        return LibERC721Storage.erc721Storage().symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "ERC721: URI query for nonexistent token");
        return LibERC721Storage.erc721Storage().tokenURIs[tokenId];
    }

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return LibERC721Storage.erc721Storage().balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = LibERC721Storage.erc721Storage().owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = this.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || this.isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    function mint(address to, uint256 tokenId, string memory uri) external {
        LibERC721Storage.mint(to, tokenId, uri);
        emit Transfer(address(0), to, tokenId);
    }

    //  Mint and set artist address
    function mintWithRoyalty(address to, string memory uri) external {
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();
        uint256 tokenId = ++es.currentTokenId;

        LibERC721Storage.mint(to, tokenId, uri);
        LibERC721Storage.setTokenArtist(tokenId, msg.sender);

        emit Transfer(address(0), to, tokenId);
    }

    // RoyaltyInfo (EIP-2981-like)
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        // For marketplaces that support only one receiver, return artist
        // But for AudioBlocks, we can expose both via custom function

        // address[] memory receivers;
        // uint256[] memory amounts;

        (receiver, royaltyAmount) = LibERC721Storage.royaltyInfo(tokenId, salePrice);

        // EIP-2981 supports only one receiver, so return artist’s part
        // return (receivers[0], amounts[0]);
    }

    // Custom getter to return both splits for your backend
    function fullRoyaltyBreakdown(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address[] memory receivers, uint256[] memory amounts)
    {
        return LibERC721Storage.royaltyFullInfo(tokenId, salePrice);
    }

    function setTokenURI(uint256 tokenId, string memory uri) external {
        LibERC721Storage.setTokenURI(tokenId, uri);
    }

    function getApproved(uint256 tokenId) external view override onlyTokenExists(tokenId) returns (address) {
        return LibERC721Storage.erc721Storage().tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721: approve to caller");
        LibERC721Storage.erc721Storage().operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return LibERC721Storage.erc721Storage().operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    // Internal functions
    function _exists(uint256 tokenId) internal view returns (bool) {
        return LibERC721Storage.erc721Storage().owners[tokenId] != address(0);
    }

    function _approve(address to, uint256 tokenId) internal {
        LibERC721Storage.erc721Storage().tokenApprovals[tokenId] = to;
        emit Approval(this.ownerOf(tokenId), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = this.ownerOf(tokenId);
        return (spender == owner || this.getApproved(tokenId) == spender || this.isApprovedForAll(owner, spender));
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(this.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _approve(address(0), tokenId);

        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();
        es.balances[from] -= 1;
        es.balances[to] += 1;
        es.owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private
        returns (bool)
    {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
