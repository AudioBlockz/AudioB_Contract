//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract HelperFacet {
    using LibAppStorage for LibAppStorage.AppStorage;

    function getMaxRoyaltyBonus() external pure returns (uint96) {
        return LibAppStorage.MAX_ROYALTY_BONUS;
    }
}
