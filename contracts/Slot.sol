// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/Ownable.sol";
import "./abstract/Pausable.sol";
import "./abstract/ReentrancyGuard.sol";
import "../libraries/ABDKMathQuad.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

error Slot__NotAdmin();
error Slot__NotOperatorOrAdmin();
error Slot__NotOperator();
error Slot__ContractNotAllowed();
error Slot__ProxyContractNotAllowed();
error Slot__CannotBeZeroAddress();
error Slot__GameCannotBeFree();
error Slot__MissingRoundId();
error Slot__ExistingRoundId();
error Slot__RoundWasNotPaidFor();
error Slot__NothingToClaim();
error Slot__NotExistingRoundId();

contract Slot is Ownable, Pausable, ReentrancyGuard {
    ///@notice struct for our round
    struct RoundInfo {
        address playerAddress;
        uint256 roundId;
        uint256 amount;
        bool updated;
        bool claimed;
    }

    event NewOperatorAddress(address operator);
    event NewGameToken(address tokenAddress);
    event GameFeeSet(uint256 gameFee);
    event GameEntered(
        uint256 roundId,
        address user,
        uint256 gameFee,
        uint8 bracket,
        uint256 amount
    );
    event ResultUpdated(uint256 roundId, uint256 amount, uint8 bracket);
    event TreasuryClaim(uint256 amount);
    event PlayerClaimed(address player, uint256 amount);

    ///@notice address of admin
    address private s_adminAddress;

    ///@notice this is address of USDC on Mumbai
    address private s_gameToken;

    ///@notice address of treasury
    address private s_treasury;

    ///@notice mapping of rounds
    mapping(uint256 => RoundInfo) public s_ledger;

    ///@notice value is roundId
    mapping(address => uint256[]) public s_userRounds;

    ///@notice mapping of user winnings
    mapping(address => uint256) public s_userWinnings; // value is balance
    uint8[] public s_brackets;

    ///@notice array of winnings
    bytes16[] public s_multiplayers;
    uint8 public s_threshold;

    ///@notice only admin
    modifier onlyAdmin() {
        if (msg.sender != s_adminAddress) {
            revert Slot__NotAdmin();
        }
        _;
    }

    ///@notice check for this is not a contract
    modifier notContract() {
        if (_isContract(msg.sender)) {
            revert Slot__ContractNotAllowed();
        }
        if (msg.sender != tx.origin) {
            revert Slot__ProxyContractNotAllowed();
        }
        _;
    }

    constructor(
        address _adminAddress,
        address _gameToken,
        address _treasury,
        uint8[] memory _brackets,
        bytes16[] memory _multiplayers,
        uint8 _threshold
    ) {
        s_adminAddress = _adminAddress;
        s_gameToken = _gameToken;
        s_treasury = _treasury;
        s_brackets = _brackets;
        s_multiplayers = _multiplayers;
        s_threshold = _threshold;
    }

    ///@notice function to enter the round
    function enterGame(
        uint256 _roundId,
        uint256 _amount
    ) external whenNotPaused nonReentrant notContract {
        if (_roundId == 0) {
            revert Slot__MissingRoundId();
        }

        RoundInfo storage roundInfo = s_ledger[_roundId];
        if (roundInfo.playerAddress != address(0x0)) {
            revert Slot__ExistingRoundId();
        }

        IERC20(s_gameToken).approve(address(this), _amount);
        bool success = IERC20(s_gameToken).transferFrom(msg.sender, address(this), _amount);

        if (success) {
            roundInfo.playerAddress = msg.sender;
            roundInfo.amount = _amount;
            roundInfo.roundId = _roundId;
            s_userRounds[msg.sender].push(_roundId);

            uint256[2] memory result = setRoundResult(_roundId, _amount);

            emit GameEntered(_roundId, msg.sender, _amount, uint8(result[0]), result[1]);
        } else {
            revert Slot__RoundWasNotPaidFor();
        }
    }

    ///@notice claim prize
    function claim() external whenNotPaused nonReentrant notContract {
        uint256 claimValue = s_userWinnings[msg.sender];
        if (claimValue == 0) {
            revert Slot__NothingToClaim();
        }

        s_userWinnings[msg.sender] = 0;
        for (uint256 i = 0; i < s_userRounds[msg.sender].length; i++) {
            uint256 round = s_userRounds[msg.sender][i];
            RoundInfo storage legerRound = s_ledger[round];
            if (legerRound.updated && !legerRound.claimed) {
                legerRound.claimed = true;
            }
        }
        IERC20(s_gameToken).transfer(msg.sender, claimValue);
        emit PlayerClaimed(msg.sender, claimValue);
    }

    ///@notice transfer money to treasury
    function claimTreasury(uint256 value) external nonReentrant onlyAdmin {
        IERC20(s_gameToken).transfer(s_treasury, value);

        emit TreasuryClaim(value);
    }

    function getTreasuryAddr() public view returns (address) {
        return s_treasury;
    }

    function getAdminAddress() public view returns (address) {
        return s_adminAddress;
    }

    function getGameTokenAddress() public view returns (address) {
        return s_gameToken;
    }

    function getMultiplayer(uint8 number) public view returns (bytes16) {
        return s_multiplayers[number];
    }

    function getBracketForRound(uint256 _roundId) public view returns (uint8) {
        uint8 randomNumber = getPseudoRandom(_roundId);
        for (uint8 i = 0; i < s_brackets.length; i++) {
            if (randomNumber <= s_brackets[i]) {
                return i;
            }
        }
    }

    ///@notice get pseudo random number
    function getPseudoRandom(uint256 _roundId) internal view returns (uint8) {
        uint8 number = uint8(
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 100
        );
        return uint8(uint256(keccak256(abi.encodePacked(number + 1, _roundId))) % 100);
    }

    ///@notice check if it is a contract
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    ///@notice set results for round
    function setRoundResult(
        uint256 _roundId,
        uint256 _amount
    ) internal returns (uint256[2] memory) {
        bytes16 multiplayer = 0x00000000000000000000000000000000;
        uint8 bracket = 100;
        if (getPseudoRandom(_roundId + 1) <= s_threshold) {
            bracket = getBracketForRound(_roundId);
            multiplayer = s_multiplayers[bracket];
        }
        uint256 amount = getAmountWithMultiplayer(_amount, multiplayer);
        RoundInfo storage roundInfo = s_ledger[_roundId];
        roundInfo.amount = amount;
        roundInfo.updated = true;
        s_userWinnings[roundInfo.playerAddress] = s_userWinnings[roundInfo.playerAddress] + amount;

        uint256[2] memory result = [bracket, amount];
        return result;
    }

    ///@notice calculate amount with multiplayer
    function getAmountWithMultiplayer(
        uint256 _amount,
        bytes16 _multiplayer
    ) public pure returns (uint256) {
        bytes16 amount = ABDKMathQuad.fromUInt(_amount);
        bytes16 resultOfMul = ABDKMathQuad.mul(amount, _multiplayer);
        return ABDKMathQuad.toUInt(resultOfMul);
    }

    ///@notice set new threshold
    function setThreshold(uint8 _threshold) external onlyAdmin {
        s_threshold = _threshold;
    }

    ///@notice set new multiplayers
    function setMultiplayers(bytes16[] memory _multiplayers) external onlyAdmin {
        s_multiplayers = _multiplayers;
    }

    ///@notice withdraw exact token from slot
    function withdrawERC20(
        address _tokenAddressToWithdraw,
        address _destination
    ) external onlyAdmin {
        uint256 totalBalance = IERC20(_tokenAddressToWithdraw).balanceOf(address(this));
        IERC20(_tokenAddressToWithdraw).transfer(address(_destination), totalBalance);
    }
}
