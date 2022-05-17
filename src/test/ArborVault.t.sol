// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {MockERC20} from "./utils/mocks/MockERC20.sol";
import {MockArborVault} from "./utils/mocks/MockArborVault.sol";

// code size is an issue due to importing solmate and AAVE contracts
// 2 solutions: inherit DSTest rather than DSTestPlus
//              and delete unnecessary functions in test.sol
// *DSTest originally from https://github.com/dapphub/ds-test/blob/master/src/test.sol
import {DSTest} from "./test.sol";

// create virtual "People" to interact with ArborVault in ArborVaultTest
contract Person {}

contract ArborVaultTest is DSTest {
    address constant USDC_ADDRESS = 0x02444D214962eC73ab733bB00Ca98879efAAa73d;
    MockERC20 underlying;
    MockArborVault vault;

    function setUp() public {
        // underlying = MockERC20(USDC_ADDRESS);
        underlying = new MockERC20("USD Coin", "USDC", 6);
        vault = new MockArborVault(underlying);
    }

    constructor() {
        setUp();
    }

    function invariantMetadata() public {
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

    function testMaxDeposit() public {
        Person alice = new Person();
        address aliceAddress = address(alice);

        assertEq(vault.maxDeposit(aliceAddress), 0, "testMaxDeposit 0");

        underlying.mint(aliceAddress, 1);
        assertEq(vault.maxDeposit(aliceAddress), 1, "testMaxDeposit after mint");

        underlying.burn(aliceAddress, 1);
        assertEq(vault.maxDeposit(aliceAddress), 0, "testMaxDeposit after burn");
    }

    function testMaxMint() public {
        // 3 situations:
        // 1. 1 share = 1 USDC when 0 USDC deposited in Vault
        // 2. 1 share = 1 USDC when some USDC deposited in Vault
        // 3. 1 share = 2 USDC when some USDC deposited in Vault

        // Situation 1
        Person alice = new Person();
        address aliceAddress = address(alice);

        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 0");

        underlying.mint(aliceAddress, 1);
        assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint after mint");

        underlying.burn(aliceAddress, 1);
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint after burn");

        // Situation 2
        underlying.mint(address(vault), 1);
        vault.mintToSelf(1);
        // Now there is 1 vault share and 1 deposited USDC
        assertEq(vault.convertToAssets(1), 1, "testMaxMint: 1 share = 1 USDC");

        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 0: 1 share = 1 USDC");

        underlying.mint(aliceAddress, 1);
        assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint after mint: 1 share = 1 USDC");

        underlying.burn(aliceAddress, 1);
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint after burn: 1 share = 1 USDC");

        // Situation 3
        underlying.mint(address(vault), 1);
        // Now there is 1 vault share and 2 deposited USDC
        assertEq(vault.convertToAssets(1), 2, "testMaxMint: 1 share = 2 USDC");

        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint 0: 1 share = 2 USDC");

        underlying.mint(aliceAddress, 2);
        assertEq(vault.maxMint(aliceAddress), 1, "testMaxMint after mint: 1 share = 2 USDC");

        underlying.burn(aliceAddress, 1);
        assertEq(vault.maxMint(aliceAddress), 0, "testMaxMint after burn: 1 share = 2 USDC");

        // Cleanup
        underlying.burn(address(vault), 2);
        vault.burn(1);
    }
}
