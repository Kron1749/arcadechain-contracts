const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const BN = require("bn.js")
const { Contract } = require("ethers")
const {
    developmentChains,
    firstMultiplayer,
    secondMultiplayer,
    thirdMultiplayer,
    fourthMultiplayer,
    fifthMultiplayer,
    sixthMultiplayer,
    seventhMultiplayer,
} = require("../../helper-hardhat-config")
const helpers = require("@nomicfoundation/hardhat-network-helpers")
const IERC20 = require("../../artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Slot Test", function () {
          let deployer, operator, treasury, gamefee, slot, usdc
          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              operator = accounts[1]
              gamefee = 1
              await deployments.fixture(["all"])
              slot = await ethers.getContract("Slot")
              treasury = await ethers.getContract("Treasury")
              usdc = await ethers.getContract("USDC")
          })
          describe("Constructor", function () {
              it("Should properly initialize values", async function () {
                  const adminAddress = await slot.getAdminAddress()
                  const treasuryAddress = await slot.getTreasuryAddr()
                  assert.equal(adminAddress, deployer.address)
                  assert.equal(treasuryAddress, treasury.address)
              })
          })
          describe("Set values", function () {
              it("Should set threshold", async () => {
                  await slot.setThreshold(8)
                  const newThreshold = await slot.s_threshold()
                  assert.equal(newThreshold, 8)
              })
              it("Should not set new thresold if not admin", async () => {
                  const connectedRandom = await slot.connect(operator)
                  await expect(connectedRandom.setThreshold(2)).to.be.revertedWith(
                      "Slot__NotAdmin"
                  )
              })
              it("Should set new multiplayers", async () => {
                  await slot.setMultiplayers([secondMultiplayer])
                  const multiplayerFromSlot = await slot.getMultiplayer(0)
                  assert.equal(secondMultiplayer.toString(), multiplayerFromSlot.toString())
              })
          })
          describe("Get values", function () {
              it("Get Bracket", async () => {
                  const bracketForRound0 = await slot.getBracketForRound(0)
                  assert.notEqual(bracketForRound0, null)
              })
              it("Get game token address", async () => {
                  const tokenAddress = await slot.getGameTokenAddress()
                  assert.equal(tokenAddress, usdc.address)
              })
          })

          describe("Enter Game", function () {
              it("Should not enter if roundId==0", async () => {
                  await expect(slot.enterGame(0, 100)).to.be.revertedWith("Slot__MissingRoundId")
              })
              it("Should not enter if round existing", async () => {
                  await usdc.approve(slot.address, 10000)
                  await slot.enterGame(1, 10)
                  await expect(slot.enterGame(1, 10)).to.be.revertedWith("Slot__ExistingRoundId")
              })
              it("Should properly enter game", async () => {
                  await usdc.approve(slot.address, 100)
                  await slot.enterGame(1, 100)
                  const roundInfo = await slot.s_ledger(1)
                  const user = roundInfo.playerAddress.toString()
                  const roundId = roundInfo.roundId.toString()
                  const amount = roundInfo.amount.toString()
                  assert.equal(user, deployer.address)
                  assert.equal(roundId, 1)
                  assert.notEqual(amount, null)
              })
          })
          describe("Claim", function () {
              it("It shouldn't claim if value is 0", async () => {
                  await expect(slot.claim()).to.be.revertedWith("Slot__NothingToClaim")
              })
              it("Should properly claim value", async () => {
                  await usdc.approve(slot.address, 10000000)
                  await usdc.transfer(slot.address, 100000)
                  await slot.enterGame(1, 10)

                  const winningBeforeClaiming = await slot.s_userWinnings(deployer.address)
                  if (winningBeforeClaiming != 0) {
                      await slot.claim()
                      const winningAfterClaiming = await slot.s_userWinnings(deployer.address)
                      const roundInfo = await slot.s_ledger(1)
                      const claimed = roundInfo.claimed.toString()
                      assert.equal(winningAfterClaiming, 0)
                      assert.equal(claimed, true.toString())
                  }
                  await expect(slot.claim()).to.be.revertedWith("Slot__NothingToClaim")
              })
          })
          describe("Claim Treasury", function () {
              it("Should claim treasury", async () => {
                  await usdc.transfer(slot.address, 8000)
                  const toClaim = 4000
                  const balanceBeforeClaimingSlot = await usdc.balanceOf(slot.address)
                  await expect(slot.claimTreasury(toClaim)).to.emit(slot, "TreasuryClaim")
                  const balanceAfterClaimingSlot = await usdc.balanceOf(slot.address)
                  const diff = balanceBeforeClaimingSlot - balanceAfterClaimingSlot
                  assert.equal(diff, toClaim)
              })
          })
          describe("Other", function () {
              it("Should withdraw all money", async () => {
                  await usdc.transfer(slot.address, 8000)
                  await slot.withdrawERC20(usdc.address, deployer.address)
                  const balanceAfter = await usdc.balanceOf(slot.address)
                  assert.equal(balanceAfter, 0)
              })
              it("Should propely get amount with multiplayers", async () => {
                  const amount = 280
                  const AmountCalculated = amount * 2.5
                  const AmountCalculated1 = amount * 2
                  const AmountCalculated2 = amount * 1.5
                  const AmountCalculated3 = amount * 1
                  const AmountCalculated4 = amount * 0.8
                  const AmountCalculated5 = amount * 0.5
                  const AmountCalculated6 = amount * 0.2

                  const ResultFromContract = await slot.getAmountWithMultiplayer(
                      amount,
                      firstMultiplayer
                  )
                  const ResultFromContract1 = await slot.getAmountWithMultiplayer(
                      amount,
                      secondMultiplayer
                  )
                  const ResultFromContract2 = await slot.getAmountWithMultiplayer(
                      amount,
                      thirdMultiplayer
                  )
                  const ResultFromContract3 = await slot.getAmountWithMultiplayer(
                      amount,
                      fourthMultiplayer
                  )
                  const ResultFromContract4 = await slot.getAmountWithMultiplayer(
                      amount,
                      fifthMultiplayer
                  )
                  const ResultFromContract5 = await slot.getAmountWithMultiplayer(
                      amount,
                      sixthMultiplayer
                  )
                  const ResultFromContract6 = await slot.getAmountWithMultiplayer(
                      amount,
                      seventhMultiplayer
                  )

                  assert.equal(AmountCalculated.toString(), ResultFromContract.toString())
                  assert.equal(AmountCalculated1.toString(), ResultFromContract1.toString())
                  assert.equal(AmountCalculated2.toString(), ResultFromContract2.toString())
                  assert.equal(AmountCalculated3.toString(), ResultFromContract3.toString())
                  assert.equal(AmountCalculated4.toString(), ResultFromContract4.toString())
                  assert.equal(AmountCalculated5.toString(), ResultFromContract5.toString())
                  assert.equal(AmountCalculated6.toString(), ResultFromContract6.toString())
              })
          })
      })
