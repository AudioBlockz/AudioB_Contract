// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibAppStorage} from "./LibAppStorage.sol";
import {LibERC721Storage} from "./LibERC721Storage.sol";
import {ErrorLib} from "./ErrorLib.sol";

library MarketplacePaymentLib {
    /**
     * @notice Handles sending payments for marketplace sales (ETH or ERC20)
     * @param tokenAddress ERC20 token used for payment (zero address = native ETH)
     * @param payer Address paying the amount (buyer)
     * @param recipient Address receiving the amount (seller, royalty, or platform)
     * @param amount Amount to transfer
     */
    function _handlePayment(address tokenAddress, address payer, address recipient, uint256 amount) internal {
        if (amount == 0 || recipient == address(0)) return;

        if (tokenAddress == address(0)) {
            // Native token transfer
            (bool success,) = payable(recipient).call{value: amount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20 erc20 = IERC20(tokenAddress);

            if (payer == address(this)) {
                // Contract already holds the tokens, just transfer out
                bool success = erc20.transfer(recipient, amount);
                require(success, "ERC20 transfer failed");
            } else {
                // Payer still holds tokens (e.g. direct user-to-recipient transfer)
                bool success = erc20.transferFrom(payer, recipient, amount);
                require(success, "ERC20 transferFrom failed");
            }
        }
    }

    /**
     * @notice Helper for distributing royalty, platform fee, and seller payment.
     */
    function _distributeFunds(address tokenAddress, address payer, address seller, uint256 tokenId, uint256 salePrice)
        internal
        returns (uint256 toSeller, uint256 royaltyAmount, uint256 platformFee, address royaltyReceiver)
    {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        (royaltyReceiver, royaltyAmount) = LibERC721Storage.royaltyInfo(tokenId, salePrice);
        platformFee = (salePrice * LibAppStorage.MARKETPLACE_FEE_BPS) / 10000;
        toSeller = salePrice - royaltyAmount - platformFee;

        // First Distribute Royalty
        if (royaltyAmount > 0) {
            _handlePayment(tokenAddress, payer, royaltyReceiver, royaltyAmount);
        }

        //Second Distribute Platform fee
        if (platformFee > 0) {
            _handlePayment(tokenAddress, payer, aps.platFormAddress, platformFee);
        }

        //Pay Seller In this Case the Artist
        _handlePayment(tokenAddress, payer, seller, toSeller);
    }

    /**
     * @notice Handle refund Prev Bidder
     */
    function refundPrevBidder(uint256 tokenId, address payer, address prevBidder, uint256 prevBid) internal {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        LibAppStorage.Auction storage a = aps.auctions[tokenId];
        // require(a.highestBidder == prevBidder, "Not highest bidder");
        // require(a.highestBid == prevBid, "Invalid bid");
        require(a.seller != address(0), "Auction not found");
        require(block.timestamp <= a.endTime, "Auction not ended");
        require(!a.settled, "Already settled");

        _handlePayment(a.erc20TokenAddress, payer, prevBidder, prevBid);
    }

    function _settleAuctions(address tokenAddress, address payer, uint256 tokenId, uint256 price)
        internal
        returns (uint256 toSeller, uint256 royaltyAmount, uint256 platformFee, address royaltyReceiver)
    {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        // Calculate royalty and platform fees
        (toSeller, royaltyAmount, platformFee, royaltyReceiver) = calculateRoyaltyAndFees(price, tokenId);

        // Pay royalty receiver (if any)
        if (royaltyAmount > 0) {
            _handlePayment(tokenAddress, payer, royaltyReceiver, royaltyAmount);
        }

        // Pay platform fee
        if (platformFee > 0) {
            _handlePayment(tokenAddress, payer, aps.platFormAddress, platformFee);
        }

        // Pay seller
        address seller = aps.listings[tokenId].seller;
        _handlePayment(tokenAddress, payer, seller, toSeller);
    }

    function calculateRoyaltyAndFees(uint256 salePrice, uint256 tokenId)
        internal
        view
        returns (uint256 toSeller, uint256 royaltyAmount, uint256 platformFee, address royaltyReceiver)
    {
        (royaltyReceiver, royaltyAmount) = LibERC721Storage.royaltyInfo(tokenId, salePrice);
        platformFee = (salePrice * LibAppStorage.MARKETPLACE_FEE_BPS) / 10000;
        // amount that should go to the seller after deducting royalty and platform fee
        toSeller = salePrice - royaltyAmount - platformFee;
    }
}
