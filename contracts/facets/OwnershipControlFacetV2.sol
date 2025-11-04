// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract OwnershipControlFacetV2 {
    modifier onlyOwner() {
        require(msg.sender == LibDiamond.contractOwner(), "Unauthorized caller");
        _;
    }

    // ================================== ADMIN ACTIONS =======================================
    
    function setERC721Details(string memory _name, string memory _symbol) external onlyOwner {
        _initializeERC721(_name, _symbol);
    }
    
    function _initializeERC721(string memory _name, string memory _symbol) internal {
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();
        require(bytes(es.name).length == 0, "Already initialized");
        require(!es.initialized, "Already initialized");
        es.name = _name;
        es.symbol = _symbol;
        es.initialized = true;
    }
}
