# for Rinkeby
$USDC_ADDRESS = 0x5B8B635c2665791cf62fe429cB149EaB42A3cEd8
$AAVE_POOL_ADDRESS = 0x3561c45840e2681495ACCa3c50Ef4dAe330c94F8

$ETH_RPC_URL = https://rinkeby.infura.io/v3/02be7a3654c84c44a776f81558798c6b
forge test --fork-url https://rinkeby.infura.io/v3/02be7a3654c84c44a776f81558798c6b -vv

curl -L https://foundry.paradigm.xyz | bash
foundryup

