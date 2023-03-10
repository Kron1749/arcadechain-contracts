// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    uint256 public s_maxSupply = 1000000 * 10 ** decimals();

    constructor() ERC20("Arcade Chain USDC", "USDC") {
        _mint(msg.sender, s_maxSupply);
    }
}
