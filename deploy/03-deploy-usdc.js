const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    const Act = await deploy("USDC", {
        from: deployer,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(Act.address, args)
        await verify(Act.address, args)
    }
}

module.exports.tags = ["all", "USDC"]
