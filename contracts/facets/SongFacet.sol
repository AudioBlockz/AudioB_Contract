//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";

contract SongFacet {

    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    event SongUploadedSuccessfully(uint256 indexed songId, uint256 indexed tokenId, address indexed artist, string songCid);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);


    // function uploadAndMintSong(
    //     string memory _songCID
    // ) external returns (uint256, address, string memory, uint256) {

    //     LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
    //     LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();
        
    //     if (msg.sender == address(0)) revert ErrorLib.ZeroAddress();
    //     if (bytes(_songCID).length == 0) revert ErrorLib.InvalidCid();
    //     if (
    //         aps.artistAddressToArtist[msg.sender].artistAddress ==
    //         address(0)
    //     ) revert ErrorLib.ARTIST_NOT_REGISTERED();

    //     // Mint NFT to represent the song
    //     // The NFT metadata will point to the song details stored on IPFS
    //     // Generate new token ID
    //     uint256 tokenId = ++es.currentTokenId;
    //     aps.tokenCounter = tokenId; // sync app storage counter
    //     string memory tokenURI = string(abi.encodePacked("ipfs://", _songCID));
    //     // Mint NFT to artist
    //     LibERC721Storage.mint(msg.sender, tokenId, tokenURI);
    //     LibERC721Storage.setTokenArtist(tokenId, msg.sender);
    //     emit Transfer(address(0), msg.sender, tokenId);

    //     address splitter = aps.artistRoyaltySplitter[msg.sender];
    //     bool needSplitterCreation = (splitter == address(0));

    //     if (needSplitterCreation) {
    //         // set up royalty receiver using RoyaltySplitter clone
    //         splitter = LibRoyaltySplitterFactory.createRoyaltySplitter(
    //             msg.sender,
    //             aps.platFormAddress,
    //             aps.artistRoyaltyFee,
    //             aps.platformRoyaltyFee,
    //             LibERC721Storage.MAX_ROYALTY_BONUS
    //         );
            
    //         aps.artistRoyaltySplitter[msg.sender] = splitter; // save for future songs by this artist
    //     } 

    //     LibERC721Storage.setTokenRoyaltyReceiver(tokenId, splitter);


    //     uint256 songId = ++aps.totalSongs;

    //     LibAppStorage.Song memory newSong = LibAppStorage.Song({
    //         songId: songId,
    //         tokenId: tokenId,
    //         artistAddress: msg.sender,
    //         songCID: _songCID,
    //         royaltyReceiver: splitter,
    //         createdAt: block.timestamp
    //     });
    //     aps.artistToSongIds[msg.sender].push(songId);
    //     aps.songIdToSong[songId] = newSong;
    //     aps.allSongIds.push(songId);
        
    //     LibAppStorage.Artist storage artist = aps.artistAddressToArtist[msg.sender];
    //     artist.songTokenIds.push(tokenId);
    //     artist.isRegistered = true;

    //     emit SongUploadedSuccessfully(songId, tokenId, msg.sender, _songCID);
        
    //     return (songId, msg.sender, _songCID, block.timestamp);
    // }


    function uploadAndMintSong(
        string memory _songCID, uint256 _albumId // 0 if no album
    ) external returns (uint256 songId, address artist, string memory songCID, uint256 createdAt) {
        artist = msg.sender;
        songCID = _songCID;
        createdAt = block.timestamp;

        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();

        if (artist == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(songCID).length == 0) revert ErrorLib.InvalidCid();
        if (aps.artistAddressToArtist[artist].artistAddress == address(0))
            revert ErrorLib.ARTIST_NOT_REGISTERED();

        //  Mint Song NFT
        uint256 tokenId = _mintSongNFT(artist, songCID, es);

        //  Setup royalty splitter or reuse existing
        address splitter = _getOrCreateSplitter(artist, aps);

        //  Link royalty receiver to token
        LibERC721Storage.setTokenRoyaltyReceiver(tokenId, splitter);

        //  Register song on-chain
        songId = ++aps.totalSongs;
        _registerSong(aps, songId, tokenId, artist, songCID, splitter);

        // ---------- album linking ----------
        if (_albumId != 0) {
            if (aps.albums[_albumId].artistAddress != artist)
                revert ErrorLib.NOT_SONG_OWNER();
            aps.albums[_albumId].songIds.push(songId);
            aps.albums[_albumId].songTokenIds.push(tokenId);
        }

        emit SongUploadedSuccessfully(songId, tokenId, artist, songCID);
        return (songId, artist, songCID, createdAt);
    }


    // --------------------------------------
    //  Internal Helpers
    // --------------------------------------

    function _mintSongNFT(
        address artist,
        string memory cid,
        LibERC721Storage.ERC721Storage storage es
    ) private returns (uint256 tokenId) {
        tokenId = ++es.currentTokenId;
        string memory tokenURI = string(abi.encodePacked("ipfs://", cid));
        LibERC721Storage.mint(artist, tokenId, tokenURI);
        LibERC721Storage.setTokenArtist(tokenId, artist);
        emit Transfer(address(0), artist, tokenId);
    }


    function _getOrCreateSplitter(
        address artist,
        LibAppStorage.AppStorage storage aps
    ) private returns (address splitter) {
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

    function _registerSong(
        LibAppStorage.AppStorage storage aps,
        uint256 songId,
        uint256 tokenId,
        address artist,
        string memory cid,
        address splitter
    ) private {
        aps.songIdToSong[songId] = LibAppStorage.Song({
            songId: songId,
            tokenId: tokenId,
            artistAddress: artist,
            songCID: cid,
            royaltyReceiver: splitter,
            createdAt: block.timestamp
        });

        aps.artistToSongIds[artist].push(songId);
        aps.allSongIds.push(songId);
        aps.artistAddressToArtist[artist].songTokenIds.push(tokenId);
    }

    function updateSongMetaData(
        uint256 songId,
        string memory newCid
    ) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        if (bytes(newCid).length == 0) revert ErrorLib.InvalidCid();
        if (aps.songIdToSong[songId].artistAddress == address(0))
            revert ErrorLib.SONG_NOT_FOUND();
        if (aps.songIdToSong[songId].artistAddress != msg.sender)
            revert ErrorLib.NOT_SONG_OWNER();

        aps.songIdToSong[songId].songCID = newCid;

        string memory newURI = string(abi.encodePacked("ipfs://", newCid));
        LibERC721Storage.setTokenURI(aps.songIdToSong[songId].tokenId, newURI);

        emit SongUploadedSuccessfully(songId, aps.songIdToSong[songId].tokenId, msg.sender, newCid);

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
