// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/Ownable.sol";
import "./abstract/Pausable.sol";
import "./abstract/ReentrancyGuard.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

error Treasury__NotAdmin();
error Treasury__NotOperator();
error Treasury__NotAdminOrOperator();
error Treasury__AddressCantBeZero();
error Treasury__PercentageCantBeMoreThanZero();
error Treasury__MustBeEqualLength();
error Treasury__PeriodCantBeMoreThanMaxPeriod();
error Treasury__TreasuryDontHaveEnoughTokens();
error Treasury__YouCantWithdrawIfYouAreNotOwner();

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract Treasury is Ownable, Pausable, ReentrancyGuard {
    ISwapRouter private swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    ///@notice immutable because we want to set it just once
    address private immutable i_admin;
    address private s_operator;

    ///@notice token in which we store our balance,
    IERC20 private s_token;

    ///@notice our act token
    IERC20 private immutable i_actToken;

    ///@notice percentage of tokens we want to burn with burn() function
    uint8 private s_percentageOfBurn;

    ///@notice percantage of tokens that owner of golden ticket will have
    uint8 private s_percentageOfGoldenTicket;

    ///@notice address of user that own golden ticket
    address private s_goldenTicket;

    ///@dev using revert,because it's more gas efficient
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Treasury__NotAdmin();
        }
        _;
    }

    modifier onlyAdminOrOperator() {
        if (msg.sender != i_admin && msg.sender != s_operator) {
            revert Treasury__NotAdminOrOperator();
        }
        _;
    }

    ///@notice modifier for checking if address is not zero
    modifier notZeroAddress(address _address) {
        if (_address == address(0)) {
            revert Treasury__AddressCantBeZero();
        }
        _;
    }

    ///@notice modifier for checking if percentage is okay
    modifier properPercentage(uint8 percentage) {
        if (percentage > 100) {
            revert Treasury__PercentageCantBeMoreThanZero();
        }
        _;
    }

    ///@notice checking if we have enough balance
    modifier treasuryHaveBalance(uint256 _amount) {
        if (_amount > s_token.balanceOf(address(this)) || _amount == 0) {
            revert Treasury__TreasuryDontHaveEnoughTokens();
        }
        _;
    }

    constructor(
        address _adminAddress,
        address _operator,
        address _act,
        uint8 _percentageOfBurn,
        uint8 _percentageOfGoldenTicket
    ) {
        i_admin = _adminAddress;
        s_operator = _operator;
        s_token = IERC20(0xE097d6B3100777DC31B34dC2c58fB524C2e76921);
        i_actToken = IERC20(_act);
        s_percentageOfBurn = _percentageOfBurn;
        s_percentageOfGoldenTicket = _percentageOfGoldenTicket;
    }

    ///@notice this function calculate amount of tokens user could withdraw for current week
    ///@param _weights the array of weights in percent passed from backend the 100 %=10000
    ///@param _usersWallets the array of users that own ACT token,passed from backend
    function weeklyCalculation(
        address[] memory _usersWallets,
        uint256[] memory _weights
    ) external {
        if (_usersWallets.length != _weights.length) {
            revert Treasury__MustBeEqualLength();
        }
        burn();
        goldenTicket();

        //Getting how much TUSD(for example) does the contract have
        uint256 balanceAfterAllExecutions = getCurrentAmountOfTokens();

        //Updating all our maps
        for (uint256 i = 0; i < _usersWallets.length; i++) {
            //Calculating how much tokens users will be able to withdraw

            //Dividing by 10000 because 100% is 10000
            uint256 userTokensToWithdraw = (balanceAfterAllExecutions * _weights[i]) / 10000;

            //Here we withdrawing money to the users
            s_token.approve(_usersWallets[i], userTokensToWithdraw);
            s_token.transfer(_usersWallets[i], userTokensToWithdraw);
        }
    }

    ///@notice setting new operator,this could do only admin
    function setOperator(address _operator) external onlyAdmin notZeroAddress(_operator) {
        s_operator = _operator;
    }

    ///@notice setting new token,like BUSD
    function setToken(address _token) external onlyAdminOrOperator notZeroAddress(_token) {
        s_token = IERC20(_token);
    }

    ///@notice setting new percentage for burn
    function setPercentageOfBurn(
        uint8 _percentage
    ) external onlyAdmin properPercentage(_percentage) {
        s_percentageOfBurn = _percentage;
    }

    ///@notice setting new percentage for golden ticket
    function setPercentageOfGoldenTicket(
        uint8 _percentage
    ) external onlyAdmin properPercentage(_percentage) {
        s_percentageOfGoldenTicket = _percentage;
    }

    ///@notice we should get it from backend
    function setGoldenTicketToAddress(address _userWallet) external onlyAdmin {
        s_goldenTicket = _userWallet;
    }

    ///@notice this function use our stable(s_token) to buy ACT and then burn it every period
    ///@notice not sure do we need treasuryHaveBalance modifier
    function burn() public onlyAdmin treasuryHaveBalance(getAmountToBurn()) {
        uint256 amountToBuy = getAmountToBurn();
        uint256 amountToBurn = swapTokens(amountToBuy);
        i_actToken.transfer(0x000000000000000000000000000000000000dEaD, amountToBurn);
    }

    ///@notice this function will automatically swap from aUSDC to ATC
    function swapTokens(uint256 amountIn) public returns (uint256 amountOut) {
        s_token.approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(s_token),
            tokenOut: address(i_actToken),
            fee: 10000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        return swapRouter.exactInputSingle(params);
    }

    ///@notice this function trasnfer tokens to the owner of golden ticket of this period
    ///@notice not sure do we really need treasuryHaveBalance modifier
    function goldenTicket() public onlyAdmin treasuryHaveBalance(getAmountOfGoldenTicket()) {
        uint256 amountToWithdraw = getAmountOfGoldenTicket();
        s_token.transfer(s_goldenTicket, amountToWithdraw);
    }

    function getAdmin() public view returns (address) {
        return i_admin;
    }

    function getOperator() public view returns (address) {
        return s_operator;
    }

    function getTokenAddress() public view returns (address) {
        return address(s_token);
    }

    function getActAddress() public view returns (address) {
        return address(i_actToken);
    }

    function getPercentageOfBurn() public view returns (uint8) {
        return s_percentageOfBurn;
    }

    function getPercentageOfGoldenTicket() public view returns (uint8) {
        return s_percentageOfGoldenTicket;
    }

    function getCurrentAmountOfTokens() public view returns (uint256) {
        return s_token.balanceOf(address(this));
    }

    ///@notice get address of owner of golden ticket for define period
    function getGoldenTicket() public view returns (address) {
        return s_goldenTicket;
    }

    ///@notice get how much tokens we want to burn
    function getAmountToBurn() public view returns (uint256) {
        uint256 currnetBalance = getCurrentAmountOfTokens();
        uint256 percentToBurn = getPercentageOfBurn();
        uint256 amountToBurn = (currnetBalance * percentToBurn) / 100;
        return amountToBurn;
    }

    ///@notice get hou much tokens owner of golden ticket will get
    function getAmountOfGoldenTicket() public view returns (uint256) {
        uint256 currentBalance = getCurrentAmountOfTokens();
        uint256 percentOfGoldenTicket = getPercentageOfGoldenTicket();
        uint256 amountOfGoldenTicket = (currentBalance * percentOfGoldenTicket) / 100;
        return amountOfGoldenTicket;
    }

    ///@notice withdraw exact token from treasury
    function withdrawERC20(
        address _tokenAddressToWithdraw,
        address _destination
    ) external onlyAdmin {
        uint256 totalBalance = IERC20(_tokenAddressToWithdraw).balanceOf(address(this));
        IERC20(_tokenAddressToWithdraw).transfer(address(_destination), totalBalance);
    }
}
