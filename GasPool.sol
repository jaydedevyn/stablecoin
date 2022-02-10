// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./LUSDToken.sol";

// responsiblility: to store the GAS fee of 200 USD worth of ETH in case user gets liquidated.
// This 200 USD worth of ETH gets refunded if the borrower pays their debt. (Acts as a deposit pool for gas)
contract GasPool {
    
    constructor(LUSDToken _lusdToken, address _spender) {
        // approve the spender to spend LUSDToken on behalf of the gaspool
        // (This happens in the vault manager)
        _lusdToken.approve(_spender, 2**256 -1);
    }
}
