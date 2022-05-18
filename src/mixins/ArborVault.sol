// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";
import {SafeTransferLib} from "../utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

import {ERC4626} from "./ERC4626.sol";
import {Pool} from "https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/pool/Pool.sol";

contract ArborVault is ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public constant USDC_ADDRESS = 0x02444D214962eC73ab733bB00Ca98879efAAa73d;
    ERC20 constant USDC_CONTRACT = ERC20(USDC_ADDRESS);
    // ERC20 public immutable USDC_CONTRACT;

    address public constant AAVE_POOL_ADDRESS = 0xC4744c984975ab7d41e0dF4B37E048Ef8006115E;
    Pool constant AAVE_POOL = Pool(AAVE_POOL_ADDRESS);

    constructor() ERC4626(USDC_CONTRACT, "Mock Token Vault", "vwTKN") {}

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    // ~20% of deposited USDC held in vault
    function reserveAssets() public view returns (uint256) {
        return USDC_CONTRACT.balanceOf(address(this));
    }

    // ~80% of deposited USDC supplied to AAVE
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

    function totalAssets() public view override returns (uint256) {
        return reserveAssets() + collateralAssets();
    }

    // quoted in shares
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint original_return = supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
        return min(original_return, convertToShares(reserveAssets()));
    }

    // quoted in assets
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

    // quoted in usdc
    function maxDeposit(address owner) public view override returns (uint256) {
        return USDC_CONTRACT.balanceOf(owner);
    }

    // quoted in shares
    function maxMint(address owner) public view override returns (uint256) {
        return convertToShares(maxDeposit(owner));
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

    // quoted in shares
    function maxRedeem(address owner) public view override returns (uint256) {
        return min(balanceOf[owner], convertToShares(reserveAssets()));
    }

    // quoted in usdc
    function maxWithdraw(address owner) public view override returns (uint256) {
        return convertToAssets(maxRedeem(owner));
    }
}