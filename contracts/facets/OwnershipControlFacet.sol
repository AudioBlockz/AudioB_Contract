// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract OwnershipControlFacet {
    modifier onlyOwner() {
        require(msg.sender == LibDiamond.contractOwner(), "Unauthorized caller");
        _;
    }

    // ================================== ADMIN ACTIONS =======================================

    function getContractBalance(address _token) external view onlyOwner returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    //  Admin functions to configure splits
    function setPlatformRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        aps.platFormAddress = receiver;
        aps.platformRoyaltyFee = feeNumerator;
        LibERC721Storage.setPlatformRoyalty(receiver, feeNumerator);
    }

    function setArtistRoyaltyFraction(uint96 feeNumerator) external onlyOwner {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        aps.artistRoyaltyFee = feeNumerator;
        LibERC721Storage.setArtistRoyaltyFraction(feeNumerator);
    }

    // View FUnctions
    function getPlatformRoyalty() external view returns (address receiver, uint96 fraction) {
        return LibERC721Storage.getPlatformRoyalty();
    }

    function getArtistRoyaltyFraction() external view returns (uint96 fraction) {
        return LibAppStorage.appStorage().artistRoyaltyFee;
    }
}
