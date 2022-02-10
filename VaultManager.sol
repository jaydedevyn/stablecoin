// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Base.sol";
import "./SortedVaults.sol";
import "./PriceFeed.sol";
import "./LiquityMath.sol";
import "./StabilityPool.sol";
import "./ActivePool.sol";
import "./LUSDToken.sol";
import "./GasPool.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// responsibilities: redeem and liquidate
contract VaultManager is Base, Ownable {
    SortedVaults public sortedVaults;
    uint256 public baseRate; // as redemptions increase the base rate increases. Initial value is 0
    address public borrowingContract;
    PriceFeed public priceFeed;
    StabilityPool public stabilityPool;
    ActivePool public activePool;
    LUSDToken public lusdToken;
    GasPool public gasPool;
    
    enum Status {
        NonExistent,
        Active,
        ClosedByOwner, // paid
        ClosedByLiquidation, // liquidated
        closedByRedemption
    }
    
    struct Vault {
        uint256 debt;
        uint256 collateral;
        Status status;
    }
    
    mapping (address => Vault) public vaults;
    
    constructor() {
        // msg.sender in this case is the Borrowing contract
        borrowingContract = msg.sender;
        sortedVaults = new SortedVaults(msg.sender);
        baseRate = 0;
    }
    
    function setAddresses(address _priceFeedAddress, 
    address _stabilityPoolAddress, 
    ActivePool _activePool, 
    LUSDToken _lusdToken,
    GasPool _gasPool) external onlyOwner {
        priceFeed = PriceFeed(_priceFeedAddress);
        stabilityPool = StabilityPool(_stabilityPoolAddress);
        activePool = _activePool;
        lusdToken = _lusdToken;
        gasPool = _gasPool;
        renounceOwnership();
    }
    
    function getNominalICR(address _borrower) public view returns(uint256) {
        (uint256 currentETH, uint256 currentLUSDDdebt) = _getCurrentVaultAmounts(_borrower);
        if(currentLUSDDdebt > 0) {
            return currentETH * DECIMAL_PRECISION / currentLUSDDdebt;
        } else {
            //  little confused as to why we give it the "maximum" value
            return (2**256) - 1;
        }
    }
    
    function _getCurrentVaultAmounts(address _borrower) internal view returns(uint256, uint256) {
        uint256 currentETH = vaults[_borrower].collateral;
        uint256 currentLUSDDdebt = vaults[_borrower].debt;
        
        return (currentETH, currentLUSDDdebt);
    }
    
    function getBorrowingFee(uint256 _lusdAmount) external view returns(uint256) {
        // base rate + 0.5% of LUSD amount 
        return baseRate + ((BORROWING_FEE_FLOOR * _lusdAmount) / DECIMAL_PRECISION);  
    }
    
    function createVault(address _borrower, uint256 _ethAmount, uint256 _debt) external onlyBorrowingContract {
        vaults[_borrower].status = Status.Active;
        vaults[_borrower].collateral = _ethAmount;
        vaults[_borrower].debt = _debt;
        
        uint256 collateralRatio = getNominalICR(_borrower);
        
        sortedVaults.insert(_borrower, collateralRatio);
    }
    
    function getVaultCollateral(address _borrower) public view returns(uint256) {
        return vaults[_borrower].collateral;
    }
    
    function getVaultDebt(address _borrower) public view returns(uint256) {
        return vaults[_borrower].debt;
    }
    
    function closeVault(address _borrower) external onlyBorrowingContract {
        _closeVault(_borrower, Status.ClosedByOwner);
    }
    
    function _closeVault(address _borrower, Status _status) internal {
        vaults[_borrower].status = _status;
        vaults[_borrower].collateral = 0;
        vaults[_borrower].debt = 0;
        
        sortedVaults.remove(_borrower);
    }
    
    function liquidate(address _borrower) external {
        // get the price of the collateral
        uint256 price = priceFeed.getPrice();
        // get the vault info
        (uint256 currentETH, uint256 currentLUSDDebt) = _getCurrentVaultAmounts(_borrower);
        
        // calculate collateral ratio
        uint256 collateralRatio = LiquityMath._computeCR(currentETH, currentLUSDDebt, price);
        
        // verify the collateral ratio is < 110%
        require(collateralRatio < MINIMUM_COLLATERAL_RATIO, "VaultManager: Cannot Liquidate Vault");
        
        // verify we have enough LUSD in the stability pool  
        uint256 lusdInStabilityPool = stabilityPool.getTotalLUSDDeposits();
        require(lusdInStabilityPool >= currentLUSDDebt, "VaultManager: Insufficient funds to liquidate");
        
        // calculate the collateral compensation for the liquidator 
        uint256 collateralCompensation = currentETH / BORROWING_FEE_DIVISOR;
        
        uint256 collateralToLiquidate = currentETH - collateralCompensation;
        
        // decrease the LUSD of the active pool
        activePool.decreaseLUSDDebt(currentLUSDDebt);
        
        // close the vault
        _closeVault(_borrower, Status.ClosedByLiquidation);
        
        // then update the LUSD deposits in the stabilityPool & burn the tokens -> offset
        stabilityPool.offset(currentLUSDDebt);

        // send the liquidated ETH to stability pool -> This has to be distributed among stability providers
        activePool.sendETH(address(stabilityPool), collateralToLiquidate);
        
        // send gas compensation to liquidator 
        lusdToken.transferFrom(address(gasPool), msg.sender, LUSD_GAS_COMPENSATION);
        
        // send 0.5% of the eth liquidated to the liquidator
        activePool.sendETH(msg.sender, collateralCompensation);
    }
    
    modifier onlyBorrowingContract {
        require(msg.sender == borrowingContract, "StakingPool: Invalid borrowing contract");
        _;
    }
}