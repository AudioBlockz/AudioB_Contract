//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {LibDiamond} from "./libraries/LibDiamond.sol";
import {LibAppStorage} from "./libraries/LibAppStorage.sol";
import {LibERC721Storage} from "./libraries/LibERC721Storage.sol";
contract DiamondInit {
    using LibERC721Storage for LibERC721Storage.ERC721Storage;
    using LibAppStorage for LibAppStorage.AppStorage;

    /// @notice Initialize function for the diamond
    /// @dev This function is called only once when the diamond is deployed. It can be
    /// used to initialize state variables of the diamond.
    /// @param _name The name of the ERC721 token.
    /// @param _symbol The symbol of the ERC721 token.
    /// @param _owner The owner of the diamond contract.
    function init(
        string memory _name,
        string memory _symbol,
        address _owner
    ) external {
        // Initialize ERC721 storage
        LibERC721Storage.ERC721Storage storage erc721 = LibERC721Storage.erc721Storage();
        erc721.name = _name;
        erc721.symbol = _symbol;
        erc721.currentTokenId = 0;

        // Initialize app storage
        LibAppStorage.AppStorage storage app = LibAppStorage.appStorage();
        app.totalArtists = 0;
        app.totalSongs = 0;

        // Set diamond owner
        LibDiamond.setContractOwner(_owner);
    }
}