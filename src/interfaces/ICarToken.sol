// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EthernautToken contract
 * @dev This is the implementation of the CarToken contract
 * @notice There is an uncapped amount of supply
 *         A user can only mint once
 */
interface ICarToken is IERC20 {
    function mint() external;
}
