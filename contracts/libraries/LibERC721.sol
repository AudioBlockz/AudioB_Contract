// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibERC721Storage} from "./LibERC721Storage.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

library LibERC721 {
    using Address for address;

    // EVENTS (mirror OZ)
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // -----------------------
    // Read helpers
    // -----------------------
    function name() internal view returns (string memory) {
        return LibERC721Storage.s().name;
    }

    function symbol() internal view returns (string memory) {
        return LibERC721Storage.s().symbol;
    }

    function balanceOf(address owner) internal view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return LibERC721Storage.s().balances[owner];
    }

    function ownerOf(uint256 tokenId) internal view returns (address) {
        address owner = LibERC721Storage.s().owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function tokenURI(uint256 tokenId) internal view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return LibERC721Storage.s().tokenURIs[tokenId];
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return LibERC721Storage.s().owners[tokenId] != address(0);
    }

    // -----------------------
    // Minting
    // -----------------------
    function _mint(address to, string memory uri) internal returns (uint256) {
        require(to != address(0), "ERC721: mint to the zero address");

        LibERC721Storage.ERC721Layout storage es = LibERC721Storage.s();
        uint256 tokenId = ++es.tokenIdCounter;

        require(es.owners[tokenId] == address(0), "ERC721: token already minted");

        es.balances[to] += 1;
        es.owners[tokenId] = to;
        es.tokenURIs[tokenId] = uri;

        emit Transfer(address(0), to, tokenId);

        return tokenId;
    }

    // Mint with royalty
    function _mintWithRoyalty(address to, string memory uri, address royaltyReceiver, uint96 fractionBps) internal returns (uint256) {
        uint256 tokenId = _mint(to, uri);
        if (royaltyReceiver != address(0) && fractionBps > 0) {
            LibERC721Storage.ERC721Layout storage es = LibERC721Storage.s();
            es.royaltyReceiver[tokenId] = royaltyReceiver;
            es.royaltyFraction[tokenId] = fractionBps;
            if (es.royaltyDenominator == 0) es.royaltyDenominator = 10000;
        }
        return tokenId;
    }

    // -----------------------
    // Approvals & Transfers
    // -----------------------
    function approve(address to, uint256 tokenId) internal {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "ERC721: approve caller is not owner nor approved for all");

        LibERC721Storage.s().tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) internal view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return LibERC721Storage.s().tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) internal {
        LibERC721Storage.s().operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) internal view returns (bool) {
        return LibERC721Storage.s().operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) internal {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) internal {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        LibERC721Storage.ERC721Layout storage es = LibERC721Storage.s();

        // Clear approvals
        if (es.tokenApprovals[tokenId] != address(0)) {
            delete es.tokenApprovals[tokenId];
        }

        es.balances[from] -= 1;
        es.balances[to] += 1;
        es.owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    // safeTransfer convenience
    function safeTransferFrom(address from, address to, uint256 tokenId) internal {
        safeTransferFrom(from, to, tokenId, "");
    }

    // Check on ERC721Receiver
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns (bool) {
        if (!to.isContract()) {
            return true;
        }
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
    }

    // -----------------------
    // Metadata setters (internal helpers)
    // -----------------------
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        LibERC721Storage.s().tokenURIs[tokenId] = uri;
    }

    function _setNameSymbol(string memory _name, string memory _symbol) internal {
        LibERC721Storage.ERC721Layout storage es = LibERC721Storage.s();
        es.name = _name;
        es.symbol = _symbol;
    }

    // -----------------------
    // EIP-2981 Royalties
    // -----------------------
    // Returns (receiver, royaltyAmount) for a sale price
    function royaltyInfo(uint256 tokenId, uint256 salePrice) internal view returns (address, uint256) {
        LibERC721Storage.ERC721Layout storage es = LibERC721Storage.s();
        address receiver = es.royaltyReceiver[tokenId];
        uint96 fraction = es.royaltyFraction[tokenId];
        uint96 denom = es.royaltyDenominator == 0 ? 10000 : es.royaltyDenominator;
        if (receiver == address(0) || fraction == 0) {
            return (address(0), 0);
        }
        uint256 royaltyAmount = (salePrice * fraction) / denom;
        return (receiver, royaltyAmount);
    }

    // EIP-165 interfaces
    function supportsInterface(bytes4 interfaceId) internal pure returns (bool) {
        // IERC165 (0x01ffc9a7), IERC721 (0x80ac58cd), IERC721Metadata (0x5b5e139f), IERC2981 (0x2a55205a)
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
