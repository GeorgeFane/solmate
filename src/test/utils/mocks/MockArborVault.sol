// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ArborVault} from "../../../mixins/ArborVault.sol";
import {ERC20} from "../../../tokens/ERC20.sol";

contract MockArborVault is ArborVault {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    constructor(address USDC_ADDRESS_, address AAVE_POOL_ADDRESS_)
        ArborVault(USDC_ADDRESS_, AAVE_POOL_ADDRESS_) {}

    function beforeWithdraw(uint256, uint256) internal override {
        beforeWithdrawHookCalledCounter++;
    }

    function afterDeposit(uint256, uint256) internal override {
        afterDepositHookCalledCounter++;
    }

    function mintFreeShares(address owner, uint256 amount) public {
        _mint(owner, amount);
    }

    /// @notice This uses _burn on Vault Shares, which the MockArborVault contract inherits
        /// (contrast with next function).
    function burnShares(address owner, uint256 amount) public {
        _burn(owner, amount);
    }

    /// @notice _burn is internal to USDC's ERC20 contract, so it can't be called from MockArborvault contract.
        /// This is a cheat to transfer USDC to a dead address
        /// (can't do 0 address due to "transfer" definition, so I picked USDC_ADDRESS).
    function burnUsdc(uint256 amount) public {
        USDC_CONTRACT.transfer(USDC_ADDRESS, amount);
    }

    function transferToAave(uint256 amount) public {
        USDC_CONTRACT.approve(AAVE_POOL_ADDRESS, amount);
        AAVE_POOL.supply(address(USDC_CONTRACT), amount, address(this), 0);
    }

    function withdrawFromAave(uint256 amount) public {
        AAVE_POOL.withdraw(address(USDC_CONTRACT), amount, address(this));
    }
}
