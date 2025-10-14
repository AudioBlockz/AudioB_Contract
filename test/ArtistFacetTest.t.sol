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
import "../contracts/RoyaltySplitter.sol" as RSplitter;
import "../contracts/facets/HelperFacet.sol";
import "../contracts/libraries/ErrorLib.sol";

import {console} from "forge-std/console.sol";

contract ArtistFacetTest is Test, IDiamondCut, DiamondUtils {
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

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

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
    }

    function testPlatFormSetUp() public {
        (address _platformReceiver, uint96 _platformFee) = OwnershipControlFacet(address(diamond)).getPlatformRoyalty();
        console.log("Platform Receiver: ", _platformReceiver);
        console.log("Platform Fee: ", _platformFee);

        assertEq(_platformReceiver, newPlatformFeeAddress, "Set Platform Address failed");
        assertEq(_platformFee, 200, "Set Platform fee failed");
    }

    function testSetupArtistProfile_Success() public {
        string memory cid = "QmTestArtistCID123";

        vm.startPrank(artist1);
        (uint256 artistId, address artistAddress, string memory returnedCid, uint256 tokenId) =
            ArtistFacet(address(diamond)).setupArtistProfile(cid);
        vm.stopPrank();

        // Verify return values
        assertEq(artistId, 1, "Artist ID should be 1");
        assertEq(artistAddress, artist1, "Artist address should match");
        assertEq(returnedCid, cid, "CID should match");
        assertEq(tokenId, 1, "Token ID should be 1");

        // Verify artist info is stored correctly
        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertEq(artist.artistId, 1, "Stored artist ID should be 1");
        assertEq(artist.artistAddress, artist1, "Stored artist address should match");
        assertEq(artist.artistCid, cid, "Stored CID should match");
        assertEq(artist.artistTokenId, tokenId, "Stored token ID should match");
        assertTrue(artist.isRegistered, "Artist should be registered");

        // Verify artist balance is initialized
        uint256 balance = ArtistFacet(address(diamond)).getArtistBalance(artist1);
        assertEq(balance, 0, "Initial balance should be 0");

        // Verify token is marked as artist token
        assertTrue(
            ArtistFacet(address(diamond)).isArtistTokenConfirm(tokenId), "Token should be marked as artist token"
        );

        // Verify NFT ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), artist1, "Artist should own the token");

        // Verify tokenURI
        string memory expectedURI = string(abi.encodePacked("ipfs://", cid));
        assertEq(ERC721Facet(address(diamond)).tokenURI(tokenId), expectedURI, "Token URI should be correct");
    }

    function testSetupArtistProfile_MultipleArtists() public {
        string memory cid1 = "QmArtist1CID";
        string memory cid2 = "QmArtist2CID";
        string memory cid3 = "QmArtist3CID";

        // Register artist 1
        vm.prank(artist1);
        (uint256 artistId1,,, uint256 tokenId1) = ArtistFacet(address(diamond)).setupArtistProfile(cid1);

        // Register artist 2
        vm.prank(artist2);
        (uint256 artistId2,,, uint256 tokenId2) = ArtistFacet(address(diamond)).setupArtistProfile(cid2);

        // Register artist 3
        vm.prank(artist3);
        (uint256 artistId3,,, uint256 tokenId3) = ArtistFacet(address(diamond)).setupArtistProfile(cid3);

        // Verify unique IDs
        assertEq(artistId1, 1, "First artist ID should be 1");
        assertEq(artistId2, 2, "Second artist ID should be 2");
        assertEq(artistId3, 3, "Third artist ID should be 3");

        assertEq(tokenId1, 1, "First token ID should be 1");
        assertEq(tokenId2, 2, "Second token ID should be 2");
        assertEq(tokenId3, 3, "Third token ID should be 3");

        // Verify each artist info
        LibAppStorage.Artist memory a1 = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        LibAppStorage.Artist memory a2 = ArtistFacet(address(diamond)).getArtistInfo(artist2);
        LibAppStorage.Artist memory a3 = ArtistFacet(address(diamond)).getArtistInfo(artist3);

        assertTrue(a1.isRegistered && a2.isRegistered && a3.isRegistered, "All artists should be registered");
        assertEq(a1.artistCid, cid1, "Artist 1 CID should match");
        assertEq(a2.artistCid, cid2, "Artist 2 CID should match");
        assertEq(a3.artistCid, cid3, "Artist 3 CID should match");
    }

    function testSetupArtistProfile_RevertWhen_EmptyCID() public {
        vm.startPrank(artist1);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidCid.selector)); // ErrorLib.InvalidCid()
        ArtistFacet(address(diamond)).setupArtistProfile("");
        vm.stopPrank();
    }

    function testSetupArtistProfile_RevertWhen_AlreadyRegistered() public {
        string memory cid = "QmTestCID";

        vm.startPrank(artist1);
        ArtistFacet(address(diamond)).setupArtistProfile(cid);

        // Try to register again
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.ARTIST_ALREADY_REGISTERED.selector));
        ArtistFacet(address(diamond)).setupArtistProfile("QmAnotherCID");
        vm.stopPrank();
    }

    function testUpdateArtistProfile_Success() public {
        string memory originalCid = "QmOriginalCID";
        string memory updatedCid = "QmUpdatedCID";

        // Setup artist profile
        vm.startPrank(artist1);
        (uint256 artistId,,, uint256 tokenId) = ArtistFacet(address(diamond)).setupArtistProfile(originalCid);

        // Update artist profile
        (uint256 returnedArtistId, address returnedAddress, string memory returnedCid) =
            ArtistFacet(address(diamond)).updateArtistProfile(updatedCid);
        vm.stopPrank();

        // Verify return values
        assertEq(returnedArtistId, artistId, "Artist ID should match");
        assertEq(returnedAddress, artist1, "Artist address should match");
        assertEq(returnedCid, updatedCid, "Updated CID should match");

        // Verify artist info is updated
        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertEq(artist.artistCid, updatedCid, "CID should be updated");

        // Verify artist info by ID is also updated
        LibAppStorage.Artist memory artistById = ArtistFacet(address(diamond)).getArtistInfoById(artistId);
        assertEq(artistById.artistCid, updatedCid, "CID should be updated in artistIdToArtist mapping");

        // Verify tokenURI is updated
        string memory expectedURI = string(abi.encodePacked("ipfs://", updatedCid));
        assertEq(ERC721Facet(address(diamond)).tokenURI(tokenId), expectedURI, "Token URI should be updated");
    }

    function testUpdateArtistProfile_MultipleUpdates() public {
        string memory cid1 = "QmCID1";
        string memory cid2 = "QmCID2";
        string memory cid3 = "QmCID3";

        vm.startPrank(artist1);

        // Setup
        (,,, uint256 tokenId) = ArtistFacet(address(diamond)).setupArtistProfile(cid1);

        // First update
        ArtistFacet(address(diamond)).updateArtistProfile(cid2);
        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertEq(artist.artistCid, cid2, "CID should be updated to cid2");

        // Second update
        ArtistFacet(address(diamond)).updateArtistProfile(cid3);
        artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertEq(artist.artistCid, cid3, "CID should be updated to cid3");

        vm.stopPrank();

        // Verify final tokenURI
        string memory expectedURI = string(abi.encodePacked("ipfs://", cid3));
        assertEq(ERC721Facet(address(diamond)).tokenURI(tokenId), expectedURI, "Token URI should reflect final update");
    }

    function testUpdateArtistProfile_RevertWhen_NotRegistered() public {
        vm.startPrank(nonArtist);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.ARTIST_NOT_FOUND.selector));
        ArtistFacet(address(diamond)).updateArtistProfile("QmTestCID");
        vm.stopPrank();
    }

    function testUpdateArtistProfile_RevertWhen_EmptyCID() public {
        string memory originalCid = "QmOriginalCID";

        vm.startPrank(artist1);
        ArtistFacet(address(diamond)).setupArtistProfile(originalCid);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidCid.selector)); // ErrorLib.InvalidCid()
        ArtistFacet(address(diamond)).updateArtistProfile("");
        vm.stopPrank();
    }

    // ========== getArtistInfo Tests ==========

    function testGetArtistInfo_RegisteredArtist() public {
        string memory cid = "QmTestCID";

        vm.prank(artist1);
        (uint256 artistId,,, uint256 tokenId) = ArtistFacet(address(diamond)).setupArtistProfile(cid);

        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);

        assertEq(artist.artistId, artistId, "Artist ID should match");
        assertEq(artist.artistAddress, artist1, "Artist address should match");
        assertEq(artist.artistCid, cid, "CID should match");
        assertEq(artist.artistTokenId, tokenId, "Token ID should match");
        assertTrue(artist.isRegistered, "Should be registered");
    }

    function testGetArtistInfo_UnregisteredArtist() public {
        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(nonArtist);

        assertEq(artist.artistId, 0, "Artist ID should be 0");
        assertEq(artist.artistAddress, address(0), "Artist address should be zero");
        assertEq(artist.artistCid, "", "CID should be empty");
        assertFalse(artist.isRegistered, "Should not be registered");
    }

    // ========== getArtistBalance Tests ==========

    function testGetArtistBalance_InitialBalance() public {
        vm.prank(artist1);
        ArtistFacet(address(diamond)).setupArtistProfile("QmTestCID");

        uint256 balance = ArtistFacet(address(diamond)).getArtistBalance(artist1);
        assertEq(balance, 0, "Initial balance should be 0");
    }

    function testGetArtistBalance_UnregisteredArtist() public {
        uint256 balance = ArtistFacet(address(diamond)).getArtistBalance(nonArtist);
        assertEq(balance, 0, "Unregistered artist balance should be 0");
    }

    // ========== isArtistTokenConfirm Tests ==========

    function testIsArtistTokenConfirm_ArtistToken() public {
        vm.prank(artist1);
        (,,, uint256 tokenId) = ArtistFacet(address(diamond)).setupArtistProfile("QmTestCID");

        assertTrue(ArtistFacet(address(diamond)).isArtistTokenConfirm(tokenId), "Should be confirmed as artist token");
    }

    function testIsArtistTokenConfirm_NonArtistToken() public {
        assertFalse(ArtistFacet(address(diamond)).isArtistTokenConfirm(999), "Should not be confirmed as artist token");
    }

    function testIntegration_CompleteArtistLifecycle() public {
        string memory originalCid = "QmOriginalCID";
        string memory updatedCid = "QmUpdatedCID";

        vm.startPrank(artist1);

        // 1. Setup artist profile
        (uint256 artistId, address artistAddress, string memory cid, uint256 tokenId) =
            ArtistFacet(address(diamond)).setupArtistProfile(originalCid);

        assertEq(artistId, 1, "Artist ID should be 1");
        assertEq(artistAddress, artist1, "Artist address should match");
        assertEq(cid, originalCid, "CID should match");

        // 2. Verify artist info
        LibAppStorage.Artist memory artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertTrue(artist.isRegistered, "Should be registered");

        // 3. Verify balance
        uint256 balance = ArtistFacet(address(diamond)).getArtistBalance(artist1);
        assertEq(balance, 0, "Balance should be 0");

        // 4. Update profile
        ArtistFacet(address(diamond)).updateArtistProfile(updatedCid);

        // 5. Verify update
        artist = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertEq(artist.artistCid, updatedCid, "CID should be updated");

        // 6. Verify token details
        assertTrue(ArtistFacet(address(diamond)).isArtistTokenConfirm(tokenId), "Should be artist token");
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), artist1, "Should own token");

        vm.stopPrank();
    }

    function testIntegration_MultipleArtistsIndependence() public {
        string memory cid1 = "QmArtist1";
        string memory cid2 = "QmArtist2";

        // Setup two artists
        vm.prank(artist1);
        (uint256 artistId1,,, uint256 tokenId1) = ArtistFacet(address(diamond)).setupArtistProfile(cid1);

        vm.prank(artist2);
        (uint256 artistId2,,, uint256 tokenId2) = ArtistFacet(address(diamond)).setupArtistProfile(cid2);

        // Update artist1
        vm.prank(artist1);
        ArtistFacet(address(diamond)).updateArtistProfile("QmUpdatedArtist1");

        // Verify artist1 is updated
        LibAppStorage.Artist memory a1 = ArtistFacet(address(diamond)).getArtistInfo(artist1);
        assertEq(a1.artistCid, "QmUpdatedArtist1", "Artist 1 should be updated");

        // Verify artist2 is unchanged
        LibAppStorage.Artist memory a2 = ArtistFacet(address(diamond)).getArtistInfo(artist2);
        assertEq(a2.artistCid, cid2, "Artist 2 should be unchanged");

        // Verify token ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId1), artist1, "Artist 1 should own token 1");
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId2), artist2, "Artist 2 should own token 2");
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
