// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// responsibilites: This pool holds the redemption fees and borrowing fees that gets distributed to stakers 
contract StakingPool is Ownable {
    uint256 public totalETHFees; // on redemptions
    uint256 public totalLUSDFees; // on borrowing
    address borrowing;
    address vaultManager;
    
    constructor(address _vaultManager) {
        borrowing = msg.sender;
        vaultManager = _vaultManager;
        totalLUSDFees = 0;
        totalETHFees = 0;
    }
    
    function increaseLUSDFees(uint256 _amount) external onlyBorrowingContract {
        totalLUSDFees += _amount;
    }
    
    function increaseETHFees(uint256 _amount) external onlyVaultManagerContract {
        totalETHFees += _amount;
    }
    
    modifier onlyBorrowingContract {
        require(msg.sender == borrowing, "StakingPool: Invalid borrowing contract");
        _;
    }
    
    modifier onlyVaultManagerContract {
        require(msg.sender == vaultManager, "StakingPool: Invalid borrowing contract");
        _;
    }
    
}