//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {ERC721Facet} from "./ERC721Facet.sol";



contract ArtistFacet {

    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;


    function setupArtistProfile(
        address _address,
        string memory _cid
    ) internal returns (uint256, address, string memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibERC721Storage.ERC721Storage storage erc721 = LibERC721Storage.erc721Storage();


        if (_address == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_cid).length == 0) revert ErrorLib.InvalidCid();

        if (aps.artistAddressToArtist[_address].artistAddress != address(0))
            revert ErrorLib.ARTIST_ALREADY_REGISTERED();

        uint256 artistId = ++aps.totalArtists;
        

        aps.artistIdToArtist[artistId] = aps.artistAddressToArtist[_address];
        aps.artistBalance[_address] = 0;

        aps.allArtistIds.push(artistId);

        // Generate new token ID and mint
        uint256 tokenId = ++erc721.currentTokenId;
        string memory tokenURI = string(abi.encodePacked("ipfs://", _cid));
        
        // Use library function instead of cross-facet call
        LibERC721Storage.mint(msg.sender, tokenId, tokenURI);
        // emit Transfer(address(0), msg.sender, tokenId);

        aps.artistAddressToArtist[_address] = LibAppStorage.Artist({
            artistId: artistId,
            artistAddress: _address,
            artistCid: _cid,
            artistTokenId: tokenId,
            isRegistered: true,
            songTokenIds: new uint256[](0)
        });
        aps.isArtistToken[tokenId] = true;


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
        aps.artistAddressToArtist[_address] = artist;
        aps.artistIdToArtist[artist.artistId] = artistById;

         // Update metadata URI - point to IPFS metadata file
        string memory tokenURI = string(abi.encodePacked("ipfs://", _cid));
        ERC721Facet(address(this)).setTokenURI(artist.artistTokenId, tokenURI);

        return (artist.artistId, _address, _cid);
    }

     function getArtistInfo(address artist) external view returns (LibAppStorage.Artist memory) {
        return LibAppStorage.appStorage().artistAddressToArtist[artist];
    }
}