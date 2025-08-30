//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";

import {ERC721Facet} from "./ERC721Facet.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";


contract SongFacet {

    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    function addNewSong(
        address _artistAddress,
        string memory _songCID
    ) external returns (uint256, address, string memory, uint256) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        if (_artistAddress == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_songCID).length == 0) revert ErrorLib.InvalidCid();
        if (
            aps.artistAddressToArtist[_artistAddress].artistAddress ==
            address(0)
        ) revert ErrorLib.ARTIST_NOT_REGISTERED();

        uint256 songId = ++aps.totalSongs;

        LibAppStorage.Song memory newSong = LibAppStorage.Song({
            songId: songId,
            artistAddress: _artistAddress,
            songCID: _songCID,
            totalStreams: 0,
            totalLikes: 0,
            createdAt: block.timestamp
        });
        aps.artistToSongIds[_artistAddress].push(songId);
        aps.songIdToSong[songId] = newSong;
        aps.allSongIds.push(songId);
        // Mint NFT to represent the song
        // The NFT metadata will point to the song details stored on IPFS
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();

        // Generate new token ID
        uint256 tokenId = ++es.currentTokenId;
        string memory tokenURI = string(abi.encodePacked("ipfs://", _songCID));

        
        // Mint NFT to artist
        LibERC721Storage.mint(msg.sender, tokenId, tokenURI);

        return (songId, _artistAddress, _songCID, block.timestamp);
    }

    function getSongInfo(uint256 songId) external view returns (LibAppStorage.Song memory) {
        require(LibAppStorage.appStorage().songIdToSong[songId].artistAddress != address(0), "Song does not exist");
        return LibAppStorage.appStorage().songIdToSong[songId];
    }

    function getArtistSongs(address artist) external view returns (uint256[] memory) {
        return LibAppStorage.appStorage().artistToSongIds[artist];
    }

    function isArtistToken(uint256 tokenId) external view returns (bool) {
        return LibAppStorage.appStorage().isArtistToken[tokenId];
    }

}