// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./LUSDToken.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// responsibilities: hold the ETH that has been liquidated
contract StabilityPool is Ownable {
    uint256 public totalLUSDDeposits;
    LUSDToken public lusdToken;
    address public vaultManagerAddress;
    address public activePoolAddress;
    uint256 public totalETHDeposited;
    
    mapping(address => uint256) public deposits;
    
    // deposit -> StabilityPool Providers should be able to deposit LUSD
    
    function setAddresses(address _lusdTokenAddress, address _vaultManagerAddress, address _activePoolAddress) external onlyOwner {
        lusdToken = LUSDToken(_lusdTokenAddress);
        vaultManagerAddress = _vaultManagerAddress;
        activePoolAddress = _activePoolAddress;
    }
    
    function deposit(uint256 _amount) external {
        deposits[msg.sender] += _amount;
        totalLUSDDeposits += _amount;
        
        // transfer from sender to this contract
        // lusdToken.approve(address(this), 2**256-1);
        lusdToken.transferFrom(msg.sender, address(this), _amount);
    }
    
    // getTotalLUSDDeposits
    function getTotalLUSDDeposits() external view returns(uint256){
        return totalLUSDDeposits;
    }
    
    function offset(uint256 _lusdDebt) external onlyVaultManager {
        // decrease the _lusdDebt
        totalLUSDDeposits -= _lusdDebt;
        
        // burn lusd
        lusdToken.burn(address(this), _lusdDebt);
    }
    
    function getTotalETHDeposits() external view returns(uint256) {
        return totalETHDeposited;
    }
    
    modifier onlyVaultManager {
        require(msg.sender == vaultManagerAddress, "StabilityPool: Sender is not vault manager");
        _;
    }
    
    modifier onlyActivePool {
        require(msg.sender == activePoolAddress, "StabilityPool: is not active pool");
        _;
    }
    
    // this is a fallback to recieve ETH
    receive() external payable onlyActivePool {
        // using "address(activePool).call{value: msg.value}("");" in "borrowing.sol" calls this function 
        
        totalETHDeposited += msg.value;
    }
    
}