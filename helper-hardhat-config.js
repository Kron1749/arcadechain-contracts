const networkConfig = {
    default: {
        name: "hardhat",
        keepersUpdateInterval: "21600",
        callbackGasLimit: "900000",
    },
    31337: {
        name: "localhost",
        subscriptionId: "10204",
        gasLane: "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f", // 30 gwei
        keepersUpdateInterval: "21600", //in seconds
        raffleEntranceFee: "1000000000000000000", // 1 USDC
        callbackGasLimit: "900000",
    },
    97: {
        name: "bsc_testnet",
        subscriptionId: "10204",
        gasLane: "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314", // 30 gwei
        keepersUpdateInterval: "21600", //in seconds
        raffleEntranceFee: "1000000000000000000", // 1 USDC
        callbackGasLimit: "900000",
        vrfCoordinatorV2: "0x6A2AAd07396B36Fe02a22b33cf443582f682c82f",
    },
    80001: {
        name: "mumbai",
        subscriptionId: "10204",
        gasLane: "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f", // 30 gwei
        keepersUpdateInterval: "21600", //in seconds
        raffleEntranceFee: "1000000000000000000", // 1 USDC
        callbackGasLimit: "900000",
        vrfCoordinatorV2: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
    },
}

const PERCENTAGE_OF_BURN = 10
const GAME_FEE = 1
const PERCENTAGE_OF_GOLDEN_TICKET = 10
const VERIFICATION_BLOCK_CONFIRMATIONS = 6
const developmentChains = ["hardhat", "localhost"]
const firstMultiplayer = "0x40004000000000000000000000000000" // 2.5
const secondMultiplayer = "0x40000000000000000000000000000000" // 2
const thirdMultiplayer = "0x3fff8000000000000000000000000000" // 1.5
const fourthMultiplayer = "0x3fff0000000000000000000000000000" // 1
const fifthMultiplayer = "0x3ffe999999999999a000000000000000" // 0.8
const sixthMultiplayer = "0x3ffe0000000000000000000000000000" // 0.5
const seventhMultiplayer = "0x3ffc999999999999a000000000000000" // 0.2

module.exports = {
    developmentChains,
    firstMultiplayer,
    secondMultiplayer,
    thirdMultiplayer,
    fourthMultiplayer,
    fifthMultiplayer,
    sixthMultiplayer,
    seventhMultiplayer,
    GAME_FEE,
    networkConfig,
    VERIFICATION_BLOCK_CONFIRMATIONS,
    PERCENTAGE_OF_BURN,
    PERCENTAGE_OF_GOLDEN_TICKET,
}
