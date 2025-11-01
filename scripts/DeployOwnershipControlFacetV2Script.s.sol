// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/OwnershipControlFacetV2.sol";

contract DeployOwnershipControlFacetV2Script is Script {
    address constant DIAMOND_ADDRESS = 0x353ac4905ba942277575d71eF5dA7c0819FBba79;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(privateKey);

        OwnershipControlFacetV2 newFacet = new OwnershipControlFacetV2();

        bytes4[] memory selectorsAdd = new bytes4[](1);
        selectorsAdd[0] = bytes4(keccak256("setERC721Details(string,string)"));

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectorsAdd
        });

        IDiamondCut(DIAMOND_ADDRESS).diamondCut(cut, address(0), "");

        vm.stopBroadcast();

        console.log(" OwnershipControlFacetV2 upgraded successfully. New facet:", address(newFacet));
    }
}
