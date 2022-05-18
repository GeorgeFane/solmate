# How to Run ArborVault Tests

1. Create a new file in Remix (remix.ethereum.org) and paste this code:

```
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "https://github.com/arbor-bounty/solmate/blob/main/src/test/ArborVault.t.sol";

contract Contract is ArborVaultTest() {}
```

2. Go to Remix's "Solidity compiler" tab and make sure "Auto compile" is off and "Enable optimization" is on, with the number input next to it, runs, set to 1.

    - The code size if very large, and these options prevent your computer from freezing and Remix from refusing to deploy.

3. Go to Remix's "Deploy and run transactions" tab and change the "ENVIRONMENT" dropdown to "Injected Web3". Make sure your Metamask is switched to Avalanche C-Chain Fuji ([instructions](https://docs.avax.network/quickstart/fuji-workflow/#set-up-fuji-network-on-metamask-optional)) and has test AVAX ([faucet](https://faucet.avax-test.network/)).

4. Run test functions in any order

    - You can view the test code in Remix's file explorer: /.deps/github/arbor-bounty/solmate/src/test/ArborVault.t.sol