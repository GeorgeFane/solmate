// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ArborVault} from "../../../mixins/ArborVault.sol";

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
}
