// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/OwnershipControlFacet.sol";
import "../contracts/facets/ArtistFacet.sol";
import "../contracts/facets/SongFacet.sol";
import "../contracts/facets/MarketPlaceFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "./helpers/DiamondUtils.sol";
import {LibAppStorage} from "../contracts/libraries/LibAppStorage.sol";
import "../contracts/facets/HelperFacet.sol";
import "../contracts/libraries/ErrorLib.sol";
import "../contracts/RoyaltySplitter.sol" as RSplitter;
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";


import {console} from "forge-std/console.sol";

contract SongFacetTest is Test, IDiamondCut, DiamondUtils {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    RSplitter.RoyaltySplitter royaltySplitter;
    HelperFacet helperFacet;

    address platformFeeAddress = address(0x1);
    address newPlatformFeeAddress = address(0x2);
    uint96 _artistRoyaltyFee = 500; // 5%
    uint96 _platformRoyaltyFee = 100; // 1%

    // Test accounts
    address artist1 = address(0x100);
    address artist2 = address(0x200);
    address artist3 = address(0x300);
    address nonArtist = address(0x400);
    address fan1 = address(0x500);

    // Test data
    string constant ARTIST1_CID = "QmArtist1Profile";
    string constant ARTIST2_CID = "QmArtist2Profile";
    string constant SONG1_CID = "QmSong1Metadata";
    string constant SONG2_CID = "QmSong2Metadata";
    string constant SONG3_CID = "QmSong3Metadata";
    string constant UPDATED_SONG_CID = "QmUpdatedSongMetadata";

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        royaltySplitter = new RSplitter.RoyaltySplitter();

        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            platformFeeAddress,
            _artistRoyaltyFee,
            _platformRoyaltyFee,
            address(royaltySplitter)
        );
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        //Deploy Facets
        ArtistFacet artistFacet = new ArtistFacet();
        MarketPlaceFacet marketPlaceFacet = new MarketPlaceFacet();
        SongFacet songFacet = new SongFacet();
        ERC721Facet erc721Facet = new ERC721Facet();
        OwnershipControlFacet ownershipControlFacet = new OwnershipControlFacet();
        helperFacet = new HelperFacet();

        // build cut struct
        FacetCut[] memory cut = new FacetCut[](8);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(artistFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ArtistFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(marketPlaceFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("MarketPlaceFacet")
            })
        );

        cut[4] = (
            FacetCut({
                facetAddress: address(songFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("SongFacet")
            })
        );

        cut[5] = (
            FacetCut({
                facetAddress: address(erc721Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721Facet")
            })
        );

        cut[6] = (
            FacetCut({
                facetAddress: address(ownershipControlFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipControlFacet")
            })
        );

        cut[7] = (
            FacetCut({
                facetAddress: address(helperFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("HelperFacet")
            })
        );

        // upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        // Setup platform royalty
        OwnershipControlFacet(address(diamond)).setPlatformRoyalty(newPlatformFeeAddress, 200);
        OwnershipControlFacet(address(diamond)).setArtistRoyaltyFraction(500);

        (address _platformReceiver, uint96 _platformFee) = OwnershipControlFacet(address(diamond)).getPlatformRoyalty();

        console.log("Platform Reciever: ", _platformReceiver);
        console.log("Platform Fee: ", _platformFee);

        uint96 newArtistRoyaltyFee = OwnershipControlFacet(address(diamond)).getArtistRoyaltyFraction();
        console.log("Artist Royalty Fee: ", newArtistRoyaltyFee);

        uint256 totalBonus = _platformFee + newArtistRoyaltyFee;

        uint256 MaxBonus = HelperFacet(address(diamond)).getMaxRoyaltyBonus();
        console.log("Max Bonus: ", MaxBonus);

        assertEq(_platformReceiver, newPlatformFeeAddress, "Set Platform Address failed");
        assertEq(_platformFee, 200, "Set Platform fee failed");
        assertEq(newArtistRoyaltyFee, 500, "Set Artist Royalty failed");
        assertEq(MaxBonus, totalBonus, "Max Bonus should be 700");

        // Register test artists
        vm.prank(artist1);
        ArtistFacet(address(diamond)).setupArtistProfile(ARTIST1_CID);

        vm.prank(artist2);
        ArtistFacet(address(diamond)).setupArtistProfile(ARTIST2_CID);

        vm.prank(artist3);
        ArtistFacet(address(diamond)).setupArtistProfile("QmArtist3Profile");
    }

    // ========== uploadAndMintSong Tests ==========

    function testUploadAndMintSong_Success() public {
        uint256 albumId = 0; // No album

        vm.startPrank(artist1);
        (uint256 songId, address artist, string memory songCID, uint256 createdAt) =
            SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, albumId);
        vm.stopPrank();

        // Verify return values
        assertEq(songId, 1, "Song ID should be 1");
        assertEq(artist, artist1, "Artist address should match");
        assertEq(songCID, SONG1_CID, "Song CID should match");
        assertGt(createdAt, 0, "Created timestamp should be set");
        assertEq(createdAt, block.timestamp, "Created timestamp should be current block");

        // Verify song info is stored correctly
        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.songId, songId, "Stored song ID should match");
        assertEq(song.artistAddress, artist1, "Stored artist address should match");
        assertEq(song.songCID, SONG1_CID, "Stored CID should match");
        assertGt(song.tokenId, 0, "Token ID should be set");
        assertEq(song.createdAt, createdAt, "Stored timestamp should match");

        // Verify NFT ownership - song token is the 2nd token (artist token is 1st)
        uint256 songTokenId = song.tokenId;
        assertEq(ERC721Facet(address(diamond)).ownerOf(songTokenId), artist1, "Artist should own song token");

        // Verify tokenURI
        string memory expectedURI = string(abi.encodePacked("ipfs://", SONG1_CID));
        assertEq(ERC721Facet(address(diamond)).tokenURI(songTokenId), expectedURI, "Token URI should be correct");

        // Verify song is NOT marked as artist token
        assertFalse(SongFacet(address(diamond)).isArtistToken(songTokenId), "Song token should not be artist token");

        // Verify royalty receiver is set
        assertTrue(song.royaltyReceiver != address(0), "Royalty receiver should be set");
    }

    function testUploadAndMintSong_MultipleSongsSameArtist() public {
        vm.startPrank(artist1);

        // Upload first song
        (uint256 songId1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Upload second song
        (uint256 songId2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);

        // Upload third song
        (uint256 songId3,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);

        vm.stopPrank();

        // Verify unique song IDs
        assertEq(songId1, 1, "First song ID should be 1");
        assertEq(songId2, 2, "Second song ID should be 2");
        assertEq(songId3, 3, "Third song ID should be 3");

        // Verify all songs belong to artist1
        uint256[] memory artistSongs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(artistSongs.length, 3, "Artist should have 3 songs");
        assertEq(artistSongs[0], songId1, "First song in array should match");
        assertEq(artistSongs[1], songId2, "Second song in array should match");
        assertEq(artistSongs[2], songId3, "Third song in array should match");

        // Verify each song has correct metadata
        LibAppStorage.Song memory song1 = SongFacet(address(diamond)).getSongInfo(songId1);
        LibAppStorage.Song memory song2 = SongFacet(address(diamond)).getSongInfo(songId2);
        LibAppStorage.Song memory song3 = SongFacet(address(diamond)).getSongInfo(songId3);

        assertEq(song1.songCID, SONG1_CID, "Song 1 CID should match");
        assertEq(song2.songCID, SONG2_CID, "Song 2 CID should match");
        assertEq(song3.songCID, SONG3_CID, "Song 3 CID should match");

        // Verify artist owns all tokens
        assertEq(ERC721Facet(address(diamond)).ownerOf(song1.tokenId), artist1, "Artist should own token 1");
        assertEq(ERC721Facet(address(diamond)).ownerOf(song2.tokenId), artist1, "Artist should own token 2");
        assertEq(ERC721Facet(address(diamond)).ownerOf(song3.tokenId), artist1, "Artist should own token 3");
    }

    function testUploadAndMintSong_MultipleSongsDifferentArtists() public {
        // Artist1 uploads 2 songs
        vm.startPrank(artist1);
        (uint256 song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        (uint256 song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        vm.stopPrank();

        // Artist2 uploads 1 song
        vm.startPrank(artist2);
        (uint256 song3,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);
        vm.stopPrank();

        // Verify song IDs are sequential
        assertEq(song1, 1, "First song should be ID 1");
        assertEq(song2, 2, "Second song should be ID 2");
        assertEq(song3, 3, "Third song should be ID 3");

        // Verify artist1 songs
        uint256[] memory artist1Songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(artist1Songs.length, 2, "Artist1 should have 2 songs");

        // Verify artist2 songs
        uint256[] memory artist2Songs = SongFacet(address(diamond)).getArtistSongs(artist2);
        assertEq(artist2Songs.length, 1, "Artist2 should have 1 song");

        // Verify song ownership
        LibAppStorage.Song memory s1 = SongFacet(address(diamond)).getSongInfo(song1);
        LibAppStorage.Song memory s2 = SongFacet(address(diamond)).getSongInfo(song2);
        LibAppStorage.Song memory s3 = SongFacet(address(diamond)).getSongInfo(song3);

        assertEq(s1.artistAddress, artist1, "Song 1 should belong to artist1");
        assertEq(s2.artistAddress, artist1, "Song 2 should belong to artist1");
        assertEq(s3.artistAddress, artist2, "Song 3 should belong to artist2");

        // Verify token ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(s1.tokenId), artist1, "Artist1 owns token 1");
        assertEq(ERC721Facet(address(diamond)).ownerOf(s2.tokenId), artist1, "Artist1 owns token 2");
        assertEq(ERC721Facet(address(diamond)).ownerOf(s3.tokenId), artist2, "Artist2 owns token 3");
    }

    function testUploadAndMintSong_RevertWhen_NotRegisteredArtist() public {
        vm.startPrank(nonArtist);
        vm.expectRevert(); // ErrorLib.ARTIST_NOT_REGISTERED()
        SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        vm.stopPrank();
    }

    function testUploadAndMintSong_RevertWhen_EmptyCID() public {
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.InvalidCid()
        SongFacet(address(diamond)).uploadAndMintSong("", 0);
        vm.stopPrank();
    }

    function testUploadAndMintSong_RevertWhen_InvalidAlbumOwner() public {
        // This test assumes album functionality exists
        // If albums are implemented, this would test that only album owner can add songs
        // For now, we'll skip this or mock it depending on album implementation
    }

    function testUploadAndMintSong_RoyaltySplitterReuse() public {
        vm.startPrank(artist1);

        // Upload first song
        (uint256 songId1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        LibAppStorage.Song memory song1 = SongFacet(address(diamond)).getSongInfo(songId1);
        address splitter1 = song1.royaltyReceiver;

        // Upload second song
        (uint256 songId2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        LibAppStorage.Song memory song2 = SongFacet(address(diamond)).getSongInfo(songId2);
        address splitter2 = song2.royaltyReceiver;

        vm.stopPrank();

        // Both songs should use the same royalty splitter
        assertEq(splitter1, splitter2, "Both songs should share the same royalty splitter");
        assertTrue(splitter1 != address(0), "Royalty splitter should be valid");
    }

    function testUploadAndMintSong_DifferentArtistsDifferentSplitters() public {
        // Artist1 uploads song
        vm.prank(artist1);
        (uint256 songId1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Artist2 uploads song
        vm.prank(artist2);
        (uint256 songId2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);

        LibAppStorage.Song memory song1 = SongFacet(address(diamond)).getSongInfo(songId1);
        LibAppStorage.Song memory song2 = SongFacet(address(diamond)).getSongInfo(songId2);

        // Different artists should have different royalty splitters
        assertTrue(song1.royaltyReceiver != song2.royaltyReceiver, "Different artists should have different splitters");
        assertTrue(song1.royaltyReceiver != address(0), "Artist1 splitter should be valid");
        assertTrue(song2.royaltyReceiver != address(0), "Artist2 splitter should be valid");
    }

    function testUploadAndMintSong_TimestampAccuracy() public {
        uint256 beforeTime = block.timestamp;

        vm.warp(1000000); // Set specific timestamp

        vm.prank(artist1);
        (uint256 songId,,, uint256 createdAt) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        assertEq(createdAt, 1000000, "Timestamp should match block.timestamp");

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.createdAt, 1000000, "Stored timestamp should match");
    }

    // ========== updateSongMetaData Tests ==========

    function testUpdateSongMetaData_Success() public {
        // Upload a song first
        vm.startPrank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Get original token ID
        LibAppStorage.Song memory originalSong = SongFacet(address(diamond)).getSongInfo(songId);
        uint256 tokenId = originalSong.tokenId;

        // Update song metadata
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);
        vm.stopPrank();

        // Verify song CID is updated
        LibAppStorage.Song memory updatedSong = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(updatedSong.songCID, UPDATED_SONG_CID, "Song CID should be updated");

        // Verify token URI is updated
        string memory expectedURI = string(abi.encodePacked("ipfs://", UPDATED_SONG_CID));
        assertEq(ERC721Facet(address(diamond)).tokenURI(tokenId), expectedURI, "Token URI should be updated");

        // Verify other fields remain unchanged
        assertEq(updatedSong.songId, originalSong.songId, "Song ID should not change");
        assertEq(updatedSong.tokenId, originalSong.tokenId, "Token ID should not change");
        assertEq(updatedSong.artistAddress, originalSong.artistAddress, "Artist address should not change");
        assertEq(updatedSong.royaltyReceiver, originalSong.royaltyReceiver, "Royalty receiver should not change");
        assertEq(updatedSong.createdAt, originalSong.createdAt, "Created timestamp should not change");
    }

    function testUpdateSongMetaData_MultipleUpdates() public {
        string memory cid1 = "QmUpdate1";
        string memory cid2 = "QmUpdate2";
        string memory cid3 = "QmUpdate3";

        vm.startPrank(artist1);

        // Upload song
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        uint256 tokenId = SongFacet(address(diamond)).getSongInfo(songId).tokenId;

        // First update
        SongFacet(address(diamond)).updateSongMetaData(songId, cid1);
        assertEq(SongFacet(address(diamond)).getSongInfo(songId).songCID, cid1, "First update should work");

        // Second update
        SongFacet(address(diamond)).updateSongMetaData(songId, cid2);
        assertEq(SongFacet(address(diamond)).getSongInfo(songId).songCID, cid2, "Second update should work");

        // Third update
        SongFacet(address(diamond)).updateSongMetaData(songId, cid3);
        assertEq(SongFacet(address(diamond)).getSongInfo(songId).songCID, cid3, "Third update should work");

        vm.stopPrank();

        // Verify final token URI
        string memory expectedURI = string(abi.encodePacked("ipfs://", cid3));
        assertEq(ERC721Facet(address(diamond)).tokenURI(tokenId), expectedURI, "Token URI should reflect final update");
    }

    function testUpdateSongMetaData_RevertWhen_EmptyCID() public {
        vm.startPrank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        vm.expectRevert(); // ErrorLib.InvalidCid()
        SongFacet(address(diamond)).updateSongMetaData(songId, "");
        vm.stopPrank();
    }

    function testUpdateSongMetaData_RevertWhen_SongNotFound() public {
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.SONG_NOT_FOUND()
        SongFacet(address(diamond)).updateSongMetaData(999, UPDATED_SONG_CID);
        vm.stopPrank();
    }

    function testUpdateSongMetaData_RevertWhen_NotOwner() public {
        // Artist1 uploads song
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Artist2 tries to update artist1's song
        vm.startPrank(artist2);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);
        vm.stopPrank();
    }

    function testUpdateSongMetaData_RevertWhen_NonArtistTriesToUpdate() public {
        // Artist1 uploads song
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Non-artist tries to update
        vm.startPrank(nonArtist);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);
        vm.stopPrank();
    }

    // ========== getSongInfo Tests ==========

    function testGetSongInfo_ValidSong() public {
        vm.prank(artist1);
        (uint256 songId,,, uint256 createdAt) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);

        assertEq(song.songId, songId, "Song ID should match");
        assertEq(song.artistAddress, artist1, "Artist address should match");
        assertEq(song.songCID, SONG1_CID, "Song CID should match");
        assertGt(song.tokenId, 0, "Token ID should be set");
        assertEq(song.createdAt, createdAt, "Created timestamp should match");
        assertTrue(song.royaltyReceiver != address(0), "Royalty receiver should be set");
    }

    function testGetSongInfo_RevertWhen_SongDoesNotExist() public {
        vm.expectRevert("Song does not exist");
        SongFacet(address(diamond)).getSongInfo(999);
    }

    // ========== getArtistSongs Tests ==========

    function testGetArtistSongs_NoSongs() public {
        uint256[] memory songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(songs.length, 0, "New artist should have no songs");
    }

    function testGetArtistSongs_OneSong() public {
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        uint256[] memory songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(songs.length, 1, "Artist should have 1 song");
        assertEq(songs[0], songId, "Song ID should match");
    }

    function testGetArtistSongs_MultipleSongs() public {
        vm.startPrank(artist1);
        (uint256 song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        (uint256 song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        (uint256 song3,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);
        vm.stopPrank();

        uint256[] memory songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(songs.length, 3, "Artist should have 3 songs");
        assertEq(songs[0], song1, "First song should match");
        assertEq(songs[1], song2, "Second song should match");
        assertEq(songs[2], song3, "Third song should match");
    }

    function testGetArtistSongs_UnregisteredArtist() public {
        uint256[] memory songs = SongFacet(address(diamond)).getArtistSongs(nonArtist);
        assertEq(songs.length, 0, "Unregistered artist should have no songs");
    }

    // ========== isArtistToken Tests ==========

    function testIsArtistToken_ArtistToken() public {
        // Get artist's token from profile setup
        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        uint256 artistTokenId = artist.artistTokenId;

        assertTrue(SongFacet(address(diamond)).isArtistToken(artistTokenId), "Should be artist token");
    }

    function testIsArtistToken_SongToken() public {
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);

        assertFalse(SongFacet(address(diamond)).isArtistToken(song.tokenId), "Should not be artist token");
    }

    function testIsArtistToken_NonExistentToken() public {
        assertFalse(SongFacet(address(diamond)).isArtistToken(999), "Non-existent token should return false");
    }

    // ========== getAllSongs Tests ==========

    function testGetAllSongs_NoSongs() public {
        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 0, "Should have no songs initially");
    }

    function testGetAllSongs_OneSong() public {
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 1, "Should have 1 song");
        assertEq(allSongs[0], songId, "Song ID should match");
    }

    function testGetAllSongs_MultipleSongsMultipleArtists() public {
        // Artist1 uploads 2 songs
        vm.startPrank(artist1);
        (uint256 song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        (uint256 song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        vm.stopPrank();

        // Artist2 uploads 1 song
        vm.prank(artist2);
        (uint256 song3,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);

        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 3, "Should have 3 songs total");
        assertEq(allSongs[0], song1, "First song should match");
        assertEq(allSongs[1], song2, "Second song should match");
        assertEq(allSongs[2], song3, "Third song should match");
    }

    // ========== getSongById Tests ==========

    function testGetSongById_ValidSong() public {
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongById(songId);

        assertEq(song.songId, songId, "Song ID should match");
        assertEq(song.artistAddress, artist1, "Artist address should match");
        assertEq(song.songCID, SONG1_CID, "Song CID should match");
    }

    function testGetSongById_NonExistentSong() public {
        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongById(999);

        assertEq(song.songId, 0, "Non-existent song should have ID 0");
        assertEq(song.artistAddress, address(0), "Non-existent song should have zero address");
        assertEq(song.songCID, "", "Non-existent song should have empty CID");
    }

    // ========== Integration Tests ==========

    function testIntegration_CompleteSongLifecycle() public {
        vm.startPrank(artist1);

        // 1. Upload song
        (uint256 songId, address artist, string memory songCID, uint256 createdAt) =
            SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        assertEq(songId, 1, "Song ID should be 1");
        assertEq(artist, artist1, "Artist should match");
        assertEq(songCID, SONG1_CID, "CID should match");

        // 2. Verify song was stored correctly
        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.artistAddress, artist1, "Stored artist should match");
        assertEq(song.songCID, SONG1_CID, "Stored CID should match");

        // 3. Verify NFT ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(song.tokenId), artist1, "Artist should own token");

        // 4. Verify song appears in artist's song list
        uint256[] memory artistSongs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(artistSongs.length, 1, "Artist should have 1 song");
        assertEq(artistSongs[0], songId, "Song ID should be in artist's list");

        // 5. Verify song appears in global song list
        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 1, "Should have 1 song globally");

        // 6. Update song metadata
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);

        // 7. Verify update
        song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.songCID, UPDATED_SONG_CID, "CID should be updated");

        // 8. Verify token URI updated
        string memory expectedURI = string(abi.encodePacked("ipfs://", UPDATED_SONG_CID));
        assertEq(ERC721Facet(address(diamond)).tokenURI(song.tokenId), expectedURI, "Token URI should be updated");

        vm.stopPrank();
    }

    function testIntegration_MultipleArtistsIndependence() public {
        // Artist1 uploads songs
        vm.startPrank(artist1);
        (uint256 a1Song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        (uint256 a1Song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        vm.stopPrank();

        // Artist2 uploads songs
        vm.startPrank(artist2);
        (uint256 a2Song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);
        vm.stopPrank();

        // Verify artist1's songs
        uint256[] memory artist1Songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(artist1Songs.length, 2, "Artist1 should have 2 songs");

        // Verify artist2's songs
        uint256[] memory artist2Songs = SongFacet(address(diamond)).getArtistSongs(artist2);
        assertEq(artist2Songs.length, 1, "Artist2 should have 1 song");

        // Artist1 updates their song
        vm.prank(artist1);
        SongFacet(address(diamond)).updateSongMetaData(a1Song1, UPDATED_SONG_CID);

        // Verify artist1's song is updated
        LibAppStorage.Song memory song1 = SongFacet(address(diamond)).getSongInfo(a1Song1);
        assertEq(song1.songCID, UPDATED_SONG_CID, "Artist1's song should be updated");

        // Verify artist2's song is unchanged
        LibAppStorage.Song memory song3 = SongFacet(address(diamond)).getSongInfo(a2Song1);
        assertEq(song3.songCID, SONG3_CID, "Artist2's song should be unchanged");

        // Verify global song count
        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 3, "Should have 3 songs total");
    }

    function testIntegration_SongOwnershipTransfer() public {
        // Artist uploads song
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        uint256 tokenId = song.tokenId;

        // Transfer token to fan1
        vm.prank(artist1);
        ERC721Facet(address(diamond)).transferFrom(artist1, fan1, tokenId);

        // Verify new ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), fan1, "Fan should own token");

        // Original artist should still be recorded as song creator
        song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.artistAddress, artist1, "Artist address should remain unchanged");

        // Only original artist can update metadata
        vm.prank(fan1);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);

        // Original artist can still update
        vm.prank(artist1);
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);

        song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.songCID, UPDATED_SONG_CID, "Artist should be able to update metadata");
    }

    function testIntegration_RoyaltySplitterCreation() public {
        // Artist1 uploads first song - should create splitter
        vm.startPrank(artist1);
        (uint256 song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        LibAppStorage.Song memory s1 = SongFacet(address(diamond)).getSongInfo(song1);
        address splitter1 = s1.royaltyReceiver;

        // Artist1 uploads second song - should reuse splitter
        (uint256 song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        LibAppStorage.Song memory s2 = SongFacet(address(diamond)).getSongInfo(song2);
        address splitter2 = s2.royaltyReceiver;
        vm.stopPrank();

        // Both songs should have same splitter
        assertEq(splitter1, splitter2, "Same artist should reuse splitter");
        assertTrue(splitter1 != address(0), "Splitter should be valid");

        // Different artist should have different splitter
        vm.prank(artist2);
        (uint256 song3,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);
        LibAppStorage.Song memory s3 = SongFacet(address(diamond)).getSongInfo(song3);

        assertTrue(s3.royaltyReceiver != splitter1, "Different artist should have different splitter");
    }

    function testIntegration_SongCounters() public {
        // Initially no songs
        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 0, "Should start with 0 songs");

        // Artist1 uploads 3 songs
        vm.startPrank(artist1);
        SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);
        vm.stopPrank();

        // Verify global counter
        allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 3, "Should have 3 songs");

        // Artist2 uploads 2 songs
        vm.startPrank(artist2);
        SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);
        vm.stopPrank();

        // Verify updated global counter
        allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, 5, "Should have 5 songs total");

        // Verify individual artist counters
        uint256[] memory artist1Songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        uint256[] memory artist2Songs = SongFacet(address(diamond)).getArtistSongs(artist2);
        assertEq(artist1Songs.length, 3, "Artist1 should have 3 songs");
        assertEq(artist2Songs.length, 2, "Artist2 should have 2 songs");
    }

    function testIntegration_TokenURIConsistency() public {
        vm.startPrank(artist1);

        // Upload song
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);

        // Verify initial URI
        string memory expectedURI1 = string(abi.encodePacked("ipfs://", SONG1_CID));
        assertEq(ERC721Facet(address(diamond)).tokenURI(song.tokenId), expectedURI1, "Initial URI should match");

        // Update metadata
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);

        // Verify updated URI
        string memory expectedURI2 = string(abi.encodePacked("ipfs://", UPDATED_SONG_CID));
        assertEq(ERC721Facet(address(diamond)).tokenURI(song.tokenId), expectedURI2, "Updated URI should match");

        vm.stopPrank();
    }

    function testIntegration_BulkUpload() public {
        uint256 numberOfSongs = 10;

        vm.startPrank(artist1);

        for (uint256 i = 0; i < numberOfSongs; i++) {
            string memory cid = string(abi.encodePacked("QmSong", Strings.toString(i)));
            SongFacet(address(diamond)).uploadAndMintSong(cid, 0);
        }

        vm.stopPrank();

        // Verify all songs were uploaded
        uint256[] memory artistSongs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(artistSongs.length, numberOfSongs, "Should have uploaded all songs");

        uint256[] memory allSongs = SongFacet(address(diamond)).getAllSongs();
        assertEq(allSongs.length, numberOfSongs, "Global count should match");

        // Verify each song has correct data
        for (uint256 i = 0; i < numberOfSongs; i++) {
            uint256 songId = artistSongs[i];
            LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
            assertEq(song.artistAddress, artist1, "Each song should belong to artist1");
            assertGt(song.tokenId, 0, "Each song should have valid token ID");
        }
    }

    function testIntegration_SongIDSequentiality() public {
        // Upload songs from different artists in sequence
        vm.prank(artist1);
        (uint256 song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        vm.prank(artist2);
        (uint256 song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);

        vm.prank(artist3);
        (uint256 song3,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG3_CID, 0);

        vm.prank(artist1);
        (uint256 song4,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Verify sequential IDs
        assertEq(song1, 1, "First song should be ID 1");
        assertEq(song2, 2, "Second song should be ID 2");
        assertEq(song3, 3, "Third song should be ID 3");
        assertEq(song4, 4, "Fourth song should be ID 4");
    }

    function testIntegration_UpdateDoesNotChangeOwnership() public {
        // Upload and transfer
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);

        vm.prank(artist1);
        ERC721Facet(address(diamond)).transferFrom(artist1, fan1, song.tokenId);

        // Update metadata
        vm.prank(artist1);
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);

        // Verify ownership unchanged
        assertEq(ERC721Facet(address(diamond)).ownerOf(song.tokenId), fan1, "Ownership should remain with fan1");

        // Verify metadata updated
        song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.songCID, UPDATED_SONG_CID, "Metadata should be updated");
    }

    // ========== Edge Cases & Security Tests ==========

    function testEdgeCase_EmptyArtistSongList() public {
        uint256[] memory songs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(songs.length, 0, "New artist should have empty song list");
    }

    function testEdgeCase_SongInfoAfterMultipleUpdates() public {
        vm.startPrank(artist1);

        (uint256 songId,,, uint256 originalTimestamp) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Multiple updates
        for (uint256 i = 0; i < 5; i++) {
            string memory newCid = string(abi.encodePacked("QmUpdate", Strings.toString(i)));
            SongFacet(address(diamond)).updateSongMetaData(songId, newCid);
        }

        vm.stopPrank();

        // Verify timestamp didn't change
        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.createdAt, originalTimestamp, "Original timestamp should be preserved");
    }

    function testSecurity_CannotUpdateOtherArtistsSongs() public {
        // Artist1 uploads song
        vm.prank(artist1);
        (uint256 song1,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Artist2 uploads song
        vm.prank(artist2);
        (uint256 song2,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG2_CID, 0);

        // Artist1 cannot update Artist2's song
        vm.startPrank(artist1);
        vm.expectRevert();
        SongFacet(address(diamond)).updateSongMetaData(song2, UPDATED_SONG_CID);
        vm.stopPrank();

        // Artist2 cannot update Artist1's song
        vm.startPrank(artist2);
        vm.expectRevert();
        SongFacet(address(diamond)).updateSongMetaData(song1, UPDATED_SONG_CID);
        vm.stopPrank();
    }

    function testSecurity_OnlyArtistCanUpdateMetadata() public {
        vm.prank(artist1);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);

        // Random user cannot update
        vm.startPrank(fan1);
        vm.expectRevert();
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);
        vm.stopPrank();

        // Platform cannot update
        vm.startPrank(platformFeeAddress);
        vm.expectRevert();
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);
        vm.stopPrank();

        // Only artist can update
        vm.prank(artist1);
        SongFacet(address(diamond)).updateSongMetaData(songId, UPDATED_SONG_CID);

        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        assertEq(song.songCID, UPDATED_SONG_CID, "Artist should be able to update");
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
