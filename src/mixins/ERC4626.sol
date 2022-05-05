// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";
import {SafeTransferLib} from "../utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

import {Pool} from "https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/pool/Pool.sol";

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol)
abstract contract ERC4626 is ERC20 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable asset;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}

contract ArborVault is ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address constant USDC_ADDRESS = 0x02444D214962eC73ab733bB00Ca98879efAAa73d;
    ERC20 constant USDC_CONTRACT = ERC20(USDC_ADDRESS);

    address constant AAVE_POOL_ADDRESS = 0xC4744c984975ab7d41e0dF4B37E048Ef8006115E;
    Pool constant AAVE_POOL = Pool(AAVE_POOL_ADDRESS);

    constructor() ERC4626(USDC_CONTRACT, "Vault Shares", "VASH") {}

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    // ~20% of deposited USDC held in vault
    function reserve_assets() public view returns (uint256) {
        return USDC_CONTRACT.balanceOf(address(this));
    }

    // ~80% of deposited USDC supplied to AAVE
    function collateral_assets() public view returns (uint256) {
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
        return reserve_assets() + collateral_assets();
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        uint original_return = supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());

        return assets < reserve_assets() ? original_return : reserve_assets();
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return previewWithdraw(convertToAssets(shares));
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function check_ratio() internal {

        uint current_reserve = reserve_assets();
        uint collateral_base = collateral_assets();
        uint total_usdc = totalAssets();

        uint percent_reserve = current_reserve * 100 / total_usdc;

        // want reserve ratio to be 20%
        uint desired_reserve = total_usdc / 5;
        if (percent_reserve < 15) {
            uint withdraw_amount = desired_reserve - current_reserve;
            AAVE_POOL.withdraw(USDC_ADDRESS, withdraw_amount, address(this));
        }
        else if (percent_reserve > 25) {
            uint deposit_amount = current_reserve - desired_reserve;
            USDC_CONTRACT.approve(AAVE_POOL_ADDRESS, deposit_amount);
            AAVE_POOL.supply(USDC_ADDRESS, deposit_amount, address(this), 0);
        }
    }

    function deposit(uint assets) public {
        deposit(assets, msg.sender);

        check_ratio();
    }

    function withdraw(uint assets) public {
        withdraw(assets, msg.sender, msg.sender);

        check_ratio();
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

    function min(uint x, uint y) internal view returns (uint) {
        return x < y ? x : y;
    }

    // quoted in usdc
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint owner_assets = convertToAssets(balanceOf[owner]);
        return min(owner_assets, reserve_assets());
    }

    // quoted in shares
    function maxRedeem(address owner) public view override returns (uint256) {
        return convertToShares(maxWithdraw(owner));
    }
}

contract VaultTest {
    // arbor vault refers to the contract above, that Alex and I wrote
    ArborVault VAULT_CONTRACT;

    address constant USDC_ADDRESS = 0x02444D214962eC73ab733bB00Ca98879efAAa73d;
    ERC20 constant USDC_CONTRACT = ERC20(USDC_ADDRESS);
    address VAULT_ADDRESS;
    // deploy new ArborVault (everything starts at 0) and pass its address into VaultTest's constructor
    constructor(address input_VAULT_ADDRESS) public {
        VAULT_CONTRACT = ArborVault(input_VAULT_ADDRESS);
        VAULT_ADDRESS = input_VAULT_ADDRESS;
    }

    // call this first
    function testBoot() public {
        //doing functions in quick succession so assuming no interests
        require(
           (VAULT_CONTRACT.reserve_assets() == 0) && VAULT_CONTRACT.collateral_assets() == 0 && VAULT_CONTRACT.totalAssets() == 0,
            "assets don't start at 0"
        );

    }
    
    // call this second
     function testDeposit() public {
         USDC_CONTRACT.approve(VAULT_ADDRESS, 20);
       VAULT_CONTRACT.deposit(20);
        /*require(
            VAULT_CONTRACT.reserve_assets() == 2  && VAULT_CONTRACT.collateral_assets() == 8 && VAULT_CONTRACT.totalAssets() == 10,
            "assets not added properly"
        );
        
        require(
            VAULT_CONTRACT.maxWithdraw(address(this)) == 2,
            "maxWithdraw incorrect"
        );
        require(
            VAULT_CONTRACT.maxRedeem(address(this)) == 2,
            "maxRedeem incorrect"
        );
        USDC_CONTRACT.approve(VAULT_ADDRESS, 10);
        VAULT_CONTRACT.deposit(10);*/
        require(
            VAULT_CONTRACT.maxWithdraw(address(this)) == 4,
            "maxWithdraw incorrect"
        );
        require(
            VAULT_CONTRACT.maxRedeem(address(this)) == 4,
            "maxRedeem incorrect"
        );
        require(
            VAULT_CONTRACT.reserve_assets() == 4  && VAULT_CONTRACT.collateral_assets() == 16 && VAULT_CONTRACT.totalAssets() == 20,
            "assets not added properly"
        );
        require(
            VAULT_CONTRACT.maxDeposit(address(this)) >= 0 && (VAULT_CONTRACT.maxDeposit(address(this)) == VAULT_CONTRACT.maxMint(address(this))),
            "maxDeposit and maxMint incorrect"
        );
        
        


     }

    // call this third
     function testWithdraw() public {
        VAULT_CONTRACT.withdraw(1);
        require(
            VAULT_CONTRACT.reserve_assets() == 3  && VAULT_CONTRACT.collateral_assets() == 16 && VAULT_CONTRACT.totalAssets() == 19,
            "assets not removed properly1"

        );
        VAULT_CONTRACT.withdraw(1);
        require(
            VAULT_CONTRACT.reserve_assets() == 3  && VAULT_CONTRACT.collateral_assets() == 15 && VAULT_CONTRACT.totalAssets() == 18,
            "assets not removed properly2"
        );
        VAULT_CONTRACT.withdraw(VAULT_CONTRACT.maxWithdraw(address(this)));
        require(
            VAULT_CONTRACT.reserve_assets() == 3  && VAULT_CONTRACT.collateral_assets() == 12 && VAULT_CONTRACT.totalAssets() == 15,
            "assets not removed properly (maxWithdraw)"
        );
     }
}
