//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";

contract ArtistFacetV2 {
    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    event ArtistRegistered(uint256 indexed artistId, address indexed artistAddress);

    function setupArtistProfile() external returns (uint256, address) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        if (msg.sender == address(0)) revert ErrorLib.ZeroAddress();

        if (aps.artistAddressToArtist[msg.sender].isRegistered) {
            revert ErrorLib.ARTIST_ALREADY_REGISTERED();
        }

        uint256 artistId = ++aps.totalArtists;

    
        // LibAppStorage.Artist memory artist = LibAppStorage.Artist({
        //     artistId: artistId,
        //     artistTokenId: 0,
        //     artistCid: "",
        //     artistAddress: msg.sender,
        //     isRegistered: true,
        //     songTokenIds: new uint256[](0)
        // });
        LibAppStorage.Artist storage newArtist = aps.artistIdToArtist[artistId];
        newArtist.artistId = artistId;
        // newArtist.artistTokenId = artistTokenId;
        // newArtist.artistCid = "";
        newArtist.artistAddress = msg.sender;
        newArtist.isRegistered = true;
        // newArtist.songTokenIds = [];

        aps.artistAddressToArtist[msg.sender] = newArtist;
        aps.artistIdToArtist[artistId] = newArtist;
        aps.artistBalance[msg.sender] = 0;
        aps.allArtistIds.push(artistId);

        emit ArtistRegistered(artistId, msg.sender);

        return (artistId, msg.sender);
    }

}
