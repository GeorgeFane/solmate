import {ERC20} from "../tokens/ERC20.sol";
import {ArborVault} from "./ArborVault.sol";

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