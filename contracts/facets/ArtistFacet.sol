//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";

contract ArtistFacet {
    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setupArtistProfile(string memory _cid) external returns (uint256, address, string memory, uint256) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibERC721Storage.ERC721Storage storage erc721 = LibERC721Storage.erc721Storage();

        if (msg.sender == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_cid).length == 0) revert ErrorLib.InvalidCid();

        if (aps.artistAddressToArtist[msg.sender].artistAddress != address(0)) {
            revert ErrorLib.ARTIST_ALREADY_REGISTERED();
        }

        uint256 artistId = ++aps.totalArtists;

        aps.artistIdToArtist[artistId] = aps.artistAddressToArtist[msg.sender];
        aps.artistBalance[msg.sender] = 0;

        aps.allArtistIds.push(artistId);

        // Generate new token ID and mint

        uint256 tokenId = ++erc721.currentTokenId;
        aps.tokenCounter = tokenId; // sync app storage counter
        string memory tokenURI = string(abi.encodePacked("ipfs://", _cid));
        LibERC721Storage.mint(msg.sender, tokenId, tokenURI);
        LibERC721Storage.setTokenArtist(tokenId, msg.sender);

        emit Transfer(address(0), msg.sender, tokenId);

        // Setup Royalty Splitter contract for this artist + token
        address splitter = LibRoyaltySplitterFactory.createRoyaltySplitter(
            msg.sender,
            aps.platFormAddress,
            aps.artistRoyaltyFee,
            aps.platformRoyaltyFee,
            LibAppStorage.MAX_ROYALTY_BONUS
        );
        LibERC721Storage.setTokenRoyaltyReceiver(tokenId, splitter);

        LibAppStorage.Artist storage newArtist = aps.artistAddressToArtist[msg.sender];
        newArtist.artistId = artistId;
        newArtist.artistTokenId = tokenId;
        newArtist.isRegistered = true;
        newArtist.artistCid = _cid;
        newArtist.artistAddress = msg.sender;

        aps.isArtistToken[tokenId] = true;

        emit LibAppStorage.ArtistRegistered(artistId, msg.sender, _cid, tokenId);

        return (artistId, msg.sender, _cid, tokenId);
    }

    function updateArtistProfile(string memory _cid) external returns (uint256, address, string memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        if (msg.sender == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_cid).length == 0) revert ErrorLib.InvalidCid();

        LibAppStorage.Artist storage artist = aps.artistAddressToArtist[msg.sender];
        if (artist.artistAddress == address(0)) revert ErrorLib.ARTIST_NOT_FOUND();

        // Update artist info in mappings
        artist.artistCid = _cid;
        aps.artistIdToArtist[artist.artistId].artistCid = _cid;

        // Update the metadata URI
        string memory tokenURI = string(abi.encodePacked("ipfs://", _cid));

        // Use library directly instead of facet call
        LibERC721Storage.setTokenURI(artist.artistTokenId, tokenURI);

        emit LibAppStorage.ArtistUpdated(artist.artistId, msg.sender, artist.artistTokenId, _cid);

        return (artist.artistId, msg.sender, _cid);
    }

    function getArtistInfo(address artist) external view returns (LibAppStorage.Artist memory) {
        return LibAppStorage.appStorage().artistAddressToArtist[artist];
    }

    function getArtistBalance(address artist) external view returns (uint256) {
        return LibAppStorage.appStorage().artistBalance[artist];
    }

    function getArtistInfoById(uint256 artistId) external view returns (LibAppStorage.Artist memory) {
        return LibAppStorage.appStorage().artistIdToArtist[artistId];
    }

    function isArtistTokenConfirm(uint256 tokenId) external view returns (bool) {
        return LibAppStorage.appStorage().isArtistToken[tokenId];
    }
}
