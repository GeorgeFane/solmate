// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "../tokens/ERC20.sol";
import {SafeTransferLib} from "../utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

import {ERC4626} from "./ERC4626.sol";
import {IPool} from "/workspace/solmate/node_modules/@aave/core-v3/contracts/interfaces/IPool.sol";

contract ArborVault is ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address immutable USDC_ADDRESS;
    ERC20 immutable USDC_CONTRACT;

    address immutable AAVE_POOL_ADDRESS;
    IPool immutable AAVE_POOL;

    constructor(address USDC_ADDRESS_, address AAVE_POOL_ADDRESS_)
        ERC4626(ERC20(USDC_ADDRESS_), "Mock Token Vault", "vwTKN")
    {
        USDC_ADDRESS = USDC_ADDRESS_;
        USDC_CONTRACT = ERC20(USDC_ADDRESS);

        AAVE_POOL_ADDRESS = AAVE_POOL_ADDRESS_;
        AAVE_POOL = IPool(AAVE_POOL_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice The contract holds ~20% of the deposited asset directly instead of in the vault
        /// which likely covers a user's withdrawal needs for a single transaction
    function reserveAssets() public view returns (uint256) {
        return USDC_CONTRACT.balanceOf(address(this));
    }

    /// @notice ~80% of deposited USDC supplied to AAVE to earn interest
    /// @dev AAVE adds two additional decimal places to totalCollateralBase
        /// (8 decimals for USDC rather than 6). Not sure why, but dividing by 100 corrects this.
    function collateralAssets() public view returns (uint256) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = AAVE_POOL.getUserAccountData(address(this));

        return totalCollateralBase / 100;
    }

    function rawCollateralAssets() public view returns (uint256) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = AAVE_POOL.getUserAccountData(address(this));

        return totalCollateralBase;
    }

    function totalAssets() public view override returns (uint256) {
        return reserveAssets() + collateralAssets();
    }

    /// @notice Quoted in shares
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint original_return = supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
        return min(original_return, convertToShares(reserveAssets()));
    }

    /// @notice Quoted in assets
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return min(convertToAssets(shares), reserveAssets());
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function checkRatio() public {
        uint total_usdc = totalAssets();

        // avoid divide by 0
        if (total_usdc == 0) {
            return;
        }

        uint current_reserve = reserveAssets();
        uint percent_reserve = current_reserve * 100 / total_usdc;

        // want reserve ratio to be 20%
        uint desired_reserve = total_usdc / 5;
        if (percent_reserve < 15) {
            uint withdraw_amount = desired_reserve - current_reserve;
            AAVE_POOL.withdraw(address(USDC_CONTRACT), withdraw_amount, address(this));
        }
        else if (percent_reserve > 25) {
            uint deposit_amount = current_reserve - desired_reserve;
            USDC_CONTRACT.approve(AAVE_POOL_ADDRESS, deposit_amount);
            AAVE_POOL.supply(address(USDC_CONTRACT), deposit_amount, address(this), 0);
        }
    }

    function deposit(uint assets) public {
        deposit(assets, msg.sender);

        checkRatio();
    }

    function withdraw(uint assets) public {
        require(assets < maxWithdraw(msg.sender), "Can't withdraw more than your max");
        withdraw(assets, msg.sender, msg.sender);

        checkRatio();
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Quoted in assets
    function maxDeposit(address owner) public view override returns (uint256) {
        return USDC_CONTRACT.balanceOf(owner);
    }

    /// @notice Quoted in shares
    function maxMint(address owner) public view override returns (uint256) {
        return convertToShares(maxDeposit(owner));
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

    /// @notice Quoted in shares
    function maxRedeem(address owner) public view override returns (uint256) {
        return min(balanceOf[owner], convertToShares(reserveAssets()));
    }

    /// @notice Quoted in assets
    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(maxRedeem(owner));
    }
}