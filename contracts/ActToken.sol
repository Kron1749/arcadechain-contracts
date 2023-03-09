// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Act is ERC20 {

    constructor(uint256 initialSupply) ERC20("Arcade Chain Token", "ACT") {
        _mint(msg.sender, initialSupply);
    }
}
