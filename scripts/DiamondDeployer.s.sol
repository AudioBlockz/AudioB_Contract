// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "forge-std/console.sol";
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
import "../test/helpers/DiamondUtils.sol";
import {LibAppStorage} from "../contracts/libraries/LibAppStorage.sol";
import "../contracts/facets/HelperFacet.sol";
import "../contracts/libraries/ErrorLib.sol";
import "../contracts/RoyaltySplitter.sol" as RSplitter;

contract DiamondDeployer is Script, DiamondUtils, IDiamondCut {

    // Constants
    uint256 constant _artistRoyaltyFee = 500; // 5%
    uint256 constant _platformRoyaltyFee = 200; // 2%
    address constant platformFeeAddress = address(0x51816a1b29569fbB1a56825C375C254742a9c5e1);

    function run() external {
        // Read private key inside the run function
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        console.log("Deployer:", deployer);

         // Deploy the core facet
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed at:", address(cutFacet));

        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        console.log("DiamondLoupeFacet deployed at:", address(dLoupe));

        OwnershipFacet ownerF = new OwnershipFacet();
        console.log("OwnershipFacet deployed at:", address(ownerF));

        // App Facets
        OwnershipControlFacet controlF = new OwnershipControlFacet();
        console.log("OwnershipControlFacet deployed at:", address(controlF));

        ArtistFacet artistF = new ArtistFacet();
        console.log("ArtistFacet deployed at:", address(artistF));

        SongFacet songF = new SongFacet();
        console.log("SongFacet deployed at:", address(songF));

        AlbumFacet albumF = new AlbumFacet();
        console.log("AlbumFacet deployed at:", address(albumF));

        MarketPlaceFacet marketF = new MarketPlaceFacet();
        console.log("MarketPlaceFacet deployed at:", address(marketF));

        ERC721Facet erc721F = new ERC721Facet();
        console.log("ERC721Facet deployed at:", address(erc721F));

        OwnershipControlFacet ownershipControlFacet = new OwnershipControlFacet();
        console.log("OwnershipControlFacet deployed at:", address(ownershipControlFacet));

        HelperFacet helperF = new HelperFacet();
        console.log("HelperFacet deployed at:", address(helperF));

        console.log("All facets deployed.");

        // Deploy the Royalty Splitter
        RSplitter.RoyaltySplitter royaltySplitter = new RSplitter.RoyaltySplitter();
        console.log("RoyaltySplitter deployed at:", address(royaltySplitter));
        
        // Deploy the Diamond
        Diamond diamond = new Diamond(
            address(deployer),
            address(cutFacet),
            platformFeeAddress,
            _artistRoyaltyFee,
            _platformRoyaltyFee,
            address(royaltySplitter)
        );
        console.log("Diamond deployed at:", address(diamond));

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
            facetAddress: address(artistF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ArtistFacet")
        });

        cut[3] = FacetCut({
            facetAddress: address(marketF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("MarketPlaceFacet")
        });

        cut[4] = FacetCut({
            facetAddress: address(songF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("SongFacet")
        });

        cut[5] = FacetCut({
            facetAddress: address(albumF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("AlbumFacet")
        });

        cut[6] = FacetCut({
            facetAddress: address(erc721F),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });

        cut[7] = FacetCut({
            facetAddress: address(ownershipControlFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipControlFacet")
        });

        cut[8] = FacetCut({
            facetAddress: address(helperF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("HelperFacet")
        });

        // Perform diamond cut to add all facets
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
        console.log("Diamond cut completed - all facets added");

        // Set the ownership of the Diamond to the deployer
        // ownerF.transferOwnership(address(deployer));

         // Configure platform settings
        OwnershipControlFacet(address(diamond)).setPlatformRoyalty(platformFeeAddress, 200);
        OwnershipControlFacet(address(diamond)).setArtistRoyaltyFraction(500);

        console.log("Diamond cut complete!");

        vm.stopBroadcast();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}