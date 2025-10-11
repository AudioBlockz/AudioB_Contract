//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {LibRoyaltySplitterFactory} from "../libraries/LibRoyaltySplitterFactory.sol";



contract ArtistFacet {

    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);


    function setupArtistProfile(
        address _address,
        string memory _cid
    ) internal returns (uint256, address, string memory, uint256) {
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
        LibERC721Storage.mint(msg.sender, tokenId, tokenURI);
        LibERC721Storage.setTokenArtist(tokenId, _address);

        emit Transfer(address(0), msg.sender, tokenId);

        // Setup Royalty Splitter contract for this artist + token
        address splitter = LibRoyaltySplitterFactory.createRoyaltySplitter(
            _address,
            aps.platFormAddress,
            aps.artistRoyaltyFee,
            aps.platformRoyaltyFee,
            LibERC721Storage.MAX_ROYALTY_BONUS
        );
        LibERC721Storage.setTokenRoyaltyReceiver(tokenId, splitter);

        aps.artistAddressToArtist[_address] = LibAppStorage.Artist({
            artistId: artistId,
            artistAddress: _address,
            artistCid: _cid,
            artistTokenId: tokenId,
            isRegistered: true,
            songTokenIds: new uint256[](0)
        });
        aps.isArtistToken[tokenId] = true;

        emit LibAppStorage.ArtistRegistered(artistId, _address, _cid, tokenId);

        return (artistId, _address, _cid, tokenId);
    }

    function updateArtistProfile(
        address _address,
        string memory _cid
    ) internal returns (uint256, address, string memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        if (_address == address(0)) revert ErrorLib.ZeroAddress();
        if (bytes(_cid).length == 0) revert ErrorLib.InvalidCid();

        LibAppStorage.Artist storage artist = aps.artistAddressToArtist[_address];
        if (artist.artistAddress == address(0)) revert ErrorLib.ARTIST_NOT_FOUND();

        // Update artist info in mappings
        artist.artistCid = _cid;
        aps.artistIdToArtist[artist.artistId].artistCid = _cid;

        // Update the metadata URI
        string memory tokenURI = string(abi.encodePacked("ipfs://", _cid));

        // Use library directly instead of facet call
        LibERC721Storage.setTokenURI(artist.artistTokenId, tokenURI);

        emit LibAppStorage.ArtistUpdated(artist.artistId, _address, artist.artistTokenId, _cid);

        return (artist.artistId, _address, _cid);
    }


    function getArtistInfo(address artist) external view returns (LibAppStorage.Artist memory) {
        return LibAppStorage.appStorage().artistAddressToArtist[artist];
    }
}
