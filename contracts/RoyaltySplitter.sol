// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AudioBlocks Royalty Splitter (ETH + ERC20)
/// @notice Splits royalties between artist and platform automatically
contract RoyaltySplitter {
    address public artist;
    address public platform;
    uint96 public artistShare; // 500 = 5%
    uint96 public platformShare; // 200 = 2%
    bool private initialized;

    event PaymentReceived(address from, uint256 amount);
    event RoyaltiesDistributed(uint256 artistAmount, uint256 platformAmount, uint256 artistShare, uint256 platformShare);
    event ERC20RoyaltiesDistributed(address token, uint256 artistAmount, uint256 platformAmount, uint256 artistShare, uint256 platformShare);

    modifier onlyOnce() {
        require(!initialized, "Already initialized");
        _;
        initialized = true;
    }

    function initialize(
        address _artist,
        address _platform,
        uint96 _artistShare,
        uint96 _platformShare,
        uint96 max_total_share
    ) external onlyOnce {
        require(_artist != address(0), "Invalid artist");
        require(_platform != address(0), "Invalid platform");
        require(_artistShare + _platformShare == max_total_share, "Invalid split");
        artist = _artist;
        platform = _platform;
        artistShare = _artistShare;
        platformShare = _platformShare;
    }

    // receive ETH directly
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
        _distributeETH(msg.value);
    }

    /// @notice distribute ETH if stuck
    function distributeETH() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to distribute");
        _distributeETH(balance);
    }

    /// @notice distribute ERC20 tokens manually (e.g. USDC)
    function distributeERC20(address token) external {
        uint256 total = IERC20(token).balanceOf(address(this));
        require(total > 0, "No tokens to distribute");
        _distributeERC20(token, total);
    }

    function _distributeETH(uint256 totalAmount) internal {
        uint256 artistAmount = (totalAmount * artistShare) / 10000;
        // uint256 platformAmount = totalAmount - artistAmount;
        uint256 platformAmount = (totalAmount * platformShare) / 10000;
        uint256 distributed = artistAmount + platformAmount;

         // Handle rounding dust (leftover wei)
        uint256 remainder = totalAmount - distributed;
        if (remainder > 0) {
            artistAmount += remainder;
        }


        (bool s1,) = payable(artist).call{value: artistAmount}("");
        require(s1, "Artist transfer failed");

        (bool s2,) = payable(platform).call{value: platformAmount}("");
        require(s2, "Platform transfer failed");

        emit RoyaltiesDistributed(artistAmount, platformAmount, artistShare, platformShare);
    }

    function _distributeERC20(address token, uint256 totalAmount) internal {

        uint256 artistAmount = (totalAmount * artistShare) / 10000;
        // uint256 platformAmount = totalAmount - artistAmount;
        uint256 platformAmount = (totalAmount * platformShare) / 10000;

        uint256 distributed = artistAmount + platformAmount;

      

        IERC20(token).transfer(artist, artistAmount);
        IERC20(token).transfer(platform, platformAmount);

        emit ERC20RoyaltiesDistributed(token, artistAmount, platformAmount, artistShare, platformShare);
    }
}
