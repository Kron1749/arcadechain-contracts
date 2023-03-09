require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("@nomicfoundation/hardhat-network-helpers")
require("hardhat-contract-sizer")
require("dotenv").config()

const BSC_TESTNET_RPC_URL = process.env.BSC_TESTNET_RPC_URL
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL
const FANTOM_TESTNET_RPC_URL = process.env.FANTOM_TESTNET_RPC_URL
const PRIVATE_KEY = process.env.PRIVATE_KEY
const REPORT_GAS = process.env.REPORT_GAS || false
const CMC_API_KEY = process.env.COINMARKETCAP_API_KEY
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            forking: {
                url: MUMBAI_RPC_URL,
            },
            gasPrice: 1500000000,
            gas: 4100000,
        },
        bsc_testnet: {
            url: BSC_TESTNET_RPC_URL,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 97,
            blockConfirmations: 5,
            allowUnlimitedContractSize: true,
            gas: 5000000,
            gasPrice: 8000000000,
        },
        mumbai: {
            url: MUMBAI_RPC_URL,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 80001,
            blockConfirmations: 5,
            allowUnlimitedContractSize: true,
            gas: 5000000,
            gasPrice: 8000000000,
        },
        fantom_testnet: {
            url: FANTOM_TESTNET_RPC_URL,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 4002,
            blockConfirmations: 5,
            allowUnlimitedContractSize: true,
            gas: 5000000,
            gasPrice: 8000000000,
        },
    },
    etherscan: {
        apiKey: {
            mumbai: POLYGONSCAN_API_KEY,
        },
    },
    gasReporter: {
        enabled: REPORT_GAS,
        currency: "USD",
        token: "MATIC",
        outputFile: "gas-report.txt",
        noColors: true,
        coinmarketcap: CMC_API_KEY,
    },
    contractSizer: {
        runOnCompile: false,
        only: ["Raffle"],
    },
    namedAccounts: {
        deployer: {
            default: 0,
            1: 0,
        },
        player: {
            default: 1,
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.7",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 300,
                    },
                },
            },
            {
                version: "0.5.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 300,
                    },
                },
            },
        ],
    },
    mocha: {
        timeout: 500000,
    },
}
