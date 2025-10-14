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
 * @title MarketPlaceFacetTest
 * @notice Comprehensive test suite for MarketPlaceFacet functionality
 * @dev Tests cover listings, auctions, payments, royalties, and security
 */
contract MarketPlaceFacetTest is Test, IDiamondCut, DiamondUtils {
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
    uint96 _platformRoyaltyFee = 200; // 2%

    // Test accounts
    address artist1 = address(0x100);
    address artist2 = address(0x200);
    address buyer1 = address(0x300);
    address buyer2 = address(0x400);
    address buyer3 = address(0x500);
    address randomUser = address(0x600);

    // Test constants
    string constant ARTIST1_CID = "QmArtist1Profile";
    string constant SONG1_CID = "QmSong1Metadata";
    string constant SONG2_CID = "QmSong2Metadata";
    
    uint256 constant LISTING_PRICE = 1 ether;
    uint256 constant AUCTION_RESERVE = 0.5 ether;
    uint256 constant AUCTION_DURATION = 1 days;

    // Event signatures
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event AuctionCreated(uint256 indexed tokenId, address indexed seller, uint256 reservePrice, uint256 endTime);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionCancelled(uint256 indexed tokenId, address indexed seller);
    event AuctionSettled(uint256 indexed tokenId, address indexed winner, address indexed seller, uint256 amount, bool settled);


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

        // Register test artists and fund accounts
        vm.deal(artist1, 100 ether);
        vm.deal(artist2, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        vm.deal(buyer3, 100 ether);
        vm.deal(randomUser, 100 ether);

        vm.prank(artist1);
        ArtistFacet(address(diamond)).setupArtistProfile(ARTIST1_CID);

        vm.prank(artist2);
        ArtistFacet(address(diamond)).setupArtistProfile("QmArtist2Profile");
    }

    // ========== Helper Functions ==========

    /**
     * @notice Helper to create a song for an artist
     * @param artist Address of the artist
     * @return tokenId The minted song token ID
     */
    function _createSong(address artist) internal returns (uint256 tokenId) {
        vm.prank(artist);
        (uint256 songId,,,) = SongFacet(address(diamond)).uploadAndMintSong(SONG1_CID, 0);
        LibAppStorage.Song memory song = SongFacet(address(diamond)).getSongInfo(songId);
        
        tokenId = song.tokenId;
        
        vm.prank(artist);
        ERC721Facet(address(diamond)).approve(address(diamond), tokenId);
        
    }

    /**
     * @notice Helper to create multiple songs for an artist
     * @param artist Address of the artist
     * @param count Number of songs to create
     * @return tokenIds Array of minted token IDs
     */
    function _createMultipleSongs(address artist, uint256 count) internal returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _createSong(artist);
        }
    }

    /**
     * @notice Helper to create listing
     */
    function _createListing(address seller, uint256 tokenId, uint256 price) internal {
        vm.prank(seller);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, price, address(0));

        vm.prank(seller);
        ERC721Facet(address(diamond)).approve(address(diamond), tokenId);
    }

    /**
     * @notice Helper to create auction
     */
    function _createAuction(address seller, uint256 tokenId, uint256 reserve, uint256 duration) internal {
        vm.prank(seller);
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, reserve, duration, address(0));

        vm.prank(seller);
        ERC721Facet(address(diamond)).approve(address(diamond), tokenId);
    }

    function testCreateListing_Success() public {
        uint256 tokenId = _createSong(artist1);

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit Listed(tokenId, artist1, LISTING_PRICE);

        // Create listing
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));

        // Verify listing
        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertEq(listing.seller, artist1, "Seller should match");
        assertEq(listing.price, LISTING_PRICE, "Price should match");
        assertTrue(listing.active, "Listing should be active");
        assertEq(listing.erc20Address, address(0), "Should be ETH listing");

        // Verify token still owned by seller
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), artist1, "Seller should still own token");
    }

    function testCreateListing_MultipleListings() public {
        uint256[] memory tokenIds = _createMultipleSongs(artist1, 3);

        vm.startPrank(artist1);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 price = (i + 1) * 1 ether;
            MarketPlaceFacet(address(diamond)).createListing(tokenIds[i], price, address(0));
        }
        vm.stopPrank();

        // Verify all listings
        for (uint256 i = 0; i < tokenIds.length; i++) {
            LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenIds[i]);
            assertTrue(listing.active, "Each listing should be active");
            assertEq(listing.seller, artist1, "Seller should match");
        }
    }

    function testCreateListing_DifferentSellers() public {
        uint256 token1 = _createSong(artist1);
        uint256 token2 = _createSong(artist2);

        _createListing(artist1, token1, 1 ether);
        _createListing(artist2, token2, 2 ether);

        LibAppStorage.Listing memory listing1 = MarketPlaceFacet(address(diamond)).getListing(token1);
        LibAppStorage.Listing memory listing2 = MarketPlaceFacet(address(diamond)).getListing(token2);

        assertEq(listing1.seller, artist1, "Listing 1 seller should match");
        assertEq(listing2.seller, artist2, "Listing 2 seller should match");
        assertEq(listing1.price, 1 ether, "Listing 1 price should match");
        assertEq(listing2.price, 2 ether, "Listing 2 price should match");
    }

    function testCreateListing_Reverts() public {
        uint256 tokenId = _createSong(artist1);

        // Test: Zero price
        vm.startPrank(artist1);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.INVALID_PRICE.selector));
        MarketPlaceFacet(address(diamond)).createListing(tokenId, 0, address(0));
        vm.stopPrank();

        // Test: Not token owner
        vm.startPrank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.NOT_TOKEN_OWNER.selector));
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));
        vm.stopPrank();

        // // Test: Price too low (below royalty + fees)
        // vm.startPrank(artist1);
        // vm.expectRevert(abi.encodeWithSelector(ErrorLib.LISTING_PRICE_TOO_LOW.selector)); // ErrorLib.LISTING_PRICE_TOO_LOW()
        // MarketPlaceFacet(address(diamond)).createListing(tokenId, 1 wei, address(0));
        // vm.stopPrank();

        // Create valid listing first
        _createListing(artist1, tokenId, LISTING_PRICE);

        // Test: Already listed
        vm.startPrank(artist1);
        vm.expectRevert("Already listed");
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));
        vm.stopPrank();
    }
    

    // ========== cancelListing Tests ==========

    function testCancelListing_Success() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, LISTING_PRICE);

        // Expect event
        vm.expectEmit(true, true, false, false);
        emit ListingCancelled(tokenId, artist1);

        // Cancel listing
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).cancelListing(tokenId);

        // Verify listing removed
        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertFalse(listing.active, "Listing should be inactive");
        assertEq(listing.seller, address(0), "Seller should be zero");
        assertEq(listing.price, 0, "Price should be zero");
    }

    function testCancelListing_Reverts() public {
        uint256 tokenId = _createSong(artist1);

        // Test: Not listed
        vm.startPrank(artist1);
        vm.expectRevert("Not listed");
        MarketPlaceFacet(address(diamond)).cancelListing(tokenId);
        vm.stopPrank();

        // Create listing
        _createListing(artist1, tokenId, LISTING_PRICE);

        // Test: Not seller
        vm.startPrank(buyer1);
        vm.expectRevert("Not seller");
        MarketPlaceFacet(address(diamond)).cancelListing(tokenId);
        vm.stopPrank();
    }

    // ========== buyNow Tests ==========

    function testBuyNow_Success() public {
        uint256 tokenId = _createSong(artist1);
        console.log("Token Listing Price: ", LISTING_PRICE);
        
        _createListing(artist1, tokenId, LISTING_PRICE);

        uint256 artistBalanceBefore = artist1.balance;
        uint256 platformBalanceBefore = newPlatformFeeAddress.balance;

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit Bought(tokenId, buyer1, artist1, LISTING_PRICE);

        // Buy now
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE}(tokenId, address(0));
        console.log("Token Buying Price: ", LISTING_PRICE);

        // Verify ownership transfer
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), buyer1, "Buyer should own token");

        // Verify listing removed
        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertFalse(listing.active, "Listing should be inactive");

        // Verify payments distributed (artist received funds after royalties/fees)
        assertGt(artist1.balance, artistBalanceBefore, "Artist should receive payment");
        assertGt(newPlatformFeeAddress.balance, platformBalanceBefore, "Platform should receive fee");
    }

    function testBuyNow_MultipleTransactions() public {
        // Create 3 listings
        uint256[] memory tokenIds = _createMultipleSongs(artist1, 3);
        
        vm.startPrank(artist1);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            MarketPlaceFacet(address(diamond)).createListing(tokenIds[i], LISTING_PRICE, address(0));
        }
        vm.stopPrank();

        // Buy all tokens with different buyers
        address[] memory buyers = new address[](3);
        buyers[0] = buyer1;
        buyers[1] = buyer2;
        buyers[2] = buyer3;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.prank(buyers[i]);
            MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE}(tokenIds[i], address(0));
            
            // Verify ownership
            assertEq(ERC721Facet(address(diamond)).ownerOf(tokenIds[i]), buyers[i], "Buyer should own token");
        }
    }

    function testBuyNow_Reverts() public {
        uint256 tokenId = _createSong(artist1);

        // Test: Not listed
        vm.startPrank(buyer1);
        vm.expectRevert("Not listed");
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE}(tokenId, address(0));
        vm.stopPrank();

        // Create listing
        _createListing(artist1, tokenId, LISTING_PRICE);

        vm.startPrank(buyer1);

        // Test: Incorrect ETH amount (too low)
        vm.expectRevert("Incorrect ETH amount");
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE - 1}(tokenId, address(0));

        // Test: Incorrect ETH amount (too high)
        vm.expectRevert("Incorrect ETH amount");
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE + 1}(tokenId, address(0));

        vm.stopPrank();
    }

    // ========== createAuction Tests ==========

    function testCreateAuction_Success() public {
        uint256 tokenId = _createSong(artist1);
        uint256 endTime = block.timestamp + AUCTION_DURATION;

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit AuctionCreated(tokenId, artist1, AUCTION_RESERVE, endTime);

        // Create auction
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, AUCTION_DURATION, address(0));

        // Verify auction
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.seller, artist1, "Seller should match");
        assertEq(auction.reservePrice, AUCTION_RESERVE, "Reserve price should match");
        assertEq(auction.endTime, endTime, "End time should match");
        assertEq(auction.highestBid, 0, "No bids yet");
        assertEq(auction.highestBidder, address(0), "No bidder yet");
        assertFalse(auction.settled, "Should not be settled");
        assertEq(auction.erc20TokenAddress, address(0), "Should be ETH auction");
    }

    function testCreateAuction_MultipleAuctions() public {
        uint256[] memory tokenIds = _createMultipleSongs(artist1, 3);

        vm.startPrank(artist1);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 reserve = (i + 1) * 0.5 ether;
            MarketPlaceFacet(address(diamond)).createAuction(tokenIds[i], reserve, AUCTION_DURATION, address(0));
        }
        vm.stopPrank();

        // Verify all auctions
        for (uint256 i = 0; i < tokenIds.length; i++) {
            LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenIds[i]);
            assertEq(auction.seller, artist1, "Seller should match");
            assertEq(auction.reservePrice, (i + 1) * 0.5 ether, "Reserve should match");
        }
    }

    function testCreateAuction_Reverts() public {
        uint256 tokenId = _createSong(artist1);

        // Test: Duration too short
        vm.startPrank(artist1);
        vm.expectRevert("Duration too short");
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, 30 seconds, address(0));
        vm.stopPrank();

        // Test: Not token owner
        vm.startPrank(buyer1);
        vm.expectRevert("Not token owner");
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, AUCTION_DURATION, address(0));
        vm.stopPrank();
    }

    // ========== placeBid Tests ==========

    function testPlaceBid_FirstBid() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(tokenId, buyer1, AUCTION_RESERVE);

        // Place bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        // Verify bid
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBidder, buyer1, "Highest bidder should be buyer1");
        assertEq(auction.highestBid, AUCTION_RESERVE, "Highest bid should match reserve");
    }

    function testPlaceBid_MultipleBids() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        uint256 buyer1BalanceBefore = buyer1.balance;
        uint256 buyer2BalanceBefore = buyer2.balance;

        // First bid from buyer1
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        // Calculate minimum increment (5% of current bid)
        uint256 minIncrement = (AUCTION_RESERVE * 500) / 10000;
        uint256 secondBid = AUCTION_RESERVE + minIncrement;

        // Second bid from buyer2 (should refund buyer1)
        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).placeBid{value: secondBid}(tokenId, 0);

        // Verify auction state
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBidder, buyer2, "Highest bidder should be buyer2");
        assertEq(auction.highestBid, secondBid, "Highest bid should be updated");

        // Verify buyer1 was refunded
        assertEq(buyer1.balance, buyer1BalanceBefore, "Buyer1 should be refunded");

        // Third bid from buyer3
        uint256 thirdBid = secondBid + ((secondBid * 500) / 10000);
        vm.prank(buyer3);
        MarketPlaceFacet(address(diamond)).placeBid{value: thirdBid}(tokenId, 0);

        auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBidder, buyer3, "Highest bidder should be buyer3");
        
        // Verify buyer2 was refunded
        assertEq(buyer2.balance, buyer2BalanceBefore, "Buyer2 should be refunded");
    }

    function testPlaceBid_Reverts() public {
        uint256 tokenId = _createSong(artist1);

        // Test: Auction not found
        vm.startPrank(buyer1);
        vm.expectRevert(); // ErrorLib.AUNCTION_NOT_FOUND()
        MarketPlaceFacet(address(diamond)).placeBid{value: 1 ether}(tokenId, 0);
        vm.stopPrank();

        // Create auction
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        vm.startPrank(buyer1);

        // Test: No bid (zero value)
        vm.expectRevert("No bid");
        MarketPlaceFacet(address(diamond)).placeBid{value: 0}(tokenId, 0);

        // Test: Bid below reserve
        vm.expectRevert(); // ErrorLib.BID_TOO_LOW()
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE - 1}(tokenId, 0);

        // Place valid first bid
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);
        vm.stopPrank();

        // Test: Second bid below minimum increment
        vm.startPrank(buyer2);
        vm.expectRevert(); // ErrorLib.BID_TOO_LOW()
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE + 1 wei}(tokenId, 0);
        vm.stopPrank();

        // Test: Bid after auction ended
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        vm.startPrank(buyer2);
        vm.expectRevert(); // ErrorLib.AUNCTION_ENED()
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE * 2}(tokenId, 0);
        vm.stopPrank();
    }

    function testPlaceBid_MinimumIncrementCalculation() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, 1 ether, AUCTION_DURATION);

        // First bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: 1 ether}(tokenId, 0);

        // Calculate exact minimum (5% increment)
        uint256 minIncrement = (1 ether * 500) / 10000; // 0.05 ether
        uint256 minBid = 1 ether + minIncrement;

        // Bid exactly the minimum
        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).placeBid{value: minBid}(tokenId, 0);

        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBid, minBid, "Should accept exact minimum bid");
    }

       // ========== cancelAuction Tests ==========

    function testCancelAuction_Success() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Expect event
        vm.expectEmit(true, true, false, false);
        emit AuctionCancelled(tokenId, artist1);

        // Cancel auction
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).cancelAuction(tokenId);

        // Verify auction removed
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.seller, address(0), "Seller should be zero");
        assertEq(auction.reservePrice, 0, "Reserve should be zero");
    }

    function testCancelAuction_Reverts() public {
        uint256 tokenId = _createSong(artist1);

        // Test: Auction not found
        vm.startPrank(artist1);
        vm.expectRevert("Auction not found");
        MarketPlaceFacet(address(diamond)).cancelAuction(tokenId);
        vm.stopPrank();

        // Create auction
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Test: Not seller
        vm.startPrank(buyer1);
        vm.expectRevert("Not seller");
        MarketPlaceFacet(address(diamond)).cancelAuction(tokenId);
        vm.stopPrank();

        // Place a bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        // Test: Already has bids
        vm.startPrank(artist1);
        vm.expectRevert("Already has bids");
        MarketPlaceFacet(address(diamond)).cancelAuction(tokenId);
        vm.stopPrank();
    }

     // ========== settleAuction Tests ==========

    function testSettleAuction_Success() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Place winning bid
        uint256 winningBid = AUCTION_RESERVE * 2;
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: winningBid}(tokenId, 0);

        // Warp time to after auction end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        uint256 artistBalanceBefore = artist1.balance;
        uint256 platformBalanceBefore = newPlatformFeeAddress.balance;

        // Expect event
        vm.expectEmit(true, true, true, false);
        emit AuctionSettled(tokenId, buyer1, artist1, winningBid, true);


        // Settle auction
        MarketPlaceFacet(address(diamond)).settleAuction(tokenId);

        // Verify ownership transfer
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), buyer1, "Winner should own token");

        // Verify payments distributed
        assertGt(artist1.balance, artistBalanceBefore, "Artist should receive payment");
        assertGt(newPlatformFeeAddress.balance, platformBalanceBefore, "Platform should receive fee");

        // Verify auction marked as settled
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertTrue(auction.settled, "Auction should be marked as settled");
    }

    function testSettleAuction_MultipleBiddersRefunded() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        uint256 buyer1BalanceBefore = buyer1.balance;
        uint256 buyer2BalanceBefore = buyer2.balance;

        // Multiple bids
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        uint256 bid2 = AUCTION_RESERVE + ((AUCTION_RESERVE * 500) / 10000);
        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).placeBid{value: bid2}(tokenId, 0);

        uint256 bid3 = bid2 + ((bid2 * 500) / 10000);
        vm.prank(buyer3);
        MarketPlaceFacet(address(diamond)).placeBid{value: bid3}(tokenId, 0);

        // Verify intermediate refunds happened
        assertEq(buyer1.balance, buyer1BalanceBefore, "Buyer1 should be refunded");
        assertEq(buyer2.balance, buyer2BalanceBefore, "Buyer2 should be refunded");

        // Settle auction
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        MarketPlaceFacet(address(diamond)).settleAuction(tokenId);

        // Verify winner owns token
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), buyer3, "Buyer3 should win");
    }

    function testSettleAuction_Reverts() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Place bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        // Test: Auction not ended
        vm.expectRevert("Auction not ended");
        MarketPlaceFacet(address(diamond)).settleAuction(tokenId);

        // Warp to after end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        MarketPlaceFacet(address(diamond)).settleAuction(tokenId);

        // auction should have been settled to true
        vm.expectRevert("Auction not active");
        MarketPlaceFacet(address(diamond)).settleAuction(tokenId);
    }

     // ========== Integration Tests ==========

    function testIntegration_CompleteListingFlow() public {
        uint256 tokenId = _createSong(artist1);

        // 1. Create listing
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));

        // 2. Verify listing exists
        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertTrue(listing.active, "Listing should be active");

        // 3. Buy token
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE}(tokenId, address(0));

        // 4. Verify ownership changed
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), buyer1, "Buyer should own token");

        // 5. Verify listing removed
        listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertFalse(listing.active, "Listing should be removed");

        // 6. Buyer can now list the token
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE * 2, address(0));

        listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertEq(listing.seller, buyer1, "Buyer1 should be new seller");
        assertEq(listing.price, LISTING_PRICE * 2, "Price should be doubled");
    }

    function testIntegration_CompleteAuctionFlow() public {
        uint256 tokenId = _createSong(artist1);

        // 1. Create auction
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, AUCTION_DURATION, address(0));

        // 2. Multiple bids
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        uint256 bid2 = AUCTION_RESERVE + ((AUCTION_RESERVE * 500) / 10000);
        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).placeBid{value: bid2}(tokenId, 0);

        uint256 bid3 = bid2 + ((bid2 * 500) / 10000);
        vm.prank(buyer3);
        MarketPlaceFacet(address(diamond)).placeBid{value: bid3}(tokenId, 0);

        // 3. Wait for auction to end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // 4. Settle auction
        MarketPlaceFacet(address(diamond)).settleAuction(tokenId);

        // 5. Verify winner owns token
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), buyer3, "Highest bidder should win");

        // 6. Winner can create new listing
        vm.prank(buyer3);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));

        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertEq(listing.seller, buyer3, "Winner should be able to list");
    }

    function testIntegration_CancelListingAndCreateAuction() public {
        uint256 tokenId = _createSong(artist1);

        // 1. Create listing
        vm.startPrank(artist1);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));

        // 2. Cancel listing
        MarketPlaceFacet(address(diamond)).cancelListing(tokenId);

        // 3. Create auction instead
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, AUCTION_DURATION, address(0));
        vm.stopPrank();

        // Verify auction exists
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.seller, artist1, "Auction should exist");

        // Verify listing doesn't exist
        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        assertFalse(listing.active, "Listing should not exist");
    }

    function testIntegration_MultipleTokensMarketplace() public {
        // Create 5 tokens
        uint256[] memory tokenIds = _createMultipleSongs(artist1, 5);

        vm.startPrank(artist1);
        
        // List 3 tokens
        for (uint256 i = 0; i < 3; i++) {
            MarketPlaceFacet(address(diamond)).createListing(tokenIds[i], (i + 1) * 1 ether, address(0));
        }

        // Auction 2 tokens
        for (uint256 i = 3; i < 5; i++) {
            MarketPlaceFacet(address(diamond)).createAuction(
                tokenIds[i],
                0.5 ether,
                AUCTION_DURATION,
                address(0)
            );
        }
        vm.stopPrank();

        // Buy 2 listed tokens
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).buyNow{value: 1 ether}(tokenIds[0], address(0));

        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).buyNow{value: 2 ether}(tokenIds[1], address(0));

        // Bid on auctions
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: 0.5 ether}(tokenIds[3], 0);

        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).placeBid{value: 0.5 ether}(tokenIds[4], 0);

        // Verify states
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenIds[0]), buyer1, "Buyer1 owns token 0");
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenIds[1]), buyer2, "Buyer2 owns token 1");
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenIds[2]), artist1, "Artist still owns token 2");

        LibAppStorage.Auction memory auction3 = MarketPlaceFacet(address(diamond)).getAuction(tokenIds[3]);
        assertEq(auction3.highestBidder, buyer1, "Buyer1 is highest bidder on auction 3");

        LibAppStorage.Auction memory auction4 = MarketPlaceFacet(address(diamond)).getAuction(tokenIds[4]);
        assertEq(auction4.highestBidder, buyer2, "Buyer2 is highest bidder on auction 4");
    }

    function testIntegration_RoyaltyDistribution() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, 10 ether);

        uint256 artistBalanceBefore = artist1.balance;
        uint256 platformBalanceBefore = newPlatformFeeAddress.balance;

        // Buy token
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).buyNow{value: 10 ether}(tokenId, address(0));

        uint256 artistBalanceAfter = artist1.balance;
        uint256 platformBalanceAfter = newPlatformFeeAddress.balance;

        // Calculate expected distributions
        // Platform fee: 2% of 10 ether = 0.2 ether
        // Artist royalty: 5% of 10 ether = 0.5 ether
        // Seller gets: 10 - 0.2 - 0.5 = 9.3 ether

        uint256 artistReceived = artistBalanceAfter - artistBalanceBefore;
        uint256 platformReceived = platformBalanceAfter - platformBalanceBefore;

        // Artist is also the seller in this case
        assertGt(artistReceived, 9 ether, "Artist should receive significant portion");
        assertGt(platformReceived, 0.1 ether, "Platform should receive fee");
    }

    // ADD TEST FOR ERC20 TOKEN REWARD DISTRIBUTION
    // HERE...


    function testIntegration_SecondaryMarketRoyalties() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, 1 ether);

        // First sale: artist to buyer1
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).buyNow{value: 1 ether}(tokenId, address(0));

        uint256 artistBalanceBeforeSecondary = artist1.balance;

         //  Approve the diamond to handle transfer on secondary sale
        vm.prank(buyer1);
        ERC721Facet(address(diamond)).approve(address(diamond), tokenId);

        // Second sale: buyer1 to buyer2 (artist should still get royalties)
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).createListing(tokenId, 2 ether, address(0));

       

        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).buyNow{value: 2 ether}(tokenId, address(0));

        uint256 artistBalanceAfterSecondary = artist1.balance;

        // Artist should receive royalties even though they're not the seller
        assertGt(artistBalanceAfterSecondary, artistBalanceBeforeSecondary, "Artist should receive royalties on secondary sale");

        // Verify final ownership
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), buyer2, "Buyer2 should own token");
    }

    // ========== Edge Cases & Security Tests ==========

    function testEdgeCase_ListAndAuctionSameToken() public {
        uint256 tokenId = _createSong(artist1);

        vm.startPrank(artist1);
        
        // Create listing
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));

        // Should be able to create auction (they're independent)
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, AUCTION_DURATION, address(0));

        vm.stopPrank();

        // Both should exist
        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);

        assertTrue(listing.active, "Listing should exist");
        assertEq(auction.seller, artist1, "Auction should exist");
    }

    function testEdgeCase_BuyOwnListing() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, LISTING_PRICE);

        // Artist tries to buy their own listing
        vm.prank(artist1);
        // This should technically work but transfer to self
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE}(tokenId, address(0));

        // Verify artist still owns it
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), artist1, "Artist still owns token");
    }

    function testEdgeCase_BidOwnAuction() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Artist tries to bid on own auction (should work technically)
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBidder, artist1, "Artist is highest bidder");
    }

    function testEdgeCase_ZeroReserveAuction() public {
        uint256 tokenId = _createSong(artist1);

        // Create auction with zero reserve
        vm.prank(artist1);
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, 0, AUCTION_DURATION, address(0));

        // Should accept any bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: 1 wei}(tokenId, 0);

        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBid, 1 wei, "Should accept 1 wei bid");
    }

    function testEdgeCase_AuctionNoBids() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // No bids placed, auction ends
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Should be able to cancel even after end if no bids
        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);
        assertEq(auction.highestBid, 0, "No bids");
        
        // Artist still owns token
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), artist1, "Artist still owns");
    }

    function testSecurity_CannotListOthersTokens() public {
        uint256 tokenId = _createSong(artist1);

        // Buyer1 tries to list artist1's token
        vm.startPrank(buyer1);
        vm.expectRevert(); // ErrorLib.NOT_TOKEN_OWNER()
        MarketPlaceFacet(address(diamond)).createListing(tokenId, LISTING_PRICE, address(0));
        vm.stopPrank();
    }

    function testSecurity_CannotAuctionOthersTokens() public {
        uint256 tokenId = _createSong(artist1);

        // Buyer1 tries to auction artist1's token
        vm.startPrank(buyer1);
        vm.expectRevert("Not token owner");
        MarketPlaceFacet(address(diamond)).createAuction(tokenId, AUCTION_RESERVE, AUCTION_DURATION, address(0));
        vm.stopPrank();
    }

    function testSecurity_CannotCancelOthersListing() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, LISTING_PRICE);

        // Buyer1 tries to cancel artist1's listing
        vm.startPrank(buyer1);
        vm.expectRevert("Not seller");
        MarketPlaceFacet(address(diamond)).cancelListing(tokenId);
        vm.stopPrank();
    }

    function testSecurity_CannotCancelOthersAuction() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Buyer1 tries to cancel artist1's auction
        vm.startPrank(buyer1);
        vm.expectRevert("Not seller");
        MarketPlaceFacet(address(diamond)).cancelAuction(tokenId);
        vm.stopPrank();
    }

    function testSecurity_CannotCancelAuctionWithBids() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Place bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        // Artist tries to cancel
        vm.startPrank(artist1);
        vm.expectRevert("Already has bids");
        MarketPlaceFacet(address(diamond)).cancelAuction(tokenId);
        vm.stopPrank();
    }

    function testSecurity_BidRefundPrevention() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // First bid
        vm.prank(buyer1);
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);

        uint256 buyer1BalanceBefore = buyer1.balance;

        // Second bid should refund first
        uint256 secondBid = AUCTION_RESERVE + ((AUCTION_RESERVE * 500) / 10000);
        vm.prank(buyer2);
        MarketPlaceFacet(address(diamond)).placeBid{value: secondBid}(tokenId, 0);

        // Verify buyer1 was refunded
        assertEq(buyer1.balance, buyer1BalanceBefore + AUCTION_RESERVE, "Buyer1 should be fully refunded");
    }

    function testSecurity_PaymentMustMatchListingPrice() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, LISTING_PRICE);

        // Try to pay less
        vm.startPrank(buyer1);
        vm.expectRevert("Incorrect ETH amount");
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE - 0.1 ether}(tokenId, address(0));

        // Try to pay more
        vm.expectRevert("Incorrect ETH amount");
        MarketPlaceFacet(address(diamond)).buyNow{value: LISTING_PRICE + 0.1 ether}(tokenId, address(0));
        vm.stopPrank();
    }

    function testSecurity_CannotBidAfterAuctionEnds() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        // Warp past end time
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Try to bid
        vm.startPrank(buyer1);
        vm.expectRevert(); // ErrorLib.AUNCTION_ENED()
        MarketPlaceFacet(address(diamond)).placeBid{value: AUCTION_RESERVE}(tokenId, 0);
        vm.stopPrank();
    }



    // ========== Getter Function Tests ==========

    function testGetListing_ValidListing() public {
        uint256 tokenId = _createSong(artist1);
        _createListing(artist1, tokenId, LISTING_PRICE);

        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);

        assertEq(listing.seller, artist1, "Seller should match");
        assertEq(listing.price, LISTING_PRICE, "Price should match");
        assertTrue(listing.active, "Should be active");
        assertEq(listing.erc20Address, address(0), "Should be ETH");
    }

    function testGetListing_NoListing() public {
        uint256 tokenId = _createSong(artist1);

        LibAppStorage.Listing memory listing = MarketPlaceFacet(address(diamond)).getListing(tokenId);

        assertEq(listing.seller, address(0), "Should be zero");
        assertEq(listing.price, 0, "Should be zero");
        assertFalse(listing.active, "Should be inactive");
    }

    function testGetAuction_ValidAuction() public {
        uint256 tokenId = _createSong(artist1);
        _createAuction(artist1, tokenId, AUCTION_RESERVE, AUCTION_DURATION);

        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);

        assertEq(auction.seller, artist1, "Seller should match");
        assertEq(auction.reservePrice, AUCTION_RESERVE, "Reserve should match");
        assertGt(auction.endTime, block.timestamp, "End time should be in future");
        assertEq(auction.erc20TokenAddress, address(0), "Should be ETH");
    }

    function testGetAuction_NoAuction() public {
        uint256 tokenId = _createSong(artist1);

        LibAppStorage.Auction memory auction = MarketPlaceFacet(address(diamond)).getAuction(tokenId);

        assertEq(auction.seller, address(0), "Should be zero");
        assertEq(auction.reservePrice, 0, "Should be zero");
        assertEq(auction.highestBid, 0, "Should be zero");
    }

    // function testSecurity_ListingPriceMustCoverFees() public {
    //     uint256 tokenId = _createSong(artist1);

    //     // Try to list at price that's too low to cover royalties + fees
    //     vm.startPrank(artist1);
    //     vm.expectRevert(); // ErrorLib.LISTING_PRICE_TOO_LOW()
    //     MarketPlaceFacet(address(diamond)).createListing(tokenId, 100 wei, address(0));
    //     vm.stopPrank();
    // }





    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}