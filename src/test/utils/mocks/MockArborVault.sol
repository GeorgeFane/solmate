// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ArborVault} from "../../../mixins/ArborVault.sol";
import {ERC20} from "../../../tokens/ERC20.sol";

contract MockArborVault is ArborVault {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    constructor() ArborVault() {}

    function beforeWithdraw(uint256, uint256) internal override {
        beforeWithdrawHookCalledCounter++;
    }

    function afterDeposit(uint256, uint256) internal override {
        afterDepositHookCalledCounter++;
    }

    function mintFreeShares(address owner, uint256 amount) public {
        _mint(owner, amount);
    }

    function burnShares(address owner, uint256 amount) public {
        _burn(owner, amount);
    }

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
