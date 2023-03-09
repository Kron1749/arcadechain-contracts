const { network } = require("hardhat")
const {
    developmentChains,
    PERCENTAGE_OF_BURN,
    PERCENTAGE_OF_GOLDEN_TICKET,
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    const act = "0x9AE51260C3824ADc9DD9F02Bc4D6B9e5Eddeb406"
    const args = [
        deployer,
        deployer,
        act,
        PERCENTAGE_OF_BURN,
        PERCENTAGE_OF_GOLDEN_TICKET,
    ]

    const Treasury = await deploy("Treasury", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(Treasury.address, args)
        await verify(Treasury.address, args)
    }
}

module.exports.tags = ["all", "Treasury"]
