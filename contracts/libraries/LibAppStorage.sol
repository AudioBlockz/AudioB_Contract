// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice All domain types for the app can live here or in a separate Types lib.
library LibAppStorage {
    event ArtistRegistered(
        uint256 indexed artistId, address indexed artistAddress, string artistCid, uint256 indexed artistTokenId
    );
    event ArtistUpdated(
        uint256 indexed artistId, address indexed artistAddress, uint256 indexed artistTokenId, string artistCid
    );

    uint256 public constant MIN_AUCTION_DURATION = 1 minutes;
    uint256 public constant MIN_BID_INCREMENT_BPS = 500; // 5% minimum increment
    uint256 internal constant MARKETPLACE_FEE_BPS = 300; // 3% marketplace fee on sales
    uint96 internal constant MAX_ROYALTY_BONUS = 700; // 7%

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
        uint256 tokenId;
        address artistAddress;
        string songCID; // IPFS CID for metadata
        address royaltyReceiver;
        uint256 createdAt;
    }

    //Album
    struct Album {
        uint256 albumId;
        uint256 tokenId;
        string albumCID;
        address artistAddress;
        uint256[] songIds;
        uint256[] songTokenIds;
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

    // MarketPlace Structs
    struct Listing {
        address seller;
        uint256 price; // wei
        bool active;
        address erc20Address; // address(0) for ETH
    }

    struct Auction {
        address seller;
        address erc20TokenAddress;
        uint256 reservePrice;
        uint256 endTime; // timestamp
        address highestBidder;
        uint256 highestBid;
        bool settled;
    }

    /// @dev Application-wide storage (separate from Diamond's selector/owner storage).
    struct AppStorage {
        // App-specific fields
        address platFormAddress;
        uint96 platformRoyaltyFee; // 200 = 2%
        uint96 artistRoyaltyFee; // 500 = 5%
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
        mapping(address => uint256[]) artistToSongIds; //Artist To Array of songs
        mapping(uint256 => Song) songIdToSong; //Song Id to Song Struct.
        //ALBUM
        mapping(uint256 => Album) albums;
        mapping(address => uint256[]) artistToAlbum; //Track all albums per artist
        uint256 totalAlbums;
        uint256[] allAlbums;
        //USER
        uint256 totalStreamers;
        mapping(address => Streamer) streamers;
        mapping(uint256 => Streamer) streamerIdToStreamer;
        // Royalty Splitter contracts per artist
        mapping(address => address) artistRoyaltySplitter; // artist address → splitter contract address
        // MarketPlace Mappings
        // mappings (tokenId => ...)
        mapping(uint256 => Listing) listings; // TokenId => Listing
        mapping(uint256 => Auction) auctions; // TokenId => Auction
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
