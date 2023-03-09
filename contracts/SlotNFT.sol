// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/Ownable.sol";
import "./abstract/Pausable.sol";
import "./abstract/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";


contract SlotNFT is Ownable, Pausable, ReentrancyGuard, ERC1155Holder {

    address public adminAddress; // address of the admin
    address public operatorAddress; // address of the operator
    address public gameToken; // you can pay with this token only
    address public nftTokenAddress;
    uint256 public gameFee;
    mapping(uint256 => RoundInfo) public ledger; // key on roundId
    mapping(address => uint256[]) public userRounds; // value is roundId
    mapping(address => uint256) public userWinnings; // value is balance
    uint8[] public brackets;
    uint256[] public winnings;
    uint8 public threshold;

    struct RoundInfo {
        address playerAddress;
        uint256 roundId;
        uint256 amount;
        bool updated; // default false
        bool claimed; // default false
    }

    event NewOperatorAddress(address operator);
    event NewGameToken(address tokenAddress);
    event NewNftAddress(address nftTokenAddress);
    event GameFeeSet(uint256 gameFee);
    event GameEntered(uint256 roundId, address user, uint256 gameFee, uint8 bracket, uint256 amount);
    event ResultUpdated(uint256 roundId, uint256 amount, uint8 bracket);
    event TreasuryClaim(uint256 amount);
    event PlayerClaimed(address player, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Not admin");
        _;
    }

    modifier onlyAdminOrOperator() {
        require(msg.sender == adminAddress || msg.sender == operatorAddress, "Not operator/admin");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    constructor(
        address _adminAddress,
        address _operatorAddress,
        address _gameTokenAddress,
        address _nftTokenAddress,
        uint256 _gameFee
    ) {
        adminAddress = _adminAddress;
        operatorAddress = _operatorAddress;
        gameToken = _gameTokenAddress;
        operatorAddress = _nftTokenAddress;
        gameFee = _gameFee;
    }

    function setOperator(address _operatorAddress) external onlyAdmin {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;

        emit NewOperatorAddress(_operatorAddress);
    }

    function setNftTokenAddress(address _nftTokenAddress) external onlyAdmin {
        require(_nftTokenAddress != address(0), "Cannot be zero address");
        nftTokenAddress = _nftTokenAddress;

        emit NewNftAddress(_nftTokenAddress);
    }

    function setBrackets(uint8[] calldata _brackets) external onlyAdmin {
        brackets = _brackets;
    }

    function setWinnings(uint256[] calldata _winnings) external onlyAdmin {
        winnings = _winnings;
    }

    function setThreshold(uint8 _threshold) external onlyAdmin {
        threshold = _threshold;
    }

    function setGameFee(uint256 _gameFee) external onlyAdmin {
        require(_gameFee != 0, "Game cannot be free");
        gameFee = _gameFee;

        emit GameFeeSet(_gameFee);
    }

    function setGameToken(address tokenAddress) external onlyAdmin {
        require(tokenAddress != address(0), "Cannot be zero address");
        gameToken = tokenAddress;

        emit NewGameToken(tokenAddress);
    }

    function enterGame(uint256 _roundId) external whenNotPaused nonReentrant notContract {
        require(_roundId != 0, "missing RoundId");

        RoundInfo storage roundInfo = ledger[_roundId];
        if (roundInfo.playerAddress != address(0x0)) {
            revert("existing roundId");
        }

        bool success = IERC20(gameToken).transferFrom(msg.sender, address(this), gameFee);

        if (success) {
            roundInfo.playerAddress = msg.sender;
            roundInfo.amount = gameFee;
            roundInfo.roundId = _roundId;
            userRounds[msg.sender].push(_roundId);

            uint256[2] memory result = setRoundResult(_roundId);

            emit GameEntered(_roundId, msg.sender, gameFee, uint8(result[0]), result[1]);
        } else {
            revert("round was not paid for");
        }
    }

    function claim() external whenNotPaused nonReentrant notContract {
        uint256 claimValue = userWinnings[msg.sender];
        if (claimValue == 0) {
            revert("nothing to claim");
        }

        userWinnings[msg.sender] = 0;
        for (uint256 i = 0; i < userRounds[msg.sender].length; i++) {
            uint256 round = userRounds[msg.sender][i];
            RoundInfo storage legerRound = ledger[round];
            if (legerRound.updated && !legerRound.claimed) {

                legerRound.claimed = true;
            }
        }

        IERC20(gameToken).transfer(msg.sender, claimValue);
        emit PlayerClaimed(msg.sender, claimValue);

    }

    function setRoundResult(uint256 _roundId) internal returns (uint256[2] memory) {
        if (ledger[_roundId].playerAddress == address(0x0)) {
            revert("not existing roundId");
        }

        uint256 amount = 0;
        uint8 bracket = 100;
        if (getPseudoRandom(_roundId + 1) <= threshold) {
            bracket = getBracketForRound(_roundId);
            amount = winnings[bracket];
        }
        RoundInfo storage roundInfo = ledger[_roundId];
        roundInfo.amount = amount;
        roundInfo.updated = true;
        userWinnings[roundInfo.playerAddress] = userWinnings[roundInfo.playerAddress] + amount;

        // todo: change to work off the random number
        if(true) {
            IERC1155(nftTokenAddress).safeTransferFrom(address(this), msg.sender, 2, 1, "0x0");
        }

        uint256[2] memory result = [bracket, amount];
        return result;
    }

    function getBracketForRound(uint256 _roundId) internal view returns (uint8) {
        uint8 randomNumber = getPseudoRandom(_roundId);
        for (uint8 i = 0; i < brackets.length; i++) {
            if (randomNumber <= brackets[i]) {
                return i;
            }
        }
        return 100;
    }

    function getPseudoRandom(uint256 _roundId) internal view returns (uint8) {
        uint8 number = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 100);
        return uint8(uint256(keccak256(abi.encodePacked(number + 1, _roundId))) % 100);
    }

    function claimTreasury(uint256 value) external nonReentrant onlyAdmin {
        IERC20(gameToken).transfer(adminAddress, value);

        emit TreasuryClaim(value);
    }

    function getUserWinnings(address _address) external view returns (uint256) {
        return userWinnings[_address];
    }

    function getUserRounds(address _address) external view returns (uint256[] memory) {
        return userRounds[_address];
    }

    function getLegerEntryForRoundId(uint256 _roundId) external view returns (RoundInfo memory) {
        return ledger[_roundId];
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
