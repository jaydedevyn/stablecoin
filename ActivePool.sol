// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// responsibilities: to hold ETH as well as LUSD debt
contract ActivePool is Ownable {
    address public borrowingContract;
    address public vaultManager;
    address public stabilityPool;
    
    uint256 public totalETHDeposited;
    uint256 public totalLUSDDebt;
    
    // getETHDeposited

    function setAddresses(address _vaultManagerAddress, address _stabilityPoolAddress) external onlyOwner {
        borrowingContract = msg.sender;
        vaultManager = _vaultManagerAddress;
        stabilityPool = _stabilityPoolAddress;
        
        renounceOwnership();
    }
    
    
    function getETHDeposited() external view returns(uint256) {
        return totalETHDeposited;
    }
    
    function getLUSDDebt() external view returns(uint256) {
        return totalLUSDDebt;
    }
    
    function increaseLUSDDebt(uint256 _amount) external onlyBorrowingContract {
        totalLUSDDebt += _amount;
    }
    
    function decreaseLUSDDebt(uint256 _amount) external onlyBorrowingOrVaultManagerOrStabilityPoolContract {
        totalLUSDDebt -= _amount;
    }
    
    function sendETH(address _account, uint256 _amount) external payable onlyBorrowingOrVaultManagerOrStabilityPoolContract {
        // borrowing when we are repaying
        // stabilityPool when liquidating
        // vault manager when redemption
        
        require(totalETHDeposited >= _amount, "ActivePool does not have enough ETH");
        totalETHDeposited -= _amount;
        
        (bool success, ) = _account.call{value: _amount}("");
        
        require(success, "ActivePool: Could not send eth to account");
    }
    
    modifier onlyBorrowingContract {
        require(msg.sender == borrowingContract, "ActivePool: Invalid borrowing contract");
        _;
    }
    
     modifier onlyBorrowingOrVaultManagerOrStabilityPoolContract {
        require(msg.sender == borrowingContract || msg.sender == vaultManager || msg.sender == stabilityPool, "ActivePool: Invalid contract");
        _;
    }
    
    // this is a fallback to recieve ETH
    receive() external payable onlyBorrowingContract {
        // using "address(activePool).call{value: msg.value}("");" in "borrowing.sol" calls this function 
        
        totalETHDeposited += msg.value;
    }
}