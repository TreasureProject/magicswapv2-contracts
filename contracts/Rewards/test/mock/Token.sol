// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "lib/solmate/src/tokens/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("", "", 18) {}
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
