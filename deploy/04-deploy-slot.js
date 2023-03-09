const { network, ethers } = require("hardhat")
const {
    developmentChains,
    firstMultiplayer,
    secondMultiplayer,
    thirdMultiplayer,
    fourthMultiplayer,
    fifthMultiplayer,
    sixthMultiplayer,
    seventhMultiplayer,
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    const treasury = await ethers.getContract("Treasury")
    const USDC = await ethers.getContract("USDC")
    const args = [
        deployer,
        USDC.address,
        treasury.address,
        [10, 20, 30, 40, 50, 75, 100],
        [
            firstMultiplayer,
            secondMultiplayer,
            thirdMultiplayer,
            fourthMultiplayer,
            fifthMultiplayer,
            sixthMultiplayer,
            seventhMultiplayer,
        ],
        90,
    ]

    const Slot = await deploy("Slot", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(Slot.address, args)
        await verify(Slot.address, args)
    }
}

module.exports.tags = ["all", "Slot"]
