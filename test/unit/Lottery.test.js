const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Lottery Test", function () {
          let deployer,
              lottery,
              usdc,
              treasury,
              accounts,
              VRFCoordinatorV2Mock,
              lotteryEntranceFee,
              interval,
              player,
              chainId,
              callback,
              gasLane
          beforeEach(async function () {
              await deployments.fixture(["all"])
              chainId = network.config.chainId
              lotteryEntranceFee = networkConfig[chainId]["raffleEntranceFee"]
              callback = networkConfig[chainId]["callbackGasLimit"]
              gasLane = networkConfig[chainId]["gasLane"]
              interval = networkConfig[chainId]["keepersUpdateInterval"]
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              player = accounts[1]
              VRFCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
              lottery = await ethers.getContract("Lottery") // Will get the recent deployment
              usdc = await ethers.getContract("USDC")
              treasury = await ethers.getContract("Treasury")
          })
          describe("Constructor", function () {
              it("Should properly initialize values", async function () {
                  const vrfAddressFromContract = await lottery.getVrfCoordinatorAddress()
                  const subIdContract = await lottery.getSubscriptionId()
                  const callbackGasLimitContract = await lottery.getCallbackGasLimit()
                  const gasLaneContract = await lottery.getGasLane()
                  const adminAddressContract = await lottery.getAdminAddress()
                  const gameTokenContract = await lottery.getGameToken()
                  const intervalContract = await lottery.getInterval()
                  const treasuryAddrContract = await lottery.getTreasuryAddress()
                  const feeContract = await lottery.s_lotteryFee()
                  assert.equal(vrfAddressFromContract, VRFCoordinatorV2Mock.address)
                  assert.equal(subIdContract.toString(), 1)
                  assert.equal(callbackGasLimitContract, callback)
                  assert.equal(gasLaneContract, gasLane)
                  assert.equal(adminAddressContract, deployer.address)
                  assert.equal(gameTokenContract, usdc.address)
                  assert.equal(intervalContract, interval)
                  assert.equal(treasuryAddrContract, treasury.address)
                  assert.equal(feeContract.toString(), lotteryEntranceFee.toString())
              })
          })
          describe("Enter game with user numbers", function () {})
          describe("Perform Upkeep", function () {
              it("Should properly write request id to rounds", async () => {
                  const tx = await lottery.performUpkeep("0x")
                  await tx.wait(1)
                  const id = await lottery.getRequestId(0)
                  console.log(id)
                  const randomWORd = await lottery.getRandomWord(1)
                  console.log(randomWORd)
                  const word = await lottery.getRequestVRFWord(0)
                  console.log(word)
              })
          })
          describe("Check Up keep", function () {})
          describe("Full fill words", function () {})
          describe("Calculate Winning Numbers", function () {})
          describe("Calculate Allocations", function () {})
      })
