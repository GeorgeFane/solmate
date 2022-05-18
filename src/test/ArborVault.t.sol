// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {MockERC20} from "./utils/mocks/MockERC20.sol";
import {MockArborVault} from "./utils/mocks/MockArborVault.sol";

// *DSTest originally from https://github.com/dapphub/ds-test/blob/master/src/test.sol
import {DSTest} from "./test.sol";
// code size is an issue due to importing solmate and AAVE contracts
// 2 solutions: inherit DSTest rather than DSTestPlus
//              and delete unnecessary functions in test.sol

// create virtual "People" to interact with ArborVault in ArborVaultTest
contract Person {
    address constant USDC_ADDRESS = 0x02444D214962eC73ab733bB00Ca98879efAAa73d;

    // _burn is internal, so I can't call it
    function burnUsdc(uint256 amount) public {
        MockERC20(USDC_ADDRESS).transfer(USDC_ADDRESS, amount);
    }
}

contract ArborVaultTest is DSTest {
    address constant USDC_ADDRESS = 0x02444D214962eC73ab733bB00Ca98879efAAa73d;
    address constant AAVE_POOL_ADDRESS = 0xC4744c984975ab7d41e0dF4B37E048Ef8006115E;

    MockERC20 underlying;
    MockArborVault vault;

    function setUp() internal {
        underlying = MockERC20(USDC_ADDRESS);
        // underlying = new MockERC20("USD Coin", "USDC", 6);

        vault = new MockArborVault();
    }

    constructor() {
        setUp();
    }

    // when run correctly: 0 logs
    function invariantMetadata() public {
        // assertEq emits logs/events when violated
        assertEq(vault.name(), "Mock Token Vault", "Invariant name");
        assertEq(vault.symbol(), "vwTKN", "Invariant symbol");
        assertEq(vault.decimals(), 6, "Invariant decimals");
    }

    // function testMetadata(string calldata name, string calldata symbol) public {
    //     MockArborVault vlt = new MockArborVault();
    //     assertEq(vlt.name(), name, "Metadata name");
    //     assertEq(vlt.symbol(), symbol, "Metadata symbol");
    //     assertEq(address(vlt.asset()), address(underlying), "Metadata asset");
    // }

    // 2 logs: Transfer events for mint and burn
    function testMaxDeposit() public {
        Person alice = new Person();
        address aliceAddress = address(alice);

        assertEq(vault.maxDeposit(aliceAddress), 0, "testMaxDeposit 0");

        underlying.mint(aliceAddress, 1);
        assertEq(vault.maxDeposit(aliceAddress), 1, "testMaxDeposit 1");

        alice.burnUsdc(1);
        assertEq(vault.maxDeposit(aliceAddress), 0, "testMaxDeposit 2");
    }
    // maxMint() is convertToShares(maxDeposit()),
    // and convertToShares is provided by solmate,
    // so no need to test maxMint()

    // 13 logs
    function testMaxMint() public {
        // 2 situations:
        // 1. Vault and AAVE both empty, 1 USDC = 1 share
        // 2. Vault and AAVE not empty, 1 USDC = 1 share
        // 3. Vault and AAVE not empty, 2 USDC = 1 share

        Person alice = new Person();
        address aliceAddress = address(alice);

        // Situation 1
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 1.0");

        underlying.mint(aliceAddress, 1);
        assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint 1.1");

        alice.burnUsdc(1);
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 1.2");

        // Situation 2
        underlying.mint(address(vault), 1);
        vault.mintFreeShares(aliceAddress, 1);

        assertEq(vault.totalAssets(), 1, "testMaxMint totalAssets");
        assertEq(vault.totalSupply(), 1, "testMaxMint totalSupply");

        assertEq(vault.convertToShares(1), 1, "testMaxMint 2.");

        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 2.0");

        underlying.mint(aliceAddress, 1);
        // alice has 1 USDC
        assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint 2.1");

        underlying.mint(aliceAddress, 1);
        // alice has 2 USDC
        assertEq(vault.maxMint(aliceAddress), 2, "testMaxMint 2.2");

        alice.burnUsdc(2);

        // Situation 3
        underlying.mint(address(vault), 1);

        assertEq(vault.totalAssets(), 2, "testMaxMint totalAssets");
        assertEq(vault.totalSupply(), 1, "testMaxMint totalSupply");

        assertEq(vault.convertToAssets(1), 2, "testMaxMint 3.");

        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 3.0");

        underlying.mint(aliceAddress, 1);
        // alice has 1 USDC
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 3.1");

        underlying.mint(aliceAddress, 1);
        // alice has 2 USDC
        assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint 3.2");

        // Cleanup
        alice.burnUsdc(2);
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 3.3");

        vault.burnShares(aliceAddress, 1);
        vault.burnUsdc(2);

        assertEq(vault.totalAssets(), 0, "testMaxMint totalAssets");
        assertEq(vault.totalSupply(), 0, "testMaxMint totalSupply");
    }

    // 17 logs
    function testReserveAssets() public {
        // 4 situations:
        // 1. No USDC anywhere
        // 3. USDC only in vault
        // 2. USDC in AAVE as aUSDC
        // 4. USDC in both vault and AAVE

        // Situation 1
        assertEq(vault.reserveAssets(), 0, "testReserveAssets 1");

        // Situation 2
        underlying.mint(address(vault), 1);
        assertEq(vault.reserveAssets(), 1, "testReserveAssets 2");

        // Situation 3
        vault.transferToAave(1);
        assertEq(vault.reserveAssets(), 0, "testReserveAssets 3");

        // Situation 4
        underlying.mint(address(vault), 1);
        assertEq(vault.reserveAssets(), 1, "testReserveAssets 4");

        // Cleanup
        vault.withdrawFromAave(1);
        assertEq(vault.reserveAssets(), 2, "testReserveAssets 5");
        vault.burnUsdc(2);
    }
    
    // 17 logs
    function testCollateralAssets() public {
        // 4 situations:
        // 1. No USDC anywhere
        // 3. USDC only in vault
        // 2. USDC in AAVE as aUSDC
        // 4. USDC in both vault and AAVE

        // Situation 1
        assertEq(vault.collateralAssets(), 0, "testCollateralAssets 1");

        // Situation 2
        underlying.mint(address(vault), 1);
        assertEq(vault.collateralAssets(), 0, "testCollateralAssets 2");

        // Situation 3
        vault.transferToAave(1);
        assertEq(vault.collateralAssets(), 1, "testCollateralAssets 3");

        // Situation 4
        underlying.mint(address(vault), 1);
        assertEq(vault.collateralAssets(), 1, "testCollateralAssets 4");

        // Cleanup
        vault.withdrawFromAave(1);
        assertEq(vault.collateralAssets(), 0, "testCollateralAssets 5");
        vault.burnUsdc(2);
    }
    // totalAssets() is reserveAssets() + collateralAssets(), so no need to test individually

    // 21 logs
    function testMaxRedeem() public {
        // 4 situations:
        // 1. Alice has 0 shares and vault has 0 shares: reserveAssets() converted to shares
        // 2. Alice has 0 shares and vault has some shares
        // 3. Alice can redeem all of her shares: her shares < convertToAssets(reserveAssets())
        // 4. Alice can't redeem all of her shares: her shares > convertToAssets(reserveAssets())
        
        Person alice = new Person();
        address aliceAddress = address(alice);

        Person bob = new Person();
        address bobAddress = address(bob);

        // Situation 1
        assertEq(vault.maxRedeem(aliceAddress), 0, "testMaxRedeem 1.0");

        // Situation 2
        underlying.mint(address(vault), 1);
        vault.mintFreeShares(bobAddress, 1);

        assertEq(vault.convertToAssets(1), 1, "testMaxMint 2.");
        assertEq(vault.maxRedeem(aliceAddress), 0, "testMaxRedeem 2.0");
        assertEq(vault.maxRedeem(bobAddress), 1, "testMaxRedeem 2.1");

        // Situation 3
        underlying.mint(address(vault), 9);
        vault.mintFreeShares(aliceAddress, 9);

        assertEq(vault.convertToAssets(1), 1, "testMaxMint 3.");
        assertEq(vault.maxRedeem(aliceAddress), 9, "testMaxRedeem 3.0");
        assertEq(vault.maxRedeem(bobAddress), 1, "testMaxRedeem 3.1");

        // Situation 4
        // imitates reserve ratio, with 80% in AAVE
        vault.transferToAave(8);
        assertEq(vault.reserveAssets(), 2, "testMaxRedeem reserveAssets");

        assertEq(vault.convertToAssets(1), 1, "testMaxMint 4.");
        assertEq(vault.maxRedeem(aliceAddress), 2, "testMaxRedeem 4.0");
        assertEq(vault.maxRedeem(bobAddress), 1, "testMaxRedeem 4.1");

        // Cleanup
        vault.withdrawFromAave(8);
        vault.burnUsdc(10);

        vault.burnShares(aliceAddress, 9);
        vault.burnShares(bobAddress, 1);
    }
    // maxWithdraw() is convertToAssets(maxRedeem()),
    // and convertToAssets is provided by solmate,
    // so no need to test maxWithdraw()

    // 66 logs
    function testCheckRatio() public {
        // 5 situations:
        // 1. Vault and AAVE are empty
        // 2. Vault has USDC, AAVE is empty
        // 3. Vault is empty, AAVE is not
        // 4. Neither are empty, new deposit to vault
        // 5. Test checkRatio behavior when ratio is 20%
        // 6. 15%
        // 7. 14%
        // 8. 25%
        // 9. 26%

        // Situation 1
        assertEq(vault.reserveAssets(), 0, "testCheckRatio 1.0");
        assertEq(vault.totalAssets(), 0, "testCheckRatio 1.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 0, "testCheckRatio 1.2");
        assertEq(vault.totalAssets(), 0, "testCheckRatio 1.3");

        // Situation 2
        underlying.mint(address(vault), 100);

        assertEq(vault.reserveAssets(), 100, "testCheckRatio 2.0");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 2.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 20, "testCheckRatio 2.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 2.3");

        // Situation 3
        vault.burnUsdc(20);

        assertEq(vault.reserveAssets(), 0, "testCheckRatio 3.0");
        assertEq(vault.totalAssets(), 80, "testCheckRatio 3.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 16, "testCheckRatio 3.2");
        assertEq(vault.totalAssets(), 80, "testCheckRatio 3.3");

        // Situation 4
        underlying.mint(address(vault), 20);

        assertEq(vault.reserveAssets(), 36, "testCheckRatio 4.0");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 4.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 20, "testCheckRatio 4.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 4.3");

        // Situation 5
        vault.checkRatio();

        assertEq(vault.reserveAssets(), 20, "testCheckRatio 5.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 5.3");

        // Situation 6
        vault.transferToAave(5);

        assertEq(vault.reserveAssets(), 15, "testCheckRatio 6.0");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 6.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 15, "testCheckRatio 6.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 6.3");

        // Situation 7
        vault.transferToAave(1);

        assertEq(vault.reserveAssets(), 14, "testCheckRatio 7.0");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 7.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 20, "testCheckRatio 7.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 7.3");

        // Situation 8
        vault.withdrawFromAave(5);

        assertEq(vault.reserveAssets(), 25, "testCheckRatio 8.0");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 8.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 25, "testCheckRatio 8.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 8.3");

        // Situation 9
        vault.withdrawFromAave(1);

        assertEq(vault.reserveAssets(), 26, "testCheckRatio 9.0");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 9.1");

        vault.checkRatio();

        assertEq(vault.reserveAssets(), 20, "testCheckRatio 9.2");
        assertEq(vault.totalAssets(), 100, "testCheckRatio 9.3");

        // Cleanup
        vault.withdrawFromAave(80);
        vault.burnUsdc(100);
    }
    // deposit and withdraw functions simply call solmate's deposit and withdraw
    // and then check ratio, so no need to test ArborVault's deposit and withdraw

    // 4 logs
    function testPreviewRedeem() public {
        // 2 situations:
        // 1. Nothing in vault: reserveAssets() is limiting factor
        // 2. Some USDC in vault: reserveAssets() is sometimes limiting factor

        Person alice = new Person();
        address aliceAddress = address(alice);

        // Situation 1
        assertEq(vault.previewRedeem(0), 0, "testPreviewRedeem 1.0");
        assertEq(vault.previewRedeem(1), 0, "testPreviewRedeem 1.1");
        assertEq(vault.previewRedeem(2), 0, "testPreviewRedeem 1.1");

        // Situation 2
        underlying.mint(address(vault), 1);
        vault.mintFreeShares(aliceAddress, 1);

        assertEq(vault.totalAssets(), 1, "testPreviewRedeem totalAssets");
        assertEq(vault.totalSupply(), 1, "testPreviewRedeem totalSupply");
        assertEq(vault.convertToAssets(1), 1, "testPreviewRedeem 2.");

        assertEq(vault.previewRedeem(0), 0, "testPreviewRedeem 2.0");
        assertEq(vault.previewRedeem(1), 1, "testPreviewRedeem 2.1");
        assertEq(vault.previewRedeem(2), 1, "testPreviewRedeem 2.2");

        // Cleanup
        vault.burnUsdc(1);
        vault.burnShares(aliceAddress, 1);

        assertEq(vault.totalAssets(), 0, "testPreviewRedeem totalAssets");
        assertEq(vault.totalSupply(), 0, "testPreviewRedeem totalSupply");
    }

    // 4 logs
    function testPreviewWithdraw() public {
        // 2 situations:
        // 1. Nothing in vault: reserveAssets() is limiting factor
        // 2. Some USDC in vault: reserveAssets() is sometimes limiting factor

        Person alice = new Person();
        address aliceAddress = address(alice);

        // Situation 1
        assertEq(vault.previewWithdraw(0), 0, "testPreviewWithdraw 1.0");
        assertEq(vault.previewWithdraw(1), 0, "testPreviewWithdraw 1.1");
        assertEq(vault.previewWithdraw(2), 0, "testPreviewWithdraw 1.1");

        // Situation 2
        underlying.mint(address(vault), 1);
        vault.mintFreeShares(aliceAddress, 1);

        assertEq(vault.totalAssets(), 1, "testPreviewWithdraw totalAssets");
        assertEq(vault.totalSupply(), 1, "testPreviewWithdraw totalSupply");
        assertEq(vault.convertToAssets(1), 1, "testPreviewWithdraw 2.");

        assertEq(vault.previewWithdraw(0), 0, "testPreviewWithdraw 2.0");
        assertEq(vault.previewWithdraw(1), 1, "testPreviewWithdraw 2.1");
        assertEq(vault.previewWithdraw(2), 1, "testPreviewWithdraw 2.2");

        // Cleanup
        vault.burnUsdc(1);
        vault.burnShares(aliceAddress, 1);

        assertEq(vault.totalAssets(), 0, "testPreviewWithdraw totalAssets");
        assertEq(vault.totalSupply(), 0, "testPreviewWithdraw totalSupply");
    }
}