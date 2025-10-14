//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";
import {NFTLibrary} from "../libraries/NFTLibrary.sol";

contract AlbumFacet {
    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    event AlbumPublishedSuccessfully(uint256 indexed albumId, address indexed artist, string albumCID);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event SongUploadedSuccessfully(
        uint256 indexed songId, uint256 indexed tokenId, address indexed artist, string songCid
    );
    event SongAddedToAlbum(uint256 indexed albumId, uint256 indexed songId);
    event SongRemovedFromAlbum(uint256 indexed albumId, uint256 indexed songId);
    event AlbumSongsUpdated(uint256 indexed albumId, uint256[] songIds);
    event AlbumMetadataUpdated(uint256 indexed albumId, string newCid);
    event AlbumDestroyed(uint256 indexed albumId, address indexed artist);

    function publishAlbum(string memory _albumCID, uint256[] memory existingSongIds)
        external
        returns (uint256 albumId, address artist, string memory albumCID, uint256 createdAt)
    {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();

        artist = msg.sender;
        albumCID = _albumCID;
        createdAt = block.timestamp;

        if (artist == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(albumCID).length == 0) revert ErrorLib.InvalidCid();
        if (!aps.artistAddressToArtist[artist].isRegistered) {
            revert ErrorLib.ARTIST_NOT_REGISTERED();
        }

        uint256 totalExisting = existingSongIds.length;
        if (totalExisting == 0) revert ErrorLib.InvalidArrayLength();

        uint256 tokenId = NFTLibrary._mintNFT(artist, albumCID, es); // Mint NFT to represent the album

        address splitter = NFTLibrary._getOrCreateSplitter(artist, aps); // Ensure splitter exists for artist

        //  Link royalty receiver to token
        LibERC721Storage.setTokenRoyaltyReceiver(tokenId, splitter);

        albumId = ++aps.totalAlbums;

        uint256[] memory allSongs = new uint256[](totalExisting);

        //  Validate and copy songIds (split logic to private helper)
        _validateAndCopySongs(existingSongIds, allSongs, artist, aps);

        //  Save album
        LibAppStorage.Album storage album = aps.albums[albumId];
        album.albumId = albumId;
        album.tokenId = tokenId;
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

    function updateAlbumMetaData(uint256 albumId, string memory newCid) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Album storage album = aps.albums[albumId];

        if (!_albumExists(albumId, aps)) revert ErrorLib.ALBUM_NOT_FOUND();
        if (album.artistAddress != msg.sender) revert ErrorLib.NOT_ALBUM_OWNER();
        if (bytes(newCid).length == 0) revert ErrorLib.InvalidCid();

        album.albumCID = newCid;

        emit AlbumMetadataUpdated(albumId, newCid);
    }

    function updateAlbumSongs(uint256 albumId, uint256[] memory newSongIds) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Album storage album = aps.albums[albumId];

        if (album.albumId == 0) revert ErrorLib.ALBUM_NOT_FOUND();
        if (album.artistAddress != msg.sender) revert ErrorLib.NOT_ALBUM_OWNER();

        uint256 totalNew = newSongIds.length;
        if (totalNew == 0) revert ErrorLib.InvalidArrayLength();

        uint256[] memory allSongs = new uint256[](totalNew);

        //  Validate and copy songIds (split logic to private helper)
        _validateAndCopySongs(newSongIds, allSongs, msg.sender, aps);

        album.songIds = allSongs;
        for (uint256 i = 0; i < allSongs.length; i++) {
            emit SongAddedToAlbum(albumId, allSongs[i]);
        }
        emit AlbumSongsUpdated(albumId, allSongs);
    }

    function removeSongFromAlbum(uint256 albumId, uint256 songId) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Album storage album = aps.albums[albumId];

        if (album.albumId == 0) revert ErrorLib.ALBUM_NOT_FOUND();
        if (album.artistAddress != msg.sender) revert ErrorLib.NOT_ALBUM_OWNER();

        uint256 total = album.songIds.length;
        for (uint256 i = 0; i < total; i++) {
            if (album.songIds[i] == songId) {
                album.songIds[i] = album.songIds[total - 1];
                album.songIds.pop();
                break;
            }
        }

        emit SongRemovedFromAlbum(albumId, songId);
    }

    function destroyAlbum(uint256 albumId) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Album storage album = aps.albums[albumId];

        if (album.albumId == 0) revert ErrorLib.ALBUM_NOT_FOUND();
        if (album.artistAddress != msg.sender) revert ErrorLib.NOT_ALBUM_OWNER();

        //  Delete album
        delete aps.albums[albumId];

        //  Remove from artistToAlbum mapping
        uint256[] storage artistAlbums = aps.artistToAlbum[msg.sender];
        uint256 total = artistAlbums.length;
        for (uint256 i = 0; i < total; i++) {
            if (artistAlbums[i] == albumId) {
                artistAlbums[i] = artistAlbums[total - 1];
                artistAlbums.pop();
                break;
            }
        }

        //  Remove from allAlbums array
        uint256[] storage allAlbums = aps.allAlbums;
        total = allAlbums.length;
        for (uint256 i = 0; i < total; i++) {
            if (allAlbums[i] == albumId) {
                allAlbums[i] = allAlbums[total - 1];
                allAlbums.pop();
                break;
            }
        }

        emit AlbumDestroyed(albumId, msg.sender);
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

    function _albumExists(uint256 albumId, LibAppStorage.AppStorage storage aps) private view returns (bool) {
        return aps.albums[albumId].albumId != 0;
    }

    /// @notice Return album details
    function getAlbum(uint256 albumId) external view returns (LibAppStorage.Album memory) {
        return LibAppStorage.appStorage().albums[albumId];
    }

    function getAlbums() external view returns (uint256[] memory) {
        return LibAppStorage.appStorage().allAlbums;
    }

    /// @notice Return albums owned by an artist
    function getAlbumsByArtist(address artist) external view returns (uint256[] memory) {
        return LibAppStorage.appStorage().artistToAlbum[artist];
    }
}
