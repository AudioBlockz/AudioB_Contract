    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ErrorLib {
    error ZeroAddress();
    error UnAuthorized();
    error NotOwner();
    error InvalidCid();
    error ARTISTNOTFOUND();
    error INVALIDTITLE();
    error INVALIDALBUM();
    error INVALIDSONGID();
    error ALBUMALREADYPUBLISHED();
    error USERNOTFOUND();
    error USERALREADYADDED();
    error ARTIST_ALREADY_REGISTERED();
    error ARTIST_NOT_REGISTERED();
    error ARTIST_NOT_FOUND();
    error SONG_NOT_FOUND();
    error NOT_SONG_OWNER();
    error InvalidArrayLength();
    error ALBUM_NOT_FOUND();
    error NOT_ALBUM_OWNER();
    error NOT_TOKEN_OWNER();
    error LISTING_PRICE_TOO_LOW();
    error AUNCTION_NOT_FOUND();
    error AUNCTION_ENED();
    error NO_BID();
    error BID_TOO_LOW();
    error INVALID_PRICE();
}
