// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./abstract/Ownable.sol";
import "./abstract/Pausable.sol";
import "./abstract/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

error Lottery__NotAdmin();
error Lottery__ContractNotAllowed();
error Lottery__ProxyContractNotAllowed();
error Lottery__CantEnterGameWhenLotteryIsNotOpen();
error Lottery__CantEnterGameIfAmountOfNumbersIsNotSix();
error Lottery__CantEnterGameIfNumberIsNotZeroOrOne();
error Lottery__isNotCalculating();

contract Lottery is
    Ownable,
    Pausable,
    ReentrancyGuard,
    VRFConsumerBaseV2,
    KeeperCompatibleInterface
{
    ///@notice for lottery
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    struct RoundInfo {
        address[] playersAddresses;
        address[] sixNumbersWinners;
        address[] fiveNumbersWinners;
        address[] fourNumbersWinners;
        address[] threeNumbersWinners;
        address[] twoNumbersWinners;
        address[] oneNumbersWinners;
        uint256 allocationForSixNumberWinners;
        uint256 allocationForFiveNumberWinners;
        uint256 allocationForFourNumberWinners;
        uint256 allocationForThreeNumberWinners;
        uint256 allocationForTwoNumberWinners;
        uint256 allocationForOneNumberWinners;
        mapping(address => uint256) allocations;
        mapping(address => uint256) winnings;
        mapping(address => uint256[]) userNumbers;
        uint256[] vrfRandomNumbers;
        uint256 round_requestId;
    }

    //Chainlink Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_gasLane;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 6;

    //Lottery variables

    ///@notice address of admin
    address private s_adminAddress;

    ///@notice this is address of USDC on Mumbai
    address private s_gameToken;

    uint256 private randomWord;
    uint256[] public arr_r;

    ///@notice How often we need to do lottery,every 60 seconds
    uint256 private immutable i_interval;

    ///@notice last time
    uint256 private s_lastTimeStamp;

    ///@notice lottery fee
    uint256 public s_lotteryFee;

    ///@notice current lottery state
    RaffleState private s_lotteryState;

    ///@notice address of treasury
    address private s_treasury;

    ///@notice initial array of allocations in percentages
    uint256[] public s_allocations;

    ///@notice this is the current roundId
    uint256 public s_currentRoundId = 0;

    ///@notice mapping of all rounds
    mapping(uint256 => RoundInfo) public s_rounds;

    constructor(
        address _vrfCoordinatorV2,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        bytes32 _gasLane,
        uint256 _interval,
        address _gameToken,
        uint256[] memory _allocations,
        address _treasury,
        address _admin,
        uint256 _fee
    ) VRFConsumerBaseV2(_vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorV2);
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        i_gasLane = _gasLane;
        i_interval = _interval;
        s_gameToken = _gameToken;
        s_allocations = _allocations;
        s_treasury = _treasury;
        s_adminAddress = _admin;
        s_lotteryFee = _fee;
    }

    ///@notice only admin
    modifier onlyAdmin() {
        if (msg.sender != s_adminAddress) {
            revert Lottery__NotAdmin();
        }
        _;
    }

    ///@notice check if lottery is calculating now
    modifier lotteryIsCalculating() {
        bool lotteryState = RaffleState.CALCULATING == s_lotteryState;
        if (!lotteryState) {
            revert Lottery__isNotCalculating();
        }
        _;
    }

    ///@notice check for this is not a contract
    modifier notContract() {
        if (_isContract(msg.sender)) {
            revert Lottery__ContractNotAllowed();
        }
        if (msg.sender != tx.origin) {
            revert Lottery__ProxyContractNotAllowed();
        }
        _;
    }

    ///@notice check if it is a contract
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hass_Players = s_rounds[s_currentRoundId].playersAddresses.length > 0;
        bool lotteryState = RaffleState.OPEN == s_lotteryState;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && hass_Players && lotteryState && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_rounds[s_currentRoundId].round_requestId = requestId;
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_rounds[s_currentRoundId].vrfRandomNumbers = randomWords;
        updateRandomWords(s_currentRoundId);
    }

    function updateRandomWords(uint256 requestId) internal {
        for (uint8 i = 0; i < s_rounds[requestId].vrfRandomNumbers.length; i++) {
            s_rounds[requestId].vrfRandomNumbers[i] =
                (s_rounds[requestId].vrfRandomNumbers[i] % 10) -
                1;
            s_rounds[requestId].vrfRandomNumbers[i] = s_rounds[requestId].vrfRandomNumbers[i] < 5
                ? 0
                : 1;
        }
        calculateAndDistributeWinnings(requestId);
    }

    ///@notice function to enter game with users numbers
    function enterGameWithUserNumbers(
        uint256[] memory _numbers
    ) external whenNotPaused nonReentrant notContract {
        if (_numbers.length != 6) {
            revert Lottery__CantEnterGameIfAmountOfNumbersIsNotSix();
        }
        for (uint8 i = 0; i < 6; i++) {
            if (_numbers[i] > 1) {
                revert Lottery__CantEnterGameIfNumberIsNotZeroOrOne();
            }
        }
        bool lotteryState = RaffleState.OPEN == s_lotteryState;
        if (!lotteryState) {
            revert Lottery__CantEnterGameWhenLotteryIsNotOpen();
        }
        uint256 feeToTransfer = s_lotteryFee / 20;
        IERC20(s_gameToken).transfer(s_treasury, feeToTransfer);
        s_rounds[s_currentRoundId].playersAddresses.push(msg.sender);
        s_rounds[s_currentRoundId].userNumbers[msg.sender] = _numbers;
        IERC20(s_gameToken).transfer(address(this), s_lotteryFee);
    }

    ///@notice calculate winnings for users
    function calculateAndDistributeWinnings(uint256 roundId) public lotteryIsCalculating {
        calculateWinningNumbers(roundId);
        calculateAllocations(roundId);
        transferWinningsToUsers(roundId);
    }

    function calculateWinningNumbers(uint256 roundId) private lotteryIsCalculating {
        address[] memory users = s_rounds[roundId].playersAddresses;
        uint256[] memory vrfNumbers = s_rounds[roundId].vrfRandomNumbers;
        for (uint256 i = 0; i < users.length; i++) {
            uint256[] memory userNumbers = s_rounds[roundId].userNumbers[users[i]];
            if (
                userNumbers[0] == vrfNumbers[0] &&
                userNumbers[1] == vrfNumbers[1] &&
                userNumbers[2] == vrfNumbers[2] &&
                userNumbers[3] == vrfNumbers[3] &&
                userNumbers[4] == vrfNumbers[4] &&
                userNumbers[5] == vrfNumbers[5]
            ) {
                s_rounds[roundId].sixNumbersWinners.push(users[i]);
            }
            if (
                userNumbers[0] == vrfNumbers[0] &&
                userNumbers[1] == vrfNumbers[1] &&
                userNumbers[2] == vrfNumbers[2] &&
                userNumbers[3] == vrfNumbers[3] &&
                userNumbers[4] == vrfNumbers[4]
            ) {
                s_rounds[roundId].fiveNumbersWinners.push(users[i]);
            }

            if (
                userNumbers[0] == vrfNumbers[0] &&
                userNumbers[1] == vrfNumbers[1] &&
                userNumbers[2] == vrfNumbers[2] &&
                userNumbers[3] == vrfNumbers[3]
            ) {
                s_rounds[roundId].fourNumbersWinners.push(users[i]);
            }

            if (
                userNumbers[0] == vrfNumbers[0] &&
                userNumbers[1] == vrfNumbers[1] &&
                userNumbers[2] == vrfNumbers[2]
            ) {
                s_rounds[roundId].threeNumbersWinners.push(users[i]);
            }

            if (userNumbers[0] == vrfNumbers[0] && userNumbers[1] == vrfNumbers[1]) {
                s_rounds[roundId].twoNumbersWinners.push(users[i]);
            }
            if (userNumbers[0] == vrfNumbers[0] && userNumbers[1] == vrfNumbers[1]) {
                s_rounds[roundId].oneNumbersWinners.push(users[i]);
            }
        }
    }

    function calculateAllocations(uint256 roundId) private lotteryIsCalculating {
        uint256[6] memory numbersOfnNumbersWinners = [
            s_rounds[roundId].sixNumbersWinners.length,
            s_rounds[roundId].fiveNumbersWinners.length,
            s_rounds[roundId].fourNumbersWinners.length,
            s_rounds[roundId].threeNumbersWinners.length,
            s_rounds[roundId].twoNumbersWinners.length,
            s_rounds[roundId].oneNumbersWinners.length
        ];
        uint256[6] memory allocations;

        uint256 freeAllocation = 0;
        for (uint8 i = 5; i <= 0; i--) {
            if (numbersOfnNumbersWinners[i] == 0) {
                freeAllocation += s_allocations[i];
                allocations[i] = 0;
            } else {
                allocations[i] = s_allocations[i] + freeAllocation;
                freeAllocation = 0;
            }
        }
        s_rounds[roundId].allocationForSixNumberWinners = allocations[0];
        s_rounds[roundId].allocationForFiveNumberWinners = allocations[1];
        s_rounds[roundId].allocationForFourNumberWinners = allocations[2];
        s_rounds[roundId].allocationForThreeNumberWinners = allocations[3];
        s_rounds[roundId].allocationForTwoNumberWinners = allocations[4];
        s_rounds[roundId].allocationForOneNumberWinners = allocations[5];
    }

    ///@notice function for to transfer winnings to user
    function transferWinningsToUsers(
        uint256 roundId
    ) private whenNotPaused nonReentrant notContract lotteryIsCalculating {
        //TODO calculate allocation for one user
        //TODO check if no one wins
        updateCurrentRound();
    }

    ///@notice this function will update current round
    function updateCurrentRound() internal whenNotPaused nonReentrant notContract {
        s_currentRoundId++;
    }

    ///@notice transfer money to treasury
    function claimTreasury(uint256 value) external nonReentrant onlyAdmin {
        IERC20(s_gameToken).transfer(s_treasury, value);
    }

    ///@notice withdraw all money from lottery
    function withdrawAllMoney() external onlyAdmin {
        uint256 totalBalance = IERC20(s_gameToken).balanceOf(address(this));
        IERC20(s_gameToken).transfer(msg.sender, totalBalance);
    }

    function getVrfCoordinatorAddress() public view returns (address) {
        return address(i_vrfCoordinator);
    }

    function getSubscriptionId() public view returns (uint64) {
        return i_subscriptionId;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getGasLane() public view returns (bytes32) {
        return i_gasLane;
    }

    function getAdminAddress() public view returns (address) {
        return s_adminAddress;
    }

    function getGameToken() public view returns (address) {
        return s_gameToken;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getTreasuryAddress() public view returns (address) {
        return s_treasury;
    }

    function getRequestId(uint256 requestId) public view returns (uint256) {
        return s_rounds[requestId].round_requestId;
    }

    function getRequestVRFWord(uint256 requestId) public view returns (uint256[] memory) {
        RoundInfo storage request = s_rounds[requestId];
        return request.vrfRandomNumbers;
    }
}
