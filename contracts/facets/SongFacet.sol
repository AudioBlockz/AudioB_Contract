//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";


contract SongFacet {

    using LibAppStorage for LibAppStorage.AppStorage;

    function addNewSong(
        address _artistAddress,
        string memory _songCID
    ) external returns (uint256, address, string memory, uint256) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        if (_artistAddress == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_songCID).length == 0) revert ErrorLib.InvalidCid();
        if (
            aps.artistAddressToArtist[_artistAddress].artistAddress ==
            address(0)
        ) revert ErrorLib.ARTIST_NOT_REGISTERED();

        uint256 songId = ++aps.totalSong;

        LibAppStorage.Song memory newSong = LibAppStorage.Song({
            songId: songId,
            artistAddress: _artistAddress,
            songCID: _songCID,
            totalStreams: 0,
            totalLikes: 0,
            createdAt: block.timestamp
        });
        aps.artistToSongIds[_artistAddress].push(songId);
        aps.songIdToSong[songId] = newSong;
        aps.allSongIds.push(songId);

        return (songId, _artistAddress, _songCID, block.timestamp);
    }

}