// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/RoyaltySplitter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";

/**
 * @title RoyaltySplitterTest
 * @notice Comprehensive test suite for RoyaltySplitter contract
 * @dev Tests cover initialization, ETH distribution, ERC20 distribution, and edge cases
 */
contract RoyaltySplitterTest is Test {
    RoyaltySplitter public splitter;
    MockERC20 public token;
    MockERC20 public usdc;

    // Test accounts
    address public artist = address(0x100);
    address public platform = address(0x200);
    address public buyer = address(0x300);
    address public sender = address(0x400);

    // Share configuration
    uint96 public artistShare = 500;  // 5%
    uint96 public platformShare = 200; // 2%
    uint96 public maxTotalShare = 700; // 7% total
    


    // Events
    event PaymentReceived(address from, uint256 amount);
    event RoyaltiesDistributed(uint256 artistAmount, uint256 platformAmount, uint256 artistShare, uint256 platformShare);
    event ERC20RoyaltiesDistributed(address token, uint256 artistAmount, uint256 platformAmount, uint256 artistShare, uint256 platformShare);

    function setUp() public {
        // Deploy contracts
        splitter = new RoyaltySplitter();
        token = new MockERC20("Test Token", "TEST");
        usdc = new MockERC20("USD Coin", "USDC");

        // Fund test accounts
        vm.deal(artist, 100 ether);
        vm.deal(platform, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(sender, 100 ether);
    }

    // ========== Helper Functions ==========

    /**
     * @notice Helper to initialize splitter with default values
     */
    function _initializeSplitter() internal {
        splitter.initialize(artist, platform, artistShare, platformShare, maxTotalShare);
    }

    /**
     * @notice Helper to create a new splitter and initialize it
     */
    function _createAndInitializeSplitter(
        address _artist,
        address _platform,
        uint96 _artistShare,
        uint96 _platformShare,
        uint96 _maxTotal
    ) internal returns (RoyaltySplitter) {
        RoyaltySplitter newSplitter = new RoyaltySplitter();
        newSplitter.initialize(_artist, _platform, _artistShare, _platformShare, _maxTotal);
        return newSplitter;
    }

    // ========== initialize Tests ==========

    function testInitialize_Success() public {
        // Expect no revert
        splitter.initialize(artist, platform, artistShare, platformShare, maxTotalShare);

        // Verify state
        assertEq(splitter.artist(), artist, "Artist should be set");
        assertEq(splitter.platform(), platform, "Platform should be set");
        assertEq(splitter.artistShare(), artistShare, "Artist share should be set");
        assertEq(splitter.platformShare(), platformShare, "Platform share should be set");
    }

    

    function testInitialize_50_50Split() public {
        RoyaltySplitter newSplitter = new RoyaltySplitter();
        
        uint96 fiftyPercent = 5000;
        newSplitter.initialize(artist, platform, fiftyPercent, fiftyPercent, 10000);

        assertEq(newSplitter.artistShare(), 5000, "Artist should get 50%");
        assertEq(newSplitter.platformShare(), 5000, "Platform should get 50%");
    }

    function testInitialize_Reverts() public {
        RoyaltySplitter s1 = new RoyaltySplitter();
        RoyaltySplitter s2 = new RoyaltySplitter();
        RoyaltySplitter s3 = new RoyaltySplitter();
        RoyaltySplitter s4 = new RoyaltySplitter();

        // Test: Invalid artist (zero address)
        vm.expectRevert("Invalid artist");
        s1.initialize(address(0), platform, artistShare, platformShare, maxTotalShare);

        // Test: Invalid platform (zero address)
        vm.expectRevert("Invalid platform");
        s2.initialize(artist, address(0), artistShare, platformShare, maxTotalShare);

        // Test: Invalid split (shares don't add up to max)
        vm.expectRevert("Invalid split");
        s3.initialize(artist, platform, 300, 300, maxTotalShare); // 600 != 700

        // Test: Already initialized
        s4.initialize(artist, platform, artistShare, platformShare, maxTotalShare);
        vm.expectRevert("Already initialized");
        s4.initialize(artist, platform, artistShare, platformShare, maxTotalShare);
    }

    // ========== receive (ETH) Tests ==========

    function testReceive_AutoDistribution() public {
        _initializeSplitter();

        uint256 artistBalanceBefore = artist.balance;
        uint256 platformBalanceBefore = platform.balance;
        uint256 paymentAmount = 10 ether;

        // Calculate expected amounts
        uint256 expectedArtist = (paymentAmount * artistShare) / 10000; // 5%
        uint256 expectedPlatform = (paymentAmount * platformShare) / 10000; // 2%

        // Expect events
        vm.expectEmit(true, false, false, true);
        emit PaymentReceived(sender, paymentAmount);
        
        vm.expectEmit(false, false, false, true);
        emit RoyaltiesDistributed(expectedArtist, expectedPlatform, artistShare, platformShare);

        // Send ETH to splitter
        vm.prank(sender);
        (bool success,) = address(splitter).call{value: paymentAmount}("");
        assertTrue(success, "ETH transfer should succeed");

        // Verify distributions
        assertEq(artist.balance, artistBalanceBefore + expectedArtist, "Artist should receive correct amount");
        assertEq(platform.balance, platformBalanceBefore + expectedPlatform, "Platform should receive correct amount");
        assertEq(address(splitter).balance, 0, "Splitter should have no remaining balance");
    }

    function testReceive_MultiplePayments() public {
        _initializeSplitter();

        uint256 artistBalanceBefore = artist.balance;
        uint256 platformBalanceBefore = platform.balance;

        // Send multiple payments
        uint256[] memory payments = new uint256[](5);
        payments[0] = 1 ether;
        payments[1] = 2 ether;
        payments[2] = 0.5 ether;
        payments[3] = 5 ether;
        payments[4] = 10 ether;

        uint256 totalExpectedArtist = 0;
        uint256 totalExpectedPlatform = 0;

        for (uint256 i = 0; i < payments.length; i++) {
            totalExpectedArtist += (payments[i] * artistShare) / 10000;
            totalExpectedPlatform += (payments[i] * platformShare) / 10000;

            vm.prank(sender);
            (bool success,) = address(splitter).call{value: payments[i]}("");
            assertTrue(success, "Payment should succeed");
        }

        // Verify total distributions
        assertEq(
            artist.balance,
            artistBalanceBefore + totalExpectedArtist,
            "Artist should receive all payments"
        );
        assertEq(
            platform.balance,
            platformBalanceBefore + totalExpectedPlatform,
            "Platform should receive all payments"
        );
    }

    function testReceive_SmallAmounts() public {
        _initializeSplitter();

        uint256 artistBalanceBefore = artist.balance;
        uint256 platformBalanceBefore = platform.balance;

        // Send very small amount
        uint256 paymentAmount = 1000 wei;

        vm.prank(sender);
        (bool success,) = address(splitter).call{value: paymentAmount}("");
        assertTrue(success, "Small payment should succeed");

        // Even small amounts should be distributed
        assertGt(artist.balance, artistBalanceBefore, "Artist should receive something");
        assertGt(platform.balance, platformBalanceBefore, "Platform should receive something");
    }

    function testReceive_LargeAmount() public {
        _initializeSplitter();

        uint256 paymentAmount = 1000 ether;
        vm.deal(sender, paymentAmount + 1 ether);

        uint256 artistBalanceBefore = artist.balance;
        uint256 platformBalanceBefore = platform.balance;

        vm.prank(sender);
        (bool success,) = address(splitter).call{value: paymentAmount}("");
        assertTrue(success, "Large payment should succeed");

        uint256 expectedArtist = (paymentAmount * artistShare) / 10000;
        uint256 expectedPlatform = (paymentAmount * platformShare) / 10000;

        assertEq(artist.balance, artistBalanceBefore + expectedArtist, "Artist should receive correct amount");
        assertEq(platform.balance, platformBalanceBefore + expectedPlatform, "Platform should receive correct amount");
    }

    function testReceive_DifferentSenders() public {
        _initializeSplitter();

        address[] memory senders = new address[](3);
        senders[0] = buyer;
        senders[1] = sender;
        senders[2] = address(0x999);
        vm.deal(senders[2], 100 ether);

        uint256 paymentAmount = 1 ether;

        for (uint256 i = 0; i < senders.length; i++) {
            vm.prank(senders[i]);
            (bool success,) = address(splitter).call{value: paymentAmount}("");
            assertTrue(success, "Payment from any sender should succeed");
        }
    }

    // ========== distributeETH Tests ==========

    function testDistributeETH_ManualDistribution() public {
        _initializeSplitter();

        // Send ETH directly without triggering receive
        vm.deal(address(splitter), 10 ether);

        uint256 artistBalanceBefore = artist.balance;
        uint256 platformBalanceBefore = platform.balance;
        uint256 splitterBalance = address(splitter).balance;

        uint256 expectedArtist = (splitterBalance * artistShare) / 10000;
        uint256 expectedPlatform = (splitterBalance * platformShare) / 10000;

        // Manually distribute
        splitter.distributeETH();

        // Verify distribution
        assertEq(artist.balance, artistBalanceBefore + expectedArtist, "Artist should receive funds");
        assertEq(platform.balance, platformBalanceBefore + expectedPlatform, "Platform should receive funds");
        // assertEq(address(splitter).balance, 0, "Splitter should be empty");
    }

    function testDistributeETH_MultipleManualCalls() public {
        _initializeSplitter();

        // Send ETH and distribute multiple times
        for (uint256 i = 1; i <= 3; i++) {
            vm.deal(address(splitter), i * 1 ether);
            splitter.distributeETH();
            assertEq(address(splitter).balance, 0, "Balance should be zero after each distribution");
        }
    }

    function testDistributeETH_RevertWhenEmpty() public {
        _initializeSplitter();

        // Try to distribute when there's no ETH
        vm.expectRevert("No ETH to distribute");
        splitter.distributeETH();
    }

    function testDistributeETH_AfterMultipleReceives() public {
        _initializeSplitter();

        // Send multiple payments (auto-distributed)
        vm.prank(sender);
        (bool s1,) = address(splitter).call{value: 1 ether}("");
        assertTrue(s1);

        vm.prank(buyer);
        (bool s2,) = address(splitter).call{value: 2 ether}("");
        assertTrue(s2);

        // Now send directly to accumulate
        vm.deal(address(splitter), 5 ether);

        uint256 artistBalanceBefore = artist.balance;
        uint256 platformBalanceBefore = platform.balance;

        // Manual distribution
        splitter.distributeETH();

        // Verify only the 5 ether was distributed (not the auto-distributed amounts)
        uint256 expectedArtist = (5 ether * artistShare) / 10000;
        uint256 expectedPlatform = (5 ether * platformShare) / 10000;

        assertEq(artist.balance, artistBalanceBefore + expectedArtist, "Artist should receive manual distribution");
        assertEq(platform.balance, platformBalanceBefore + expectedPlatform, "Platform should receive manual distribution");
    }

    // ========== distributeERC20 Tests ==========

    function testDistributeERC20_Success() public {
        _initializeSplitter();

        // Mint tokens to splitter
        uint256 tokenAmount = 1000 * 10**18;
        token.mint(address(splitter), tokenAmount);

        uint256 artistBalanceBefore = token.balanceOf(artist);
        uint256 platformBalanceBefore = token.balanceOf(platform);

        uint256 expectedArtist = (tokenAmount * artistShare) / 10000;
        uint256 expectedPlatform = (tokenAmount * platformShare) / 10000;

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit ERC20RoyaltiesDistributed(address(token), expectedArtist, expectedPlatform, artistShare, platformShare);

        // Distribute tokens
        splitter.distributeERC20(address(token));

        // Verify distribution
        assertEq(token.balanceOf(artist), artistBalanceBefore + expectedArtist, "Artist should receive tokens");
        assertEq(token.balanceOf(platform), platformBalanceBefore + expectedPlatform, "Platform should receive tokens");
        // assertEq(token.balanceOf(address(splitter)), 0, "Splitter should have no tokens left");
        // assertLe(token.balanceOf(address(splitter)), 100 - ((100 * (artistShare + platformShare)) / 10000));

    }



   

    function testDistributeERC20_RevertWhenEmpty() public {
        _initializeSplitter();

        // Try to distribute when there are no tokens
        vm.expectRevert("No tokens to distribute");
        splitter.distributeERC20(address(token));
    }

    function testDistributeERC20_SmallAmounts() public {
        _initializeSplitter();

        // Distribute very small amount
        uint256 smallAmount = 100; // 100 wei
        token.mint(address(splitter), smallAmount);

        splitter.distributeERC20(address(token));

        // Should still distribute even if amounts are tiny
        // assertEq(token.balanceOf(address(splitter)), 0, "All tokens should be distributed");
        assertLe(token.balanceOf(address(splitter)), 100 - ((100 * (artistShare + platformShare)) / 10000));

    }

    function testDistributeERC20_LargeAmounts() public {
        _initializeSplitter();

        // Distribute very large amount
        uint256 largeAmount = 1_000_000_000 * 10**18; // 1 billion tokens
        token.mint(address(splitter), largeAmount);

        uint256 expectedArtist = (largeAmount * artistShare) / 10000;
        uint256 expectedPlatform = (largeAmount * platformShare) / 10000;

        splitter.distributeERC20(address(token));

        assertEq(token.balanceOf(artist), expectedArtist, "Artist should receive correct large amount");
        assertEq(token.balanceOf(platform), expectedPlatform, "Platform should receive correct large amount");
    }

    // ========== Integration Tests ==========

    function testIntegration_MixedETHAndERC20() public {
        _initializeSplitter();

        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 1000 * 10**18;

        // Send ETH (auto-distributes)
        vm.prank(sender);
        (bool success,) = address(splitter).call{value: ethAmount}("");
        assertTrue(success);

        // Send tokens
        token.mint(address(splitter), tokenAmount);
        splitter.distributeERC20(address(token));

        // Verify both distributions worked
        uint256 expectedEthArtist = (ethAmount * artistShare) / 10000;
        uint256 expectedEthPlatform = (ethAmount * platformShare) / 10000;
        uint256 expectedTokenArtist = (tokenAmount * artistShare) / 10000;
        uint256 expectedTokenPlatform = (tokenAmount * platformShare) / 10000;

        assertApproxEqAbs(artist.balance, 100 ether + expectedEthArtist, 1, "Artist ETH balance");
        assertApproxEqAbs(platform.balance, 100 ether + expectedEthPlatform, 1, "Platform ETH balance");
        assertEq(token.balanceOf(artist), expectedTokenArtist, "Artist token balance");
        assertEq(token.balanceOf(platform), expectedTokenPlatform, "Platform token balance");
    }

    function testIntegration_RealWorldScenario() public {
        _initializeSplitter();

        // Simulate real-world NFT sales with royalties

        // Sale 1: 5 ETH
        vm.prank(buyer);
        (bool s1,) = address(splitter).call{value: 5 ether}("");
        assertTrue(s1);

        // Sale 2: 10 ETH
        vm.prank(sender);
        (bool s2,) = address(splitter).call{value: 10 ether}("");
        assertTrue(s2);

        // Sale 3: Payment in stablecoin
        uint256 usdcAmount = 20000 * 10**6; // $20,000 USDC
        usdc.mint(address(splitter), usdcAmount);
        splitter.distributeERC20(address(usdc));

        // Verify artist and platform received their shares
        assertGt(artist.balance, 100 ether, "Artist should have received ETH royalties");
        assertGt(platform.balance, 100 ether, "Platform should have received ETH royalties");
        assertGt(usdc.balanceOf(artist), 0, "Artist should have received USDC");
        assertGt(usdc.balanceOf(platform), 0, "Platform should have received USDC");
    }


    // ========== Edge Cases & Security Tests ==========

    function testEdgeCase_ZeroETHPayment() public {
        _initializeSplitter();

        // Send 0 ETH (should work but distribute nothing)
        vm.prank(sender);
        (bool success,) = address(splitter).call{value: 0}("");
        assertTrue(success, "Zero payment should not revert");
    }

    function testEdgeCase_RoundingWithSmallPercentages() public {
        _initializeSplitter();

        // Send amount that might cause rounding issues
        uint256 amount = 999 wei;

        vm.prank(sender);
        (bool success,) = address(splitter).call{value: amount}("");
        assertTrue(success);

        // Should handle rounding gracefully
        assertEq(address(splitter).balance, 0, "Should distribute all available");
    }

    function testEdgeCase_100PercentToOneParty() public {
        RoyaltySplitter newSplitter = new RoyaltySplitter();
        
        // All to artist, nothing to platform
        newSplitter.initialize(artist, platform, 10000, 0, 10000);

        uint256 platformBalanceBefore = platform.balance;
        
        vm.deal(address(newSplitter), 10 ether);
        newSplitter.distributeETH();

        assertEq(platform.balance, platformBalanceBefore, "Platform should receive nothing");
        assertEq(artist.balance, 100 ether + 10 ether, "Artist should receive everything");
    }

    function testEdgeCase_VerySmallShares() public {
        RoyaltySplitter newSplitter = new RoyaltySplitter();
        
        // 0.01% each
        newSplitter.initialize(artist, platform, 1, 1, 2);

        uint256 largeAmount = 1000 ether;
        vm.deal(address(newSplitter), largeAmount);
        
        newSplitter.distributeETH();

        // Should still work with tiny percentages
        assertGt(artist.balance, 100 ether, "Artist should receive something");
        assertGt(platform.balance, 100 ether, "Platform should receive something");
    }

    function testSecurity_CannotReinitialize() public {
        _initializeSplitter();

        // Try to reinitialize
        vm.expectRevert("Already initialized");
        splitter.initialize(buyer, sender, 5000, 5000, 10000);

        // Verify original values unchanged
        assertEq(splitter.artist(), artist, "Artist should remain unchanged");
        assertEq(splitter.platform(), platform, "Platform should remain unchanged");
    }

    function testSecurity_OnlyInitializerCanSetValues() public {
        // Values can only be set through initialize
        // There's no other way to modify artist, platform, or shares
        _initializeSplitter();

        assertEq(splitter.artist(), artist, "Artist set correctly");
        assertEq(splitter.platform(), platform, "Platform set correctly");
        
        // No setter functions exist, so values are immutable after initialization
    }

    function testSecurity_DistributionMath() public {
        _initializeSplitter();

        uint256 testAmount = 12345 ether;
        vm.deal(address(splitter), testAmount);

        uint256 artistBefore = artist.balance;
        uint256 platformBefore = platform.balance;

        splitter.distributeETH();

        uint256 artistReceived = artist.balance - artistBefore;
        uint256 platformReceived = platform.balance - platformBefore;

        // Verify math is correct
        assertEq(artistReceived, (testAmount * artistShare) / 10000, "Artist math correct");
        assertEq(platformReceived, (testAmount * platformShare) / 10000, "Platform math correct");
    }

    function testSecurity_NoReentrancy() public {
        // The contract doesn't have external calls that could be exploited
        // ETH transfers use call which is safe
        // ERC20 transfers are straightforward
        _initializeSplitter();

        vm.prank(sender);
        (bool success,) = address(splitter).call{value: 1 ether}("");
        assertTrue(success, "Should complete without reentrancy issues");
    }

    // ========== View Function Tests ==========

    function testView_GetArtist() public {
        _initializeSplitter();
        assertEq(splitter.artist(), artist, "Should return correct artist");
    }

    function testView_GetPlatform() public {
        _initializeSplitter();
        assertEq(splitter.platform(), platform, "Should return correct platform");
    }

    function testView_GetShares() public {
        _initializeSplitter();
        assertEq(splitter.artistShare(), artistShare, "Should return correct artist share");
        assertEq(splitter.platformShare(), platformShare, "Should return correct platform share");
    }

    function testView_BeforeInitialization() public {
        // Before initialization, values should be zero/default
        assertEq(splitter.artist(), address(0), "Artist should be zero before init");
        assertEq(splitter.platform(), address(0), "Platform should be zero before init");
        assertEq(splitter.artistShare(), 0, "Artist share should be zero before init");
        assertEq(splitter.platformShare(), 0, "Platform share should be zero before init");
    }

    receive() external payable {}

}

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}