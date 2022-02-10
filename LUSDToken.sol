// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

// LUSD Token is an ERC-20 token with mint + burn restricted to certain actors
contract LUSDToken is ERC20 {
    // mint: onlyBorrowingContract
    // burn: onlyBorrowingOrVaultManagerOrStabilityPoolContract
    
    address public borrowingContract;
    address public vaultManagerContract;
    address public stabilityContract;
    
    constructor() ERC20("LUSDToken", "LUSDToken") {
    }
    
    function setAddresses(address _vaultManagerContract, address _stabilityContract) external onlyBorrowingContract {
        borrowingContract = msg.sender;
        vaultManagerContract = _vaultManagerContract;
        stabilityContract = _stabilityContract;
    }
    
    function mint(address _account, uint256 _amount) external onlyBorrowingContract {
        _mint(_account, _amount);
    }
    
    function burn(address _account, uint256 _amount) external onlyBorrowingOrVaultManagerOrStabilityPoolContract {
        _burn(_account, _amount);
    }
    
    modifier onlyBorrowingContract {
        require(msg.sender == borrowingContract, "LUSDToken: Invalid borrowing contract");
        _;
    }
    
    modifier onlyBorrowingOrVaultManagerOrStabilityPoolContract {
        require(msg.sender == borrowingContract || msg.sender == vaultManagerContract || msg.sender == stabilityContract, "LUSDToken: Invalid contract");
        _;
    }
}
