// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract Base {
    uint256 constant public MINIMUM_COLLATERAL_RATIO = 1100000000000000000; // 110% or 1.1
    uint256 constant public DECIMAL_PRECISION = 1e18; // 110% or 1.1
    uint256 constant public BORROWING_FEE_FLOOR = DECIMAL_PRECISION / 1000 * 5; // 0.005 * DECIMAL_PRECISION or 0.5% in wei
    uint256 constant public LUSD_GAS_COMPENSATION = 200 * DECIMAL_PRECISION;
    uint256 constant public BORROWING_FEE_DIVISOR = 200;
}
