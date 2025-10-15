// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
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
import "../contracts/Diamond.sol";
import "../test/helpers/DiamondUtils_2.sol";
import {LibAppStorage} from "../contracts/libraries/LibAppStorage.sol";
import "../contracts/facets/HelperFacet.sol";
import "../contracts/libraries/ErrorLib.sol";
import "../contracts/RoyaltySplitter.sol" as RSplitter;

contract DiamondDeployer is DiamondUtils_2, IDiamondCut {

    // Constants
    uint96 constant _artistRoyaltyFee = 500; // 5%
    uint96 constant _platformRoyaltyFee = 200; // 2%
    address constant platformFeeAddress = address(0x51816a1b29569fbB1a56825C375C254742a9c5e1);

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        console.log("\n=== Generating Selectors ===");

        // Generate selectors BEFORE broadcast (FFI needs to run outside broadcast context)
        bytes4[] memory loupeSels = generateSelectors("DiamondLoupeFacet");
        bytes4[] memory ownerSels = generateSelectors("OwnershipFacet");
        bytes4[] memory artistSels = generateSelectors("ArtistFacet");
        bytes4[] memory marketSels = generateSelectors("MarketPlaceFacet");
        bytes4[] memory songSels = generateSelectors("SongFacet");
        bytes4[] memory albumSels = generateSelectors("AlbumFacet");
        bytes4[] memory erc721Sels = generateSelectors("ERC721Facet");
        bytes4[] memory controlSels = generateSelectors("OwnershipControlFacet");
        bytes4[] memory helperSels = generateSelectors("HelperFacet");

        console.log("\n=== Starting Deployment ===");
        vm.startBroadcast(privateKey);

        // Deploy the core facet
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet:", address(cutFacet));

        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        console.log("DiamondLoupeFacet:", address(dLoupe));

        OwnershipFacet ownerF = new OwnershipFacet();
        console.log("OwnershipFacet:", address(ownerF));

        // App Facets
        ArtistFacet artistF = new ArtistFacet();
        console.log("ArtistFacet:", address(artistF));

        SongFacet songF = new SongFacet();
        console.log("SongFacet:", address(songF));

        AlbumFacet albumF = new AlbumFacet();
        console.log("AlbumFacet:", address(albumF));

        MarketPlaceFacet marketF = new MarketPlaceFacet();
        console.log("MarketPlaceFacet:", address(marketF));

        ERC721Facet erc721F = new ERC721Facet();
        console.log("ERC721Facet:", address(erc721F));

        OwnershipControlFacet controlF = new OwnershipControlFacet();
        console.log("OwnershipControlFacet:", address(controlF));

        HelperFacet helperF = new HelperFacet();
        console.log("HelperFacet:", address(helperF));

        // Deploy the Royalty Splitter
        RSplitter.RoyaltySplitter royaltySplitter = new RSplitter.RoyaltySplitter();
        console.log("RoyaltySplitter:", address(royaltySplitter));
        
        // Deploy the Diamond
        Diamond diamond = new Diamond(
            deployer,
            address(cutFacet),
            platformFeeAddress,
            _artistRoyaltyFee,
            _platformRoyaltyFee,
            address(royaltySplitter)
        );
        console.log("Diamond:", address(diamond));

        console.log("\n=== Preparing Facet Cuts ===");
        
        FacetCut[] memory cut = new FacetCut[](9);

        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: loupeSels
        });

        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: ownerSels
        });

        cut[2] = FacetCut({
            facetAddress: address(artistF),
            action: FacetCutAction.Add,
            functionSelectors: artistSels
        });

        cut[3] = FacetCut({
            facetAddress: address(marketF),
            action: FacetCutAction.Add,
            functionSelectors: marketSels
        });

        cut[4] = FacetCut({
            facetAddress: address(songF),
            action: FacetCutAction.Add,
            functionSelectors: songSels
        });

        cut[5] = FacetCut({
            facetAddress: address(albumF),
            action: FacetCutAction.Add,
            functionSelectors: albumSels
        });

        cut[6] = FacetCut({
            facetAddress: address(erc721F),
            action: FacetCutAction.Add,
            functionSelectors: erc721Sels
        });

        cut[7] = FacetCut({
            facetAddress: address(controlF),
            action: FacetCutAction.Add,
            functionSelectors: controlSels
        });

        cut[8] = FacetCut({
            facetAddress: address(helperF),
            action: FacetCutAction.Add,
            functionSelectors: helperSels
        });

        // Log selector counts
        for (uint i = 0; i < cut.length; i++) {
            console.log("Facet", i, "- Selectors:", cut[i].functionSelectors.length);
            
            // Debug: print first selector to verify it's not 0x00000000
            if (cut[i].functionSelectors.length > 0) {
                console.log("  First selector:", uint32(cut[i].functionSelectors[0]));
            }
        }

        console.log("\n=== Executing Diamond Cut ===");
        
        // Perform diamond cut to add all facets
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
        console.log("Diamond cut completed!");

        // Verify deployment
        address[] memory facetAddresses = DiamondLoupeFacet(address(diamond)).facetAddresses();
        console.log("Facets installed:", facetAddresses.length);
        require(facetAddresses.length > 0, "Diamond deployment failed");

        console.log("\n=== Configuring Platform Settings ===");
        
        // Configure platform settings
        OwnershipControlFacet(address(diamond)).setPlatformRoyalty(platformFeeAddress, 200);
        OwnershipControlFacet(address(diamond)).setArtistRoyaltyFraction(500);
        
        // console.log("Platform royalty set to:", platformFeeAddress);
        // console.log("Artist royalty fraction:", 500);

        console.log("\n=================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("Diamond Address:", address(diamond));
        console.log("=================================\n");

        vm.stopBroadcast();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}