// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ArborVault} from "../../../mixins/ArborVault.sol";
import {ERC20} from "../../../tokens/ERC20.sol";

contract MockArborVault is ArborVault {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    constructor(ERC20 underlying) ArborVault(underlying) {}

    function beforeWithdraw(uint256, uint256) internal override {
        beforeWithdrawHookCalledCounter++;
    }

    function afterDeposit(uint256, uint256) internal override {
        afterDepositHookCalledCounter++;
    }

    function mintToSelf(uint256 amount) public {
        _mint(address(this), amount);
    }

    function burn(uint256 amount) public {
        _burn(address(this), amount);
    }
}
