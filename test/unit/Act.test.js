const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name) ? describe.skip : describe("Act Test", function () {

    let deployer,act
    beforeEach(async function(){
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["all"])
        act = await ethers.getContract("Act")
    })
    describe("Constructor",function(){
        it("Should properly initialize values",async function(){
            const supply = await act.totalSupply()
            const name = await act.name()
            const symbol = await act.symbol()
            assert.equal(supply,10000000)
            assert.equal(name.toString(),"Arcade Chain Token")
            assert.equal(symbol.toString(),"ACT")
        })
    })
})
