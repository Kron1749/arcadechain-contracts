const { Contract } = require("ethers")
const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const IERC20 = require("../../artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json")
const {
    PERCENTAGE_OF_BURN,
    PERCENTAGE_OF_GOLDEN_TICKET,
    developmentChains,
} = require("../../helper-hardhat-config")
const helpers = require("@nomicfoundation/hardhat-network-helpers")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Treasury Test", function () {
          let usdc, impersonateSigner, act, treasury, operator, user1, user2, user3

          beforeEach(async function () {
              const address = "0xF37955134Dda37eaC7380f5eb42bce10796bD224"
              await helpers.impersonateAccount(address)
              impersonateSigner = await ethers.getSigner(address)
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              operator = accounts[1]
              user1 = accounts[2]
              user2 = accounts[3]
              user3 = accounts[4]
              usdc = new Contract(
                  "0xE097d6B3100777DC31B34dC2c58fB524C2e76921",
                  IERC20.abi,
                  impersonateSigner
              )
              await deployments.fixture(["all"])
              treasury = await ethers.getContract("Treasury")
              act = new Contract(
                  "0x9AE51260C3824ADc9DD9F02Bc4D6B9e5Eddeb406",
                  IERC20.abi,
                  impersonateSigner
              )
          })
          describe("Contructor", function () {
              it("Should set proper variables", async () => {
                  const adminFromTest = await treasury.getAdmin()
                  const actFromContract = await treasury.getActAddress()
                  const operatorFromTest = await treasury.getOperator()
                  const tokenAddressFromTest = await treasury.getTokenAddress()
                  const percentageOfBurnFromTest = await treasury.getPercentageOfBurn()
                  const percentageOfGoldenTicketFromTest =
                      await treasury.getPercentageOfGoldenTicket()
                  assert.equal(adminFromTest, deployer.address)
                  assert.equal(operatorFromTest, deployer.address)
                  assert.equal(tokenAddressFromTest, usdc.address)
                  assert.equal(actFromContract, act.address)
                  assert.equal(percentageOfBurnFromTest, PERCENTAGE_OF_BURN)
                  assert.equal(percentageOfGoldenTicketFromTest, PERCENTAGE_OF_GOLDEN_TICKET)
              })
          })
          describe("Set Functions", function () {
              describe("Set new Operator", function () {
                  it("Should proper set new operator", async () => {
                      await treasury.setOperator(user1.address)
                      const getOperator = await treasury.getOperator()
                      assert.equal(user1.address, getOperator)
                  })
                  it("Should not set new operator,if called not from admin", async () => {
                      const connectedToRandom = await treasury.connect(operator)
                      await expect(
                          connectedToRandom.setOperator(user1.address)
                      ).to.be.revertedWith("Treasury__NotAdmin")
                  })
              })
              describe("Set new Token", function () {
                  it("Should properly set new token", async () => {
                      const newToken = new Contract(
                          "0x9AE51260C3824ADc9DD9F02Bc4D6B9e5Eddeb406",
                          IERC20.abi,
                          impersonateSigner
                      )
                      await treasury.setToken(newToken.address)
                      const newTokenFromTreasury = await treasury.getTokenAddress()
                      assert.equal(newToken.address, newTokenFromTreasury)
                  })
                  it("Should not set if not admin or operator", async () => {
                      const newToken = new Contract(
                          "0x9AE51260C3824ADc9DD9F02Bc4D6B9e5Eddeb406",
                          IERC20.abi,
                          impersonateSigner
                      )
                      const connectedToRandom = await treasury.connect(user1)
                      await expect(
                          connectedToRandom.setToken(newToken.address)
                      ).to.be.revertedWith("Treasury__NotAdminOrOperator")
                  })
              })
              describe("Set Percentage Of Burn", function () {
                  it("Should proper set percentage", async () => {
                      const newPercentage = 15
                      await treasury.setPercentageOfBurn(newPercentage)
                      const newPercentageFromContract = await treasury.getPercentageOfBurn()
                      assert.equal(newPercentage.toString(), newPercentageFromContract.toString())
                  })
                  it("Should not set if not admin", async () => {
                      const connectedToRandom = await treasury.connect(user1)
                      await expect(connectedToRandom.setPercentageOfBurn(5)).to.be.revertedWith(
                          "Treasury__NotAdmin"
                      )
                  })
                  it("Shouldd not set if not proper percentage", async () => {
                      await expect(treasury.setPercentageOfBurn(105)).to.be.revertedWith(
                          "Treasury__PercentageCantBeMoreThanZero"
                      )
                  })
              })
              describe("Set Percentage Of Golden Ticket", function () {
                  it("Should proper set percentage", async () => {
                      const newPercentage = 15
                      await treasury.setPercentageOfGoldenTicket(newPercentage)
                      const newPercentageFromContract =
                          await treasury.getPercentageOfGoldenTicket()
                      assert.equal(newPercentage.toString(), newPercentageFromContract.toString())
                  })
              })
          })
          describe("Get Functions()", function () {
              it("Should get address of golden ticket", async () => {
                  await treasury.setGoldenTicketToAddress(user1.address)
                  const addr = await treasury.getGoldenTicket()
                  assert.equal(addr, user1.address)
              })
          })

          describe("Swap Tokens", function () {
              it("Should properly swap tokens", async () => {
                  await usdc.transfer(treasury.address, 100)
                  const amountToBuy = 10
                  const actBefore = await act.balanceOf(treasury.address)
                  const usdcBefore = await usdc.balanceOf(treasury.address)
                  await treasury.swapTokens(amountToBuy)
                  const actAfter = await act.balanceOf(treasury.address)
                  const usdcAfter = await usdc.balanceOf(treasury.address)
                  const diffUsdc = usdcBefore - usdcAfter
                  const diffAct = actAfter - actBefore
                  assert.equal(diffUsdc, amountToBuy)
                  assert.notEqual(diffAct, 0)
              })
          })
          describe("Burn", function () {
              it("Shouldn't burn if treasury don't have balance", async () => {
                  await expect(treasury.burn()).to.be.revertedWith(
                      "Treasury__TreasuryDontHaveEnoughTokens"
                  )
              })
              it("Should properly burn", async () => {
                  await usdc.transfer(treasury.address, 10000)
                  const amountToBurn = await treasury.getAmountToBurn()
                  const percentageOfBurn = await treasury.getPercentageOfBurn()
                  const calculatedAmountToBurn = (10000 * percentageOfBurn) / 100
                  assert.equal(amountToBurn, calculatedAmountToBurn)
                  const usdcBefore = await usdc.balanceOf(treasury.address)
                  await treasury.burn()
                  const actAfter = await act.balanceOf(treasury.address)
                  const usdcAfter = await usdc.balanceOf(treasury.address)
                  const diffUsdc = usdcBefore - usdcAfter
                  assert.equal(diffUsdc, amountToBurn)
                  assert.equal(actAfter, 0)
              })
          })
          describe("Golden Ticket", function () {
              it("Should propely transfer", async () => {
                  await usdc.transfer(treasury.address, 10000)
                  await treasury.setGoldenTicketToAddress(user1.address)
                  const amountOfUSDCBefore = await usdc.balanceOf(user1.address)
                  const amountOfGoldenTicket = await treasury.getAmountOfGoldenTicket()
                  const percentageOfGoldenTicket = await treasury.getPercentageOfGoldenTicket()
                  const calculatedAmountOfGoldenTicket = (10000 * percentageOfGoldenTicket) / 100
                  assert.equal(amountOfGoldenTicket, calculatedAmountOfGoldenTicket)
                  await treasury.goldenTicket()
                  const amountOfUSDCAfter = await usdc.balanceOf(user1.address)
                  const diff = amountOfUSDCAfter - amountOfUSDCBefore
                  assert.equal(diff.toString(), amountOfGoldenTicket.toString())
              })
          })
          describe("Withdraw all money", async () => {
              it("Should properly withdraw everything", async () => {
                  await usdc.transfer(treasury.address, 10000)
                  await act.transfer(treasury.address, 10000)
                  const balanceOfUSDCAdminBefore = await usdc.balanceOf(deployer.address)
                  await treasury.withdrawERC20(usdc.address, deployer.address)
                  const balanceOfUSDCAdminAfter = await usdc.balanceOf(deployer.address)
                  const balanceOfUSDCTreasuryAfter = await usdc.balanceOf(treasury.address)
                  const diffUSDC = balanceOfUSDCAdminAfter - balanceOfUSDCAdminBefore
                  assert.equal(diffUSDC, 10000)
                  assert.equal(balanceOfUSDCTreasuryAfter, 0)
              })
          })
          describe("Weekly calculations", function () {
              it("Should get revert if lengths not equal", async () => {
                  const _userWallets = [user1.address, user2.address]
                  const weights = [10, 15, 20]
                  await expect(
                      treasury.weeklyCalculation(_userWallets, weights)
                  ).to.be.revertedWith("Treasury__MustBeEqualLength")
              })
              it("Should properly calculate rewards for user", async () => {
                  await usdc.transfer(treasury.address, 10000)
                  await act.transfer(treasury.address, 10000)
                  await treasury.setGoldenTicketToAddress(user3.address)
                  const _userWallets = [operator.address, user1.address, user2.address]
                  const weights = [50, 30, 20]
                  const percentageOfBurn = await treasury.getPercentageOfBurn()
                  const calculatedAmountToBurn = (10000 * percentageOfBurn) / 100
                  const percentageOfGoldenTicket = await treasury.getPercentageOfGoldenTicket()
                  const calculatedAmountOfGoldenTicket = (10000 * percentageOfGoldenTicket) / 100
                  const amountLeftAfterBurnGoldenTicket =
                      10000 - calculatedAmountToBurn - calculatedAmountOfGoldenTicket
                  const calculatedAmountOfTokensUser1 =
                      (amountLeftAfterBurnGoldenTicket * weights[0]) / 10000
                  const calculatedAmountOfTokensUser2 =
                      (amountLeftAfterBurnGoldenTicket * weights[1]) / 10000
                  const calculatedAmountOfTokensUser3 =
                      (amountLeftAfterBurnGoldenTicket * weights[2]) / 10000
                  await treasury.weeklyCalculation(_userWallets, weights)
                  const balanceOfUser1 = await usdc.balanceOf(operator.address)
                  const balanceOfUser2 = await usdc.balanceOf(user1.address)
                  const balanceOfUser3 = await usdc.balanceOf(user2.address)
                  assert.equal(calculatedAmountOfTokensUser1.toString(), balanceOfUser1.toString())
                  assert.equal(calculatedAmountOfTokensUser2.toString(), balanceOfUser2.toString())
                  assert.equal(calculatedAmountOfTokensUser3.toString(), balanceOfUser3.toString())
              })
          })
      })
