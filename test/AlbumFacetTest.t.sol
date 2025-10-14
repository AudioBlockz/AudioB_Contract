// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/OwnershipControlFacet.sol";
import "../contracts/facets/ArtistFacet.sol";
import "../contracts/facets/SongFacet.sol";
import "../contracts/facets/AlbumFacet.sol";
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


/**
 * @title AlbumFacetTest
 * @notice Comprehensive test suite for AlbumFacet functionality
 * @dev Tests cover album lifecycle, access control, event emissions, and edge cases
 */
contract AlbumFacetTest is Test, IDiamondCut, DiamondUtils {
    // ========== State Variables ==========
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

    // Test data constants
    string constant ARTIST1_CID = "QmArtist1Profile";
    string constant ARTIST2_CID = "QmArtist2Profile";
    string constant ARTIST3_CID = "QmArtist3Profile";
    string constant SONG1_CID = "QmSong1Metadata";
    string constant SONG2_CID = "QmSong2Metadata";
    string constant SONG3_CID = "QmSong3Metadata";
    string constant SONG4_CID = "QmSong4Metadata";
    string constant SONG5_CID = "QmSong5Metadata";
    string constant ALBUM1_CID = "QmAlbum1Metadata";
    string constant ALBUM2_CID = "QmAlbum2Metadata";
    string constant UPDATED_ALBUM_CID = "QmUpdatedAlbumMetadata";

    // Event signatures for testing
    event AlbumPublishedSuccessfully(uint256 indexed albumId, address indexed artist, string albumCID);
    event AlbumMetadataUpdated(uint256 indexed albumId, string newCid);
    event SongAddedToAlbum(uint256 indexed albumId, uint256 indexed songId);
    event SongRemovedFromAlbum(uint256 indexed albumId, uint256 indexed songId);
    event AlbumSongsUpdated(uint256 indexed albumId, uint256[] songIds);
    event AlbumDestroyed(uint256 indexed albumId, address indexed artist);

    // ========== Setup ==========

    function setUp() public {
        // Deploy core diamond infrastructure
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

        // Deploy all facets
        ArtistFacet artistFacet = new ArtistFacet();
        MarketPlaceFacet marketPlaceFacet = new MarketPlaceFacet();
        SongFacet songFacet = new SongFacet();
        AlbumFacet albumFacet = new AlbumFacet();
        ERC721Facet erc721Facet = new ERC721Facet();
        OwnershipControlFacet ownershipControlFacet = new OwnershipControlFacet();
        helperFacet = new HelperFacet();

        // Build cut struct
        FacetCut[] memory cut = new FacetCut[](9);

        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        cut[2] = FacetCut({
            facetAddress: address(artistFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ArtistFacet")
        });

        cut[3] = FacetCut({
            facetAddress: address(marketPlaceFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("MarketPlaceFacet")
        });

        cut[4] = FacetCut({
            facetAddress: address(songFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("SongFacet")
        });

        cut[5] = FacetCut({
            facetAddress: address(albumFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("AlbumFacet")
        });

        cut[6] = FacetCut({
            facetAddress: address(erc721Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });

        cut[7] = FacetCut({
            facetAddress: address(ownershipControlFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipControlFacet")
        });

        cut[8] = (
            FacetCut({
                facetAddress: address(helperFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("HelperFacet")
            })
        );

        // Execute diamond cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        // Configure platform settings
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
        ArtistFacet(address(diamond)).setupArtistProfile(ARTIST3_CID);
    }

    

    // ========== Helper Functions ==========

    /**
     * @notice Helper to create songs for an artist
     * @param artist Address of the artist
     * @param count Number of songs to create
     * @return songIds Array of created song IDs
     */
    function _createSongsForArtist(address artist, uint256 count) internal returns (uint256[] memory songIds) {
        songIds = new uint256[](count);
        vm.startPrank(artist);
        for (uint256 i = 0; i < count; i++) {
            string memory cid = string(abi.encodePacked("QmSong", Strings.toString(i)));
            (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(cid, 0);
            songIds[i] = songId;
        }
        vm.stopPrank();
    }

    /**
     * @notice Helper to create an album with songs
     * @param artist Address of the artist
     * @param songCount Number of songs in the album
     * @return albumId The created album ID
     * @return songIds The song IDs in the album
     */
    function _createAlbumWithSongs(address artist, uint256 songCount)
        internal
        returns (uint256 albumId, uint256[] memory songIds)
    {
        songIds = _createSongsForArtist(artist, songCount);
        vm.prank(artist);
        (albumId,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);
    }

    // ========== publishAlbum Tests ==========

    function testPublishAlbum_Success() public {
        // Create songs
        uint256[] memory songIds = _createSongsForArtist(artist1, 3);

        // Record expected event
        vm.expectEmit(true, true, false, true);
        emit AlbumPublishedSuccessfully(1, artist1, ALBUM1_CID);

        // Publish album
        vm.prank(artist1);
        (uint256 albumId, address artist, string memory albumCID, uint256 createdAt) =
            AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);

        // Assert return values
        assertEq(albumId, 1, "Album ID should be 1");
        assertEq(artist, artist1, "Artist should match");
        assertEq(albumCID, ALBUM1_CID, "Album CID should match");
        assertGt(createdAt, 0, "Created timestamp should be set");
        assertEq(createdAt, block.timestamp, "Timestamp should match block timestamp");

        // Verify album storage
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumId, albumId, "Stored album ID should match");
        assertEq(album.artistAddress, artist1, "Stored artist should match");
        assertEq(album.albumCID, ALBUM1_CID, "Stored CID should match");
        assertEq(album.songIds.length, 3, "Album should have 3 songs");
        assertTrue(album.published, "Album should be marked as published");
        assertEq(album.createdAt, createdAt, "Created timestamp should match");
        assertEq(album.publishedAt, createdAt, "Published timestamp should match created");

        // Verify song IDs match
        for (uint256 i = 0; i < songIds.length; i++) {
            assertEq(album.songIds[i], songIds[i], "Song ID should match");
        }

        // Verify NFT minting
        assertGt(album.tokenId, 0, "Album should have token ID");
        assertEq(ERC721Facet(address(diamond)).ownerOf(album.tokenId), artist1, "Artist should own album NFT");

        // Verify token URI
        string memory expectedURI = string(abi.encodePacked("ipfs://", ALBUM1_CID));
        assertEq(ERC721Facet(address(diamond)).tokenURI(album.tokenId), expectedURI, "Token URI should be correct");

        // Verify royalty receiver
        assertTrue(album.tokenId != 0, "Token ID should be set");
    }

    function testPublishAlbum_MultipleAlbumsSameArtist() public {
        // Create songs for first album
        uint256[] memory album1Songs = _createSongsForArtist(artist1, 3);

        // Create songs for second album
        uint256[] memory album2Songs = _createSongsForArtist(artist1, 2);

        vm.startPrank(artist1);

        // Publish first album
        (uint256 albumId1,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, album1Songs);

        // Publish second album
        (uint256 albumId2,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM2_CID, album2Songs);

        vm.stopPrank();

        // Verify unique IDs
        assertEq(albumId1, 1, "First album should be ID 1");
        assertEq(albumId2, 2, "Second album should be ID 2");

        // Verify artist albums
        uint256[] memory artistAlbums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        assertEq(artistAlbums.length, 2, "Artist should have 2 albums");
        assertEq(artistAlbums[0], albumId1, "First album ID should match");
        assertEq(artistAlbums[1], albumId2, "Second album ID should match");

        // Verify album details
        LibAppStorage.Album memory a1 = AlbumFacet(address(diamond)).getAlbum(albumId1);
        LibAppStorage.Album memory a2 = AlbumFacet(address(diamond)).getAlbum(albumId2);

        assertEq(a1.songIds.length, 3, "First album should have 3 songs");
        assertEq(a2.songIds.length, 2, "Second album should have 2 songs");
        assertEq(a1.albumCID, ALBUM1_CID, "First album CID should match");
        assertEq(a2.albumCID, ALBUM2_CID, "Second album CID should match");
    }

    function testPublishAlbum_MultipleArtists() public {
        // Artist1 publishes album
        uint256[] memory artist1Songs = _createSongsForArtist(artist1, 3);
        vm.prank(artist1);
        (uint256 album1,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, artist1Songs);

        // Artist2 publishes album
        uint256[] memory artist2Songs = _createSongsForArtist(artist2, 2);
        vm.prank(artist2);
        (uint256 album2,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM2_CID, artist2Songs);

        // Verify sequential IDs
        assertEq(album1, 1, "First album should be ID 1");
        assertEq(album2, 2, "Second album should be ID 2");

        // Verify ownership
        LibAppStorage.Album memory a1 = AlbumFacet(address(diamond)).getAlbum(album1);
        LibAppStorage.Album memory a2 = AlbumFacet(address(diamond)).getAlbum(album2);

        assertEq(a1.artistAddress, artist1, "Album 1 should belong to artist1");
        assertEq(a2.artistAddress, artist2, "Album 2 should belong to artist2");

        // Verify artist-specific albums
        uint256[] memory artist1Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        uint256[] memory artist2Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist2);

        assertEq(artist1Albums.length, 1, "Artist1 should have 1 album");
        assertEq(artist2Albums.length, 1, "Artist2 should have 1 album");

        // Verify global albums
        uint256[] memory allAlbums = AlbumFacet(address(diamond)).getAlbums();
        assertEq(allAlbums.length, 2, "Should have 2 albums globally");
    }

    function testPublishAlbum_LargeAlbum() public {
        // Create album with 20 songs
        uint256[] memory songIds = _createSongsForArtist(artist1, 20);

        vm.prank(artist1);
        (uint256 albumId,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 20, "Album should have 20 songs");

        // Verify all songs are correctly stored
        for (uint256 i = 0; i < 20; i++) {
            assertEq(album.songIds[i], songIds[i], "Each song ID should match");
        }
    }

    function testPublishAlbum_Reverts() public {
        uint256[] memory songIds = _createSongsForArtist(artist1, 3);
        uint256[] memory emptySongs = new uint256[](0);
        uint256[] memory invalidSongs = new uint256[](2);
        invalidSongs[0] = 1;
        invalidSongs[1] = 999; // Non-existent song

        // Test: Not registered artist
        vm.startPrank(nonArtist);
        vm.expectRevert(); // ErrorLib.ARTIST_NOT_REGISTERED()
        AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);
        vm.stopPrank();

        vm.startPrank(artist1);

        // Test: Empty CID
        vm.expectRevert(); // ErrorLib.InvalidCid()
        AlbumFacet(address(diamond)).publishAlbum("", songIds);

        // Test: Empty song array
        vm.expectRevert(); // ErrorLib.InvalidArrayLength()
        AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, emptySongs);

        vm.stopPrank();

        // Test: Invalid song ID
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.SONG_NOT_FOUND()
        AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, invalidSongs);
        vm.stopPrank();

        // Test: Songs from different artist
        uint256[] memory artist2Songs = _createSongsForArtist(artist2, 2);
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, artist2Songs);
        vm.stopPrank();
    }

    // ========== updateAlbumMetaData Tests ==========

    function testUpdateAlbumMetaData_Success() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit AlbumMetadataUpdated(albumId, UPDATED_ALBUM_CID);

        // Update metadata
        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);

        // Verify update
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumCID, UPDATED_ALBUM_CID, "Album CID should be updated");

        // Verify other fields unchanged
        assertEq(album.albumId, albumId, "Album ID should not change");
        assertEq(album.artistAddress, artist1, "Artist should not change");
        assertEq(album.songIds.length, 3, "Song count should not change");
    }

    function testUpdateAlbumMetaData_MultipleUpdates() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        string[] memory updates = new string[](3);
        updates[0] = "QmUpdate1";
        updates[1] = "QmUpdate2";
        updates[2] = "QmUpdate3";

        vm.startPrank(artist1);
        for (uint256 i = 0; i < updates.length; i++) {
            AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, updates[i]);
            LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
            assertEq(album.albumCID, updates[i], "Album CID should match update");
        }
        vm.stopPrank();
    }

    function testUpdateAlbumMetaData_Reverts() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        // Test: Album not found
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.ALBUM_NOT_FOUND()
        AlbumFacet(address(diamond)).updateAlbumMetaData(999, UPDATED_ALBUM_CID);

        // Test: Empty CID
        vm.expectRevert(); // ErrorLib.InvalidCid()
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, "");
        vm.stopPrank();

        // Test: Not album owner
        vm.startPrank(artist2);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);
        vm.stopPrank();

        // Test: Non-artist tries to update
        vm.startPrank(nonArtist);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);
        vm.stopPrank();
    }

    // ========== updateAlbumSongs Tests ==========

    function testUpdateAlbumSongs_Success() public {
        // Create album with 3 songs
        (uint256 albumId, uint256[] memory originalSongs) = _createAlbumWithSongs(artist1, 3);

        // Create new songs
        uint256[] memory newSongs = _createSongsForArtist(artist1, 2);

        // Expect events
        vm.expectEmit(true, true, false, false);
        emit SongAddedToAlbum(albumId, newSongs[0]);
        vm.expectEmit(true, true, false, false);
        emit SongAddedToAlbum(albumId, newSongs[1]);
        vm.expectEmit(true, false, false, true);
        emit AlbumSongsUpdated(albumId, newSongs);

        // Update songs
        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, newSongs);

        // Verify update
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 2, "Album should have 2 songs");
        assertEq(album.songIds[0], newSongs[0], "First song should match");
        assertEq(album.songIds[1], newSongs[1], "Second song should match");
    }

    function testUpdateAlbumSongs_ReplaceWithMore() public {
        // Create album with 2 songs
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 2);

        // Create 5 new songs
        uint256[] memory newSongs = _createSongsForArtist(artist1, 5);

        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, newSongs);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 5, "Album should now have 5 songs");
    }

    function testUpdateAlbumSongs_Reverts() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);
        uint256[] memory emptySongs = new uint256[](0);
        uint256[] memory invalidSongs = new uint256[](1);
        invalidSongs[0] = 999;

        // Test: Album not found
        uint256[] memory validSongs = _createSongsForArtist(artist1, 2);
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.ALBUM_NOT_FOUND()
        AlbumFacet(address(diamond)).updateAlbumSongs(999, validSongs);

        // Test: Empty array
        vm.expectRevert(); // ErrorLib.InvalidArrayLength()
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, emptySongs);

        // Test: Invalid song ID
        vm.expectRevert(); // ErrorLib.SONG_NOT_FOUND()
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, invalidSongs);
        vm.stopPrank();

        // Test: Not album owner
        uint256[] memory newSongs = _createSongsForArtist(artist1, 2);
        vm.startPrank(artist2);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, newSongs);
        vm.stopPrank();

        // Test: Songs from different artist
        uint256[] memory artist2Songs = _createSongsForArtist(artist2, 2);
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, artist2Songs);
        vm.stopPrank();
    }

    // ========== removeSongFromAlbum Tests ==========

    function testRemoveSongFromAlbum_Success() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        uint256 songToRemove = songIds[1]; // Remove middle song

        // Expect event
        vm.expectEmit(true, true, false, false);
        emit SongRemovedFromAlbum(albumId, songToRemove);

        // Remove song
        vm.prank(artist1);
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songToRemove);

        // Verify removal
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 2, "Album should have 2 songs remaining");

        // Verify removed song is not in array
        bool found = false;
        for (uint256 i = 0; i < album.songIds.length; i++) {
            if (album.songIds[i] == songToRemove) {
                found = true;
                break;
            }
        }
        assertFalse(found, "Removed song should not be in album");
    }

    function testRemoveSongFromAlbum_RemoveFirst() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        vm.prank(artist1);
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[0]);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 2, "Should have 2 songs left");
    }

    function testRemoveSongFromAlbum_RemoveLast() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        vm.prank(artist1);
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[2]);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 2, "Should have 2 songs left");
    }

    function testRemoveSongFromAlbum_RemoveAllSongs() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        vm.startPrank(artist1);
        for (uint256 i = 0; i < songIds.length; i++) {
            AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[i]);
        }
        vm.stopPrank();

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 0, "Album should have no songs");
    }

    function testRemoveSongFromAlbum_NonExistentSong() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        // Try to remove song not in album (should not revert, just do nothing)
        vm.prank(artist1);
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, 999);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 3, "Song count should remain unchanged");
    }

    function testRemoveSongFromAlbum_Reverts() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        // Test: Album not found
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.ALBUM_NOT_FOUND()
        AlbumFacet(address(diamond)).removeSongFromAlbum(999, songIds[0]);
        vm.stopPrank();

        // Test: Not album owner
        vm.startPrank(artist2);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[0]);
        vm.stopPrank();

        // Test: Non-artist
        vm.startPrank(nonArtist);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[0]);
        vm.stopPrank();
    }

    // ========== destroyAlbum Tests ==========

    function testDestroyAlbum_Success() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        // Get initial counts
        uint256[] memory initialGlobalAlbums = AlbumFacet(address(diamond)).getAlbums();
        uint256[] memory initialArtistAlbums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);

        // Expect event
        vm.expectEmit(true, true, false, false);
        emit AlbumDestroyed(albumId, artist1);

        // Destroy album
        vm.prank(artist1);
        AlbumFacet(address(diamond)).destroyAlbum(albumId);

        // Verify album is deleted
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumId, 0, "Album should be deleted (ID = 0)");
        assertEq(album.artistAddress, address(0), "Album artist should be zero address");
        assertEq(album.songIds.length, 0, "Album should have no songs");

        // Verify removed from artist albums
        uint256[] memory artistAlbums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        assertEq(artistAlbums.length, initialArtistAlbums.length - 1, "Artist should have one less album");

        // Verify removed from global albums
        uint256[] memory globalAlbums = AlbumFacet(address(diamond)).getAlbums();
        assertEq(globalAlbums.length, initialGlobalAlbums.length - 1, "Global albums should decrease by 1");

        // Verify album ID is not in arrays
        bool foundInArtist = false;
        for (uint256 i = 0; i < artistAlbums.length; i++) {
            if (artistAlbums[i] == albumId) foundInArtist = true;
        }
        assertFalse(foundInArtist, "Album should not be in artist's albums");

        bool foundInGlobal = false;
        for (uint256 i = 0; i < globalAlbums.length; i++) {
            if (globalAlbums[i] == albumId) foundInGlobal = true;
        }
        assertFalse(foundInGlobal, "Album should not be in global albums");
    }

    function testDestroyAlbum_MultipleAlbums() public {
        // Create 3 albums
        (uint256 album1,) = _createAlbumWithSongs(artist1, 2);
        (uint256 album2,) = _createAlbumWithSongs(artist1, 3);
        (uint256 album3,) = _createAlbumWithSongs(artist1, 4);

        // Destroy middle album
        vm.prank(artist1);
        AlbumFacet(address(diamond)).destroyAlbum(album2);

        // Verify counts
        uint256[] memory artistAlbums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        assertEq(artistAlbums.length, 2, "Should have 2 albums remaining");

        // Verify correct albums remain
        LibAppStorage.Album memory a1 = AlbumFacet(address(diamond)).getAlbum(album1);
        LibAppStorage.Album memory a2 = AlbumFacet(address(diamond)).getAlbum(album2);
        LibAppStorage.Album memory a3 = AlbumFacet(address(diamond)).getAlbum(album3);

        assertEq(a1.albumId, album1, "Album 1 should still exist");
        assertEq(a2.albumId, 0, "Album 2 should be deleted");
        assertEq(a3.albumId, album3, "Album 3 should still exist");
    }

    function testDestroyAlbum_DoesNotAffectSongs() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        // Destroy album
        vm.prank(artist1);
        AlbumFacet(address(diamond)).destroyAlbum(albumId);

        // Verify songs still exist
        for (uint256 i = 0; i < songIds.length; i++) {
            LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songIds[i]);
            assertEq(song.songId, songIds[i], "Song should still exist");
            assertEq(song.artistAddress, artist1, "Song artist should be unchanged");
        }

        // Verify artist still has songs
        uint256[] memory artistSongs = SongFacet(address(diamond)).getArtistSongs(artist1);
        assertEq(artistSongs.length, 3, "Artist should still have all songs");
    }

    function testDestroyAlbum_Reverts() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        // Test: Album not found
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.ALBUM_NOT_FOUND()
        AlbumFacet(address(diamond)).destroyAlbum(999);
        vm.stopPrank();

        // Test: Not album owner
        vm.startPrank(artist2);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).destroyAlbum(albumId);
        vm.stopPrank();

        // Test: Non-artist
        vm.startPrank(nonArtist);
        vm.expectRevert(); // ErrorLib.NOT_ALBUM_OWNER()
        AlbumFacet(address(diamond)).destroyAlbum(albumId);
        vm.stopPrank();
    }

    // ========== Getter Function Tests ==========

    function testGetAlbum_ValidAlbum() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);

        assertEq(album.albumId, albumId, "Album ID should match");
        assertEq(album.artistAddress, artist1, "Artist should match");
        assertEq(album.albumCID, ALBUM1_CID, "CID should match");
        assertEq(album.songIds.length, 3, "Should have 3 songs");
        assertTrue(album.published, "Should be published");
        assertGt(album.tokenId, 0, "Should have token ID");
        assertEq(album.createdAt, album.publishedAt, "Created and published should match");

        // Verify song IDs
        for (uint256 i = 0; i < songIds.length; i++) {
            assertEq(album.songIds[i], songIds[i], "Song ID should match");
        }
    }

    function testGetAlbum_NonExistentAlbum() public {
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(999);

        assertEq(album.albumId, 0, "Non-existent album should have ID 0");
        assertEq(album.artistAddress, address(0), "Should have zero address");
        assertEq(album.albumCID, "", "Should have empty CID");
        assertEq(album.songIds.length, 0, "Should have no songs");
    }

    function testGetAlbums_Empty() public {
        uint256[] memory albums = AlbumFacet(address(diamond)).getAlbums();
        assertEq(albums.length, 0, "Should have no albums initially");
    }

    function testGetAlbums_MultipleAlbums() public {
        // Create albums from different artists
        (uint256 album1,) = _createAlbumWithSongs(artist1, 2);
        (uint256 album2,) = _createAlbumWithSongs(artist2, 3);
        (uint256 album3,) = _createAlbumWithSongs(artist1, 4);

        uint256[] memory albums = AlbumFacet(address(diamond)).getAlbums();

        assertEq(albums.length, 3, "Should have 3 albums");
        assertEq(albums[0], album1, "First album should match");
        assertEq(albums[1], album2, "Second album should match");
        assertEq(albums[2], album3, "Third album should match");
    }

    function testGetAlbumsByArtist_NoAlbums() public {
        uint256[] memory albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        assertEq(albums.length, 0, "New artist should have no albums");
    }

    function testGetAlbumsByArtist_SingleAlbum() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        uint256[] memory albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);

        assertEq(albums.length, 1, "Artist should have 1 album");
        assertEq(albums[0], albumId, "Album ID should match");
    }

    function testGetAlbumsByArtist_MultipleAlbums() public {
        (uint256 album1,) = _createAlbumWithSongs(artist1, 2);
        (uint256 album2,) = _createAlbumWithSongs(artist1, 3);
        (uint256 album3,) = _createAlbumWithSongs(artist1, 4);

        uint256[] memory albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);

        assertEq(albums.length, 3, "Artist should have 3 albums");
        assertEq(albums[0], album1, "First album should match");
        assertEq(albums[1], album2, "Second album should match");
        assertEq(albums[2], album3, "Third album should match");
    }

    function testGetAlbumsByArtist_DifferentArtists() public {
        // Artist1 creates 2 albums
        _createAlbumWithSongs(artist1, 2);
        _createAlbumWithSongs(artist1, 3);

        // Artist2 creates 1 album
        _createAlbumWithSongs(artist2, 4);

        uint256[] memory artist1Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        uint256[] memory artist2Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist2);

        assertEq(artist1Albums.length, 2, "Artist1 should have 2 albums");
        assertEq(artist2Albums.length, 1, "Artist2 should have 1 album");
    }

    function testGetAlbumsByArtist_UnregisteredArtist() public {
        uint256[] memory albums = AlbumFacet(address(diamond)).getAlbumsByArtist(nonArtist);
        assertEq(albums.length, 0, "Unregistered artist should have no albums");
    }

    // ========== Integration Tests ==========

    function testIntegration_CompleteAlbumLifecycle() public {
        vm.startPrank(artist1);

        // 1. Create songs
        uint256[] memory songIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(
                string(abi.encodePacked("QmSong", Strings.toString(i))),
                0
            );
            songIds[i] = songId;
        }

        // 2. Publish album
        (uint256 albumId,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);

        // 3. Verify album exists
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 3, "Album should have 3 songs");

        // 4. Update metadata
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);
        album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumCID, UPDATED_ALBUM_CID, "CID should be updated");

        // 5. Remove a song
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[1]);
        album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 2, "Should have 2 songs after removal");

        // 6. Add new songs
        uint256[] memory newSongs = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) {
            (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(
                string(abi.encodePacked("QmNewSong", Strings.toString(i))),
                0
            );
            newSongs[i] = songId;
        }
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, newSongs);
        album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 2, "Should have 2 new songs");

        // 7. Destroy album
        AlbumFacet(address(diamond)).destroyAlbum(albumId);
        album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumId, 0, "Album should be destroyed");

        vm.stopPrank();
    }

    function testIntegration_MultipleArtistsMultipleAlbums() public {
        // Artist1 creates 2 albums
        uint256[] memory a1Songs1 = _createSongsForArtist(artist1, 2);
        uint256[] memory a1Songs2 = _createSongsForArtist(artist1, 3);

        vm.startPrank(artist1);
        (uint256 a1Album1,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, a1Songs1);
        (uint256 a1Album2,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM2_CID, a1Songs2);
        vm.stopPrank();

        // Artist2 creates 1 album
        uint256[] memory a2Songs = _createSongsForArtist(artist2, 4);
        vm.prank(artist2);
        (uint256 a2Album,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, a2Songs);

        // Verify global state
        uint256[] memory allAlbums = AlbumFacet(address(diamond)).getAlbums();
        assertEq(allAlbums.length, 3, "Should have 3 albums total");

        // Verify per-artist state
        uint256[] memory artist1Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        uint256[] memory artist2Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist2);
        assertEq(artist1Albums.length, 2, "Artist1 should have 2 albums");
        assertEq(artist2Albums.length, 1, "Artist2 should have 1 album");

        // Artist1 updates their first album
        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumMetaData(a1Album1, UPDATED_ALBUM_CID);

        // Verify only artist1's album is updated
        LibAppStorage.Album memory a1a1 = AlbumFacet(address(diamond)).getAlbum(a1Album1);
        LibAppStorage.Album memory a1a2 = AlbumFacet(address(diamond)).getAlbum(a1Album2);
        LibAppStorage.Album memory a2a = AlbumFacet(address(diamond)).getAlbum(a2Album);

        assertEq(a1a1.albumCID, UPDATED_ALBUM_CID, "Artist1 album1 should be updated");
        assertEq(a1a2.albumCID, ALBUM2_CID, "Artist1 album2 should be unchanged");
        assertEq(a2a.albumCID, ALBUM1_CID, "Artist2 album should be unchanged");

        // Artist1 destroys one album
        vm.prank(artist1);
        AlbumFacet(address(diamond)).destroyAlbum(a1Album1);

        // Verify counts
        artist1Albums = AlbumFacet(address(diamond)).getAlbumsByArtist(artist1);
        allAlbums = AlbumFacet(address(diamond)).getAlbums();
        assertEq(artist1Albums.length, 1, "Artist1 should have 1 album left");
        assertEq(allAlbums.length, 2, "Should have 2 albums total");
    }

    function testIntegration_AlbumNFTOwnership() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        uint256 albumTokenId = album.tokenId;

        // Verify artist owns album NFT
        assertEq(ERC721Facet(address(diamond)).ownerOf(albumTokenId), artist1, "Artist should own album NFT");

        // Transfer album NFT to fan
        vm.prank(artist1);
        ERC721Facet(address(diamond)).transferFrom(artist1, fan1, albumTokenId);

        // Verify new ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(albumTokenId), fan1, "Fan should own album NFT");

        // Verify artist can still manage album
        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);

        album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumCID, UPDATED_ALBUM_CID, "Artist should still be able to update");

        // Verify fan cannot manage album
        vm.startPrank(fan1);
        vm.expectRevert();
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, "QmFanUpdate");
        vm.stopPrank();
    }

    function testIntegration_AlbumWithMixedSongOperations() public {
        vm.startPrank(artist1);

        // Create initial songs
        uint256[] memory initialSongs = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(
                string(abi.encodePacked("QmInitial", Strings.toString(i))),
                0
            );
            initialSongs[i] = songId;
        }

        // Publish album
        (uint256 albumId,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, initialSongs);

        // Remove one song
        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, initialSongs[1]);

        // Create and add new songs
        uint256[] memory newSongs = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(
                string(abi.encodePacked("QmNew", Strings.toString(i))),
                0
            );
            newSongs[i] = songId;
        }

        // Update with new songs
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, newSongs);

        vm.stopPrank();

        // Verify final state
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 4, "Should have 4 songs");

        // Verify all new songs are in album
        for (uint256 i = 0; i < newSongs.length; i++) {
            assertEq(album.songIds[i], newSongs[i], "New song should be in album");
        }
    }

    function testIntegration_AlbumCountersAndSequencing() public {
        // Create 5 albums across different artists
        _createAlbumWithSongs(artist1, 2); // Album 1
        _createAlbumWithSongs(artist2, 3); // Album 2
        _createAlbumWithSongs(artist1, 4); // Album 3
        _createAlbumWithSongs(artist3, 2); // Album 4
        _createAlbumWithSongs(artist2, 5); // Album 5

        // Verify global count
        uint256[] memory allAlbums = AlbumFacet(address(diamond)).getAlbums();
        assertEq(allAlbums.length, 5, "Should have 5 albums");

        // Verify sequential IDs
        for (uint256 i = 0; i < allAlbums.length; i++) {
            assertEq(allAlbums[i], i + 1, "Album IDs should be sequential");
        }

        // Verify per-artist counts
        assertEq(AlbumFacet(address(diamond)).getAlbumsByArtist(artist1).length, 2, "Artist1 should have 2");
        assertEq(AlbumFacet(address(diamond)).getAlbumsByArtist(artist2).length, 2, "Artist2 should have 2");
        assertEq(AlbumFacet(address(diamond)).getAlbumsByArtist(artist3).length, 1, "Artist3 should have 1");
    }

    // ========== Edge Cases & Security Tests ==========

    function testEdgeCase_AlbumWithSingleSong() public {
        uint256[] memory songIds = _createSongsForArtist(artist1, 1);

        vm.prank(artist1);
        (uint256 albumId,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 1, "Album should have 1 song");
    }

    function testEdgeCase_RemoveLastSongFromAlbum() public {
        uint256[] memory songIds = _createSongsForArtist(artist1, 1);

        vm.startPrank(artist1);
        (uint256 albumId,,,) = AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, songIds);

        AlbumFacet(address(diamond)).removeSongFromAlbum(albumId, songIds[0]);
        vm.stopPrank();

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 0, "Album should have no songs");
    }

    function testEdgeCase_UpdateAlbumWithSameSongs() public {
        (uint256 albumId, uint256[] memory songIds) = _createAlbumWithSongs(artist1, 3);

        // Update with same songs
        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumSongs(albumId, songIds);

        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.songIds.length, 3, "Should still have 3 songs");
    }

    function testEdgeCase_DestroyAlbumThenAccessIt() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        vm.prank(artist1);
        AlbumFacet(address(diamond)).destroyAlbum(albumId);

        // Try to access destroyed album
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumId, 0, "Destroyed album should return empty struct");

        // Try to operate on destroyed album
        vm.startPrank(artist1);
        vm.expectRevert();
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);
        vm.stopPrank();
    }

    function testSecurity_CannotUseOtherArtistsSongs() public {
        // Artist2 creates songs
        uint256[] memory artist2Songs = _createSongsForArtist(artist2, 3);

        // Artist1 tries to create album with artist2's songs
        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, artist2Songs);
        vm.stopPrank();
    }

    function testSecurity_CannotUpdateOtherArtistsAlbums() public {
        (uint256 album1,) = _createAlbumWithSongs(artist1, 3);
        (uint256 album2,) = _createAlbumWithSongs(artist2, 3);

        // Artist1 cannot update artist2's album
        vm.startPrank(artist1);
        vm.expectRevert();
        AlbumFacet(address(diamond)).updateAlbumMetaData(album2, UPDATED_ALBUM_CID);
        vm.stopPrank();

        // Artist2 cannot update artist1's album
        vm.startPrank(artist2);
        vm.expectRevert();
        AlbumFacet(address(diamond)).updateAlbumMetaData(album1, UPDATED_ALBUM_CID);
        vm.stopPrank();
    }

    function testSecurity_CannotDestroyOtherArtistsAlbums() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);

        // Artist2 cannot destroy artist1's album
        vm.startPrank(artist2);
        vm.expectRevert();
        AlbumFacet(address(diamond)).destroyAlbum(albumId);
        vm.stopPrank();

        // Non-artist cannot destroy
        vm.startPrank(nonArtist);
        vm.expectRevert();
        AlbumFacet(address(diamond)).destroyAlbum(albumId);
        vm.stopPrank();
    }

    function testSecurity_OnlyOriginalArtistCanManageAfterTransfer() public {
        (uint256 albumId,) = _createAlbumWithSongs(artist1, 3);
        LibAppStorage.Album memory album = AlbumFacet(address(diamond)).getAlbum(albumId);

        // Transfer NFT to fan
        vm.prank(artist1);
        ERC721Facet(address(diamond)).transferFrom(artist1, fan1, album.tokenId);

        // Fan owns NFT but cannot manage album
        vm.startPrank(fan1);
        vm.expectRevert();
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);
        
        vm.expectRevert();
        AlbumFacet(address(diamond)).destroyAlbum(albumId);
        vm.stopPrank();

        // Original artist can still manage
        vm.prank(artist1);
        AlbumFacet(address(diamond)).updateAlbumMetaData(albumId, UPDATED_ALBUM_CID);

        album = AlbumFacet(address(diamond)).getAlbum(albumId);
        assertEq(album.albumCID, UPDATED_ALBUM_CID, "Original artist should be able to manage");
    }

    function testSecurity_CannotMixSongsFromDifferentArtists() public {
        uint256[] memory artist1Songs = _createSongsForArtist(artist1, 2);
        uint256[] memory artist2Songs = _createSongsForArtist(artist2, 1);

        // Try to create album with mixed songs
        uint256[] memory mixedSongs = new uint256[](3);
        mixedSongs[0] = artist1Songs[0];
        mixedSongs[1] = artist2Songs[0];
        mixedSongs[2] = artist1Songs[1];

        vm.startPrank(artist1);
        vm.expectRevert(); // ErrorLib.NOT_SONG_OWNER()
        AlbumFacet(address(diamond)).publishAlbum(ALBUM1_CID, mixedSongs);
        vm.stopPrank();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}