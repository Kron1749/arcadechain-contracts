const { network, ethers } = require("hardhat")
const { networkConfig, developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

const FUND_AMOUNT = "1000000000000000000000"

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    let vrfCoordinatorV2Address, subscriptionId
    const usdc = await ethers.getContract("USDC")
    const treasury = await ethers.getContract("Treasury")
    const allocations = [65, 15, 10, 5, 3, 2]
    if (chainId == 31337) {
        const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        const trxResponse = await vrfCoordinatorV2Mock.createSubscription()
        const trxReceipt = await trxResponse.wait()
        subscriptionId = trxReceipt.events[0].args.subId
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    }

    const arguments = [
        vrfCoordinatorV2Address,
        subscriptionId,
        networkConfig[chainId]["callbackGasLimit"],
        networkConfig[chainId]["gasLane"],
        networkConfig[chainId]["keepersUpdateInterval"],
        usdc.address,
        allocations,
        treasury.address,
        deployer,
        networkConfig[chainId]["raffleEntranceFee"],
    ]
    const lottery = await deploy("Lottery", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: 1,
    })

    // Contract verifying
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(lottery.address, arguments)
    }
}
module.exports.tags = ["all", "lottery"]
