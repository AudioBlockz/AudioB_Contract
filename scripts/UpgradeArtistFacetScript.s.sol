// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/ArtistFacetV2.sol";

contract UpgradeArtistFacetScript is Script {
    address constant DIAMOND_ADDRESS = 0x353ac4905ba942277575d71eF5dA7c0819FBba79;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(privateKey);

        ArtistFacetV2 newFacet = new ArtistFacetV2();

        bytes4[] memory selectorsRemove = new bytes4[](1);
        selectorsRemove[0] = bytes4(keccak256("setupArtistProfile(string)"));

        bytes4[] memory selectorsAdd = new bytes4[](1);
        selectorsAdd[0] = bytes4(keccak256("setupArtistProfile()"));

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectorsRemove
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectorsAdd
        });

        IDiamondCut(DIAMOND_ADDRESS).diamondCut(cut, address(0), "");

        vm.stopBroadcast();

        console.log(" ArtistFacet upgraded successfully. New facet:", address(newFacet));
    }
}
