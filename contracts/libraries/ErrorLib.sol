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
    
}