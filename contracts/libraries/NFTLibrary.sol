// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library NFTLibrary {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @dev mints an ERC721 token for an album (uses es.currentTokenId)
    function _mintNFT(
        address artist,
        string memory cid,
        LibERC721Storage.ERC721Storage storage es
    ) internal returns (uint256 tokenId) {
        tokenId = ++es.currentTokenId;
        string memory tokenURI = string(abi.encodePacked("ipfs://", cid));
        LibERC721Storage.mint(artist, tokenId, tokenURI);
        LibERC721Storage.setTokenArtist(tokenId, artist);
        emit Transfer(address(0), artist, tokenId);
    }

    /// @dev returns existing splitter or creates and stores a new one in AppStorage
    function _getOrCreateSplitter(
        address artist,
        LibAppStorage.AppStorage storage aps
    ) internal returns (address splitter) {
        splitter = aps.artistRoyaltySplitter[artist];
        if (splitter == address(0)) {
            splitter = LibRoyaltySplitterFactory.createRoyaltySplitter(
                artist,
                aps.platFormAddress,
                aps.artistRoyaltyFee,
                aps.platformRoyaltyFee,
                LibERC721Storage.MAX_ROYALTY_BONUS
            );
            aps.artistRoyaltySplitter[artist] = splitter;
        }
    }
}
