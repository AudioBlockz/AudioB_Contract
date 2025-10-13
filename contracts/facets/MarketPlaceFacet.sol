// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibERC721Storage} from "../libraries/LibERC721Storage.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {ErrorLib} from "../libraries/ErrorLib.sol";
import {MarketplacePaymentLib} from "../libraries/MarketplacePaymentLib.sol";


contract MarketplaceFacet {
    using LibAppStorage for LibAppStorage.AppStorage;
    using LibERC721Storage for LibERC721Storage.ERC721Storage;

    // --- Events
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    event AuctionCreated(uint256 indexed tokenId, address indexed seller, uint256 reservePrice, uint256 endTime);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionCancelled(uint256 indexed tokenId, address indexed seller);
    event AuctionSettled(uint256 indexed tokenId, address indexed winner, address indexed seller, uint256 amount);


    // simple reentrancy guard (slot independent)
    bytes32 private constant REENTRANCY_SLOT = keccak256("audioblocks.marketplace.reentrancy");
    modifier nonReentrant() {
        uint256 status;
        bytes32 s = REENTRANCY_SLOT;
        assembly {
            status := sload(s)
        }
        require(status == 0, "Reentrant");
        assembly {
            sstore(s, 1)
        }
        _;
        assembly {
            sstore(s, 0)
        }
    }


    // ---------- Fixed-price listing API ----------

    /// @notice Seller lists an owned NFT for fixed price. Seller must be token owner.
    function createListing(uint256 tokenId, uint256 price, address _erc20Address) external {
        require(price > 0, "Invalid price");
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        address owner = es.owners[tokenId];

        if (owner != msg.sender) revert ErrorLib.NOT_TOKEN_OWNER();

        //Calculate minimum price to cover royalty + marketplace fee
        (, uint256 royaltyAmount, uint256 platformFee,) = MarketplacePaymentLib.calculateRoyaltyAndFees(price, tokenId);
        uint256 minPrice = royaltyAmount + platformFee;
        if(price < minPrice) revert ErrorLib.LISTING_PRICE_TOO_LOW();

        LibAppStorage.Listing storage listing = aps.listings[tokenId];
        require(!listing.active, "Already listed");
        listing.seller = msg.sender;
        listing.price = price;
        listing.active = true;
        listing.erc20Address = _erc20Address;


        emit Listed(tokenId, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Listing storage l = aps.listings[tokenId];
        require(l.active, "Not listed");
        require(l.seller == msg.sender, "Not seller");

        delete aps.listings[tokenId];
        emit ListingCancelled(tokenId, msg.sender);
    }

    /// @notice Buy the listed NFT by sending exact price.
    function buyNow(uint256 tokenId, address _erc20Address) external payable nonReentrant {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Listing storage l = aps.listings[tokenId];
        require(l.active, "Not listed");

        l.active = false;
        address seller = l.seller;
        uint256 price = l.price;

        if (_erc20Address == address(0)) {
            require(msg.value == price, "Incorrect ETH amount");
        } else {
            require(_erc20Address == l.erc20Address, "Wrong ERC20");
            IERC20(_erc20Address).transferFrom(msg.sender, address(this), price); // Money is in contract at this point
        }

        delete aps.listings[tokenId]; // Effects first

        //  Distribute funds (royalties, fees, seller)
        MarketplacePaymentLib._distributeFunds(_erc20Address, address(this), seller, tokenId, price);

        //  Transfer NFT ownership
        ERC721Facet(address(this)).transferFrom(seller, msg.sender, tokenId);

        emit Bought(tokenId, msg.sender, seller, price);
    }


    // ---------- Auction API (English auction) ----------

    /// @notice Create an auction for tokenId: seller must be owner.
    function createAuction(uint256 tokenId, uint256 reservePrice, uint256 durationSeconds, address _erc20Address) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibERC721Storage.ERC721Storage storage es = LibERC721Storage.erc721Storage();

        require(durationSeconds >= LibAppStorage.MIN_AUCTION_DURATION, "Duration too short");
        address owner = es.owners[tokenId];
        require(owner == msg.sender, "Not token owner");

        uint256 endTime = block.timestamp + durationSeconds;
        LibAppStorage.Auction storage auction = aps.auctions[tokenId];
        require(!auction.settled, "Already settled");

        auction.seller = msg.sender;
        auction.reservePrice = reservePrice;
        auction.endTime = endTime;
        auction.erc20TokenAddress = _erc20Address;

        emit AuctionCreated(tokenId, msg.sender, reservePrice, endTime);
    }

    /// @notice Place a bid. Sender must fund bid by sending ETH.
    function placeBid(uint256 tokenId, uint256 incoming) external payable nonReentrant {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();

        LibAppStorage.Auction storage a = aps.auctions[tokenId];

        address tokenAddr = a.erc20TokenAddress;

        if(a.seller == address(0)) revert ErrorLib.AUNCTION_NOT_FOUND();
        if(block.timestamp >= a.endTime) revert ErrorLib.AUNCTION_ENED();
        if(a.settled== true) revert ErrorLib.AUNCTION_ENED();

        if (tokenAddr == address(0)) {
            require(msg.value > 0, "No bid");
            incoming = msg.value;
        } else {
            IERC20(tokenAddr).transferFrom(msg.sender, address(this), incoming);
        }

        require(incoming > 0, "No bid");

        uint256 minRequired;
        if (a.highestBid == 0) {
            // first bid must meet reservePrice
            minRequired = a.reservePrice;
        } else {
            // next bid must be >= highest + minIncrement
            uint256 increment = (a.highestBid * LibAppStorage.MIN_BID_INCREMENT_BPS) / 10000;
            minRequired = a.highestBid + (increment == 0 ? 1 : increment);
        }
        if(incoming < minRequired) revert ErrorLib.BID_TOO_LOW();


        // store previous highest to refund later
        address prevBidder = a.highestBidder;
        uint256 prevBid = a.highestBid;

        // effect: update highest
        a.highestBid = incoming;
        a.highestBidder = msg.sender;

        // interaction: refund previous highest bidder (if any)
        MarketplacePaymentLib.refundPrevBidder(tokenId, address(this), prevBidder, prevBid);


        emit BidPlaced(tokenId, msg.sender, incoming);
    }

    /// @notice Cancel an auction (only seller, only if no bids)
    function cancelAuction(uint256 tokenId) external {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        
        LibAppStorage.Auction storage a = aps.auctions[tokenId];

        require(a.seller != address(0), "Auction not found");
        require(a.seller == msg.sender, "Not seller");
        require(a.highestBid == 0, "Already has bids");

        delete aps.auctions[tokenId];
        emit AuctionCancelled(tokenId, msg.sender);
    }

    /// @notice Settle auction after it ends. Transfers NFT to winner and distributes funds.
    function settleAuction(uint256 tokenId) external nonReentrant {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        LibAppStorage.Auction storage auc = aps.auctions[tokenId];

        require(auc.settled, "Auction not active");
        require(block.timestamp >= auc.endTime, "Auction not ended");

        auc.settled = false;

        address winner = auc.highestBidder;
        uint256 amount = auc.highestBid;
        address paymentToken = auc.erc20TokenAddress;

        // --- Distribute funds
        MarketplacePaymentLib._settleAuctions(paymentToken, address(this), tokenId, amount);

        // --- Transfer NFT
        ERC721Facet(address(this)).transferFrom(auc.seller, winner, tokenId);

        emit AuctionSettled(tokenId, winner, auc.seller, amount);
    }


    // ---------- Helper view getters ----------

    function getListing(uint256 tokenId) external view returns (LibAppStorage.Listing memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        
        LibAppStorage.Listing storage a = aps.listings[tokenId];
        return a;
    }

    function getAuction(uint256 tokenId) external view returns (LibAppStorage.Auction memory) {
        LibAppStorage.AppStorage storage aps = LibAppStorage.appStorage();
        
        LibAppStorage.Auction storage a = aps.auctions[tokenId];
        return a;
    }



    // ---- Internal Helper functions ----
    //@note make sure the price for aunction is more when royalty fee is removed from sale price
    
}
