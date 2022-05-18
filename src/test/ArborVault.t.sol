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
    function burn(address erc20_address, uint256 amount) public {
        MockERC20(erc20_address).transfer(USDC_ADDRESS, amount);
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

        alice.burn(USDC_ADDRESS, 1);
        assertEq(vault.maxDeposit(aliceAddress), 0, "testMaxDeposit 2");
    }
    // maxMint() is convertToShares(maxDeposit()),
    // and convertToShares is provided by solmate,
    // so no need to test maxMint()

    // 11 logs: all Transfer events
    // function testMaxMint() public {
    //     // 3 situations:
    //     // 1. 1 share = 1 USDC when 0 USDC deposited in Vault
    //     // 2. 1 share = 1 USDC when some USDC deposited in Vault
    //     // 3. 1 share = 2 USDC when some USDC deposited in Vault

    //     // Situation 1
    //     Person alice = new Person();
    //     address aliceAddress = address(alice);

    //     assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 1.0");

    //     underlying.mint(aliceAddress, 1);
    //     assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint 1.1");

    //     alice.burn(USDC_ADDRESS, 1);
    //     assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 1.2");

    //     // Situation 2
    //     underlying.mint(aliceAddress, 1);
    //     vault.mintFreeShares(aliceAddress, 1);
    //     // Now there is 1 vault share and 1 deposited USDC
    //     assertEq(vault.convertToAssets(1), 1, "testMaxMint 2.");

    //     assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 2.0");

    //     underlying.mint(aliceAddress, 1);
    //     assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint 2.1");

    //     alice.burn(USDC_ADDRESS, 1);
    //     assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 2.2");

    //     // Situation 3
    //     underlying.mint(address(vault), 1);
    //     // Now there is 1 vault share and 2 deposited USDC
    //     assertEq(vault.convertToAssets(1), 2, "testMaxMint: 3.");

    //     assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 3.0");

    //     underlying.mint(aliceAddress, 2);
    //     assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint 3.1");

    //     alice.burn(USDC_ADDRESS, 1);
    //     assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 3.2");

    //     // Cleanup
    //     vault.burnUsdc(2);
    //     alice.burn(address(vault), 1);
    // }

    // checkRatio is only called by deposit and withdraw,
    // so reserve ratio may be off

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

        alice.burn(address(vault), 9);
        bob.burn(address(vault), 1);
    }
    // maxWithdraw() is convertToAssets(maxRedeem()),
    // and convertToAssets is provided by solmate,
    // so no need to test maxWithdraw()
}