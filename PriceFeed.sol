// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract PriceFeed {
    uint256 latestPrice;
    
    constructor() {
        
    }
    
    function setPrice(uint256 _price) external {
        latestPrice = _price;
    }
    
    function getPrice() external view returns(uint256) {
        return latestPrice;
    }
    
}