// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice All domain types for the app can live here or in a separate Types lib.
library LibAppStorage {

    //Artist
    struct Artist {
        uint256 artistId;
        address artistAddress;
        string artistCid;
        uint256 artistTokenId;
        bool isRegistered;
        uint256[] songTokenIds;

    }

    //Song
    struct Song {
        uint256 songId;
        address artistAddress;
        string songCID;
        uint256 totalStreams;
        uint256 totalLikes;
        uint256 createdAt;
    }

    //Album
    struct Album {
        uint256 albumId;
        string albumCID;
        address artistAddress;
        uint256[] songIds;
        bool published;
        uint256 createdAt;
        uint256 publishedAt;
    }

    //User
    struct Streamer {
        uint256 streamId;
        address streamerAddress;
        string cid;
        uint256 balance;
    }
   

    /// @dev Application-wide storage (separate from Diamond's selector/owner storage).
    struct AppStorage {
        // App-specific fields
        address owner;
        uint256 tokenCounter;
        uint256 totalArtists;
        uint256[] allArtistIds;
        mapping(address => Artist) artistAddressToArtist;
        mapping(uint256 => Artist) artistIdToArtist;
        mapping(address => uint256) artistBalance; //Artist Address to Balance
        mapping(uint256 => bool) isArtistToken; // true if token represents artist, false if song


        //Song
        uint256 totalSongs;
        uint256[] allSongIds;
        mapping(address => uint256[]) artistToSongIds; //ArtistToArray of songs
        mapping(uint256 => Song) songIdToSong; //Song Id to Song Struct.
        
        //ALBUM
        mapping(uint256 => Album) albums;
        mapping(address => uint256[]) artistToAlbum;
        uint256 totalAlbum;
        uint256[] allAlbums;
        //USER
        uint256 totalStreamers;
        mapping(address => Streamer) streamers;
        mapping(uint256 => Streamer) streamerIdToStreamer;

    }

    /// @dev Unique slot for AppStorage.
    bytes32 internal constant APP_STORAGE_POSITION = keccak256("audioblocks.app.storage.v1");

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
