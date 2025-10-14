// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RoyaltySplitter.sol";

library LibRoyaltySplitterFactory {
    using Clones for address;

    bytes32 constant STORAGE_POSITION = keccak256("audioblocks.diamond.royaltysplitter.factory.storage");

    struct FactoryStorage {
        address splitterImplementation;
    }

    function factoryStorage() internal pure returns (FactoryStorage storage fs) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            fs.slot := position
        }
    }

    function setImplementation(address impl) internal {
        require(impl != address(0), "Invalid implementation");
        factoryStorage().splitterImplementation = impl;
    }

    function createRoyaltySplitter(
        address artist,
        address platform,
        uint96 artistShare,
        uint96 platformShare,
        uint96 max_total_share
    ) internal returns (address clone) {
        FactoryStorage storage fs = factoryStorage();
        require(fs.splitterImplementation != address(0), "Splitter impl not set");

        // Deploy clone using OZ’s Clones lib
        clone = Clones.clone(fs.splitterImplementation);

        // Initialize the cloned splitter
        RoyaltySplitter(payable(clone)).initialize(artist, platform, artistShare, platformShare, max_total_share);
    }
}
