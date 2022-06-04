//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VestingToken is ERC20 {
    constructor() ERC20("VestingToken", "VST") {
        _mint(msg.sender, 10 * 10**decimals());
    }
}