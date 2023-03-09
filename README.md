[![Node.js CI](https://github.com/arcadechain/arcadechain-contracts/actions/workflows/node.js.yaml/badge.svg?branch=master)](https://github.com/arcadechain/arcadechain-contracts/actions/workflows/node.js.yaml)

# pre-requisites
- metamask installed in the browser
```
npm install -g truffle
npm install -g ganache-cli
```
For Ethereum Networks outside of local:
- set your metamask account mnemonic to `.secret` file (do not commit it!)
- account loaded with ETH for gas fees


## installation
```
npm install
```

# contract development workflow
## Run a local ethereum network, and deploy your token contract to this local network
- Run the command `truffle develop` (to run a local ethereum network)
    - Run  the command `compile` (to compile your solidity contract files)
    - Run the command `migrate --reset` (to deploy your contract to the locally running ethereum network)
    - Run the command `test` (to deploy your contract to the locally [i.e. withing truffle environemnt] running ethereum network)

- Run the command `truffle migrate --reset --network rinkeby` (to deploy your contract to the rinkeby ethereum network)
- Run the command `truffle migrate --network cronos_testnet` (to deploy your contract to the Cronos test network)
- Run command `truffle migrate -f 2 --to 2 --network cronos_testnet` to deploy only migration file 2

# flattening contract
```
npm install truffle-flattener -g
```
the run:
```
 truffle-flattener contracts/Slot.sol
```
# contract addresses
- Test Admin Address - `0x588acF052631756422844856e1dc2Ef6066ce121` explorer: https://cronos.org/explorer/testnet3/address/0x588acF052631756422844856e1dc2Ef6066ce121
- TUSD - Cronos Test - `0x912aAEA32355DA6FeB20D98E73B9C81B5afd6A2e`
- Slot - Cronos Test = `0xF137Ef1CbBC39548c6564551614Ef0354f4d9aa3`