// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WETHMock is ERC20 {
    using SafeMath for uint256;

    constructor() ERC20("WETH Mock", "WETHM") {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
