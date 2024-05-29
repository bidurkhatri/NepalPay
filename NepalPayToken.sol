// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/access/Ownable.sol";

/**
 * @title NepalPayToken
 * @dev ERC20 token representing NepalPay Token (NPT)
 */
contract NepalPayToken is ERC20Burnable {
    constructor() ERC20("NepalPay Token", "NPT") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}
