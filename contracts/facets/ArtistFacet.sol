//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";

contract ArtistFacet {

    using LibAppStorage for LibAppStorage.AppStorage;

    function setupArtistProfile(
        address _address,
        string memory _cid
    ) internal returns (uint256, address, string memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();


        if (_address == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_cid).length == 0) revert ErrorLib.InvalidCid();

        if (aps.artistAddressToArtist[_address].artistAddress != address(0))
            revert ErrorLib.ARTIST_ALREADY_REGISTERED();

        uint256 artistId = ++aps.totalArtist;
        aps.artistAddressToArtist[_address] = LibAppStorage.Artist({
            artistId: artistId,
            artistAddress: _address,
            artistCid: _cid
        });

        aps.artistIdToArtist[artistId] = aps.artistAddressToArtist[_address];
        aps.artistBalance[_address] = 0;

        aps.allArtistIds.push(artistId);

        return (artistId, _address, _cid);
    }

    function updateArtistProfile(
        address _address,
        string memory _cid
    ) internal returns (uint256, address, string memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();


        if (_address == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_cid).length == 0) revert ErrorLib.InvalidCid();

        LibAppStorage.Artist storage artist = aps.artistAddressToArtist[
            _address
        ];

        LibAppStorage.Artist storage artistById = aps.artistIdToArtist[
            artist.artistId
        ];

        artist.artistCid = _cid;
        artistById.artistCid = _cid;

        return (artist.artistId, _address, _cid);
    }
}