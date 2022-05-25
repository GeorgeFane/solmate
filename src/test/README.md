# How to Run ArborVault Tests

1. Clone this repo and `cd solmate`

2. Install Foundry in a terminal: `curl -L https://foundry.paradigm.xyz | bash`

    - Above is for Linux, here are other instructions: [https://mirror.xyz/crisgarner.eth/BhQzl33tthkJJ3Oh2ehAD_2FXGGlMupKlrUUcDk0ALA](https://mirror.xyz/crisgarner.eth/BhQzl33tthkJJ3Oh2ehAD_2FXGGlMupKlrUUcDk0ALA)

3. Open a new terminal and run `foundryup`

4. In a terminal, run tests with forked Rinkeby: `forge test --fork-url https://rinkeby.infura.io/v3/02be7a3654c84c44a776f81558798c6b -vv`

    - You can use my Infura endpoint, or your own

# Potential Bug with Pool.withdraw() and Pool.supply()

Found a minor bug, probably a floating point issue.

In testWithdraw() in ArborVault.t.sol, the 4626 vault can start with 80 USDC, supply all of it to AAVE, and end up withdrawing 81 USDC. Tha vault can also start with 800 USDC and end with 801 USDC.

A similar issue is shown in testSupply(), where the vault is given 100 USDC total but ends with only 99.