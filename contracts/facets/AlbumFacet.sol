//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";

contract AlbumFacet {

    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    event AlbumPublishedSuccessfully(
        uint256 indexed albumId,
        address indexed artist,
        string albumCID
    );

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event SongUploadedSuccessfully(uint256 indexed songId, uint256 indexed tokenId, address indexed artist, string songCid);

    function publishAlbum(
        string memory _albumCID,
        uint256[] memory existingSongIds
    ) external returns (uint256 albumId, address artist, string memory albumCID, uint256 createdAt) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        artist = msg.sender;
        albumCID = _albumCID;
        createdAt = block.timestamp;

        if (artist == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(albumCID).length == 0) revert ErrorLib.InvalidCid();
        if (!aps.artistAddressToArtist[artist].isRegistered)
            revert ErrorLib.ARTIST_NOT_REGISTERED();

        uint256 totalExisting = existingSongIds.length;
        if (totalExisting == 0) revert ErrorLib.InvalidArrayLength();

        albumId = ++aps.totalAlbums;

        uint256[] memory allSongs = new uint256[](totalExisting);

        //  Validate and copy songIds (split logic to private helper)
        _validateAndCopySongs(existingSongIds, allSongs, artist, aps);

        //  Save album
        LibAppStorage.Album storage album = aps.albums[albumId];
        album.albumId = albumId;
        album.albumCID = albumCID;
        album.artistAddress = artist;
        album.songIds = allSongs;
        album.published = true;
        album.createdAt = createdAt;
        album.publishedAt = createdAt;

        aps.artistToAlbum[artist].push(albumId);
        aps.allAlbums.push(albumId);

        emit AlbumPublishedSuccessfully(albumId, artist, albumCID);

        return (albumId, artist, albumCID, createdAt);
    }

    function _validateAndCopySongs(
        uint256[] memory existingSongIds,
        uint256[] memory allSongs,
        address artist,
        LibAppStorage.AppStorage storage aps
    ) private view {
        uint256 total = existingSongIds.length;
        for (uint256 i = 0; i < total; i++) {
            uint256 songId = existingSongIds[i];
            LibAppStorage.Song storage song = aps.songIdToSong[songId];
            if (song.songId == 0) revert ErrorLib.SONG_NOT_FOUND();
            if (song.artistAddress != artist) revert ErrorLib.NOT_SONG_OWNER();
            allSongs[i] = songId;
        }
    }


    /// @notice Return album details
    function getAlbum(uint256 albumId) external view returns (LibAppStorage.Album memory) {
        return LibAppStorage.appStorage().albums[albumId];
    }

    /// @notice Return albums owned by an artist
    function getAlbumsByArtist(address artist) external view returns (uint256[] memory) {
        return LibAppStorage.appStorage().artistToAlbum[artist];
    }



}