// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Base.sol";
import "./VaultManager.sol";
import "./GasPool.sol";
import "./ActivePool.sol";
import "./StabilityPool.sol";
import "./PriceFeed.sol";
import "./StakingPool.sol";
import "./VaultManager.sol";
import "./LUSDToken.sol";

import "hardhat/console.sol";

// borrow and repay
contract Borrowing is Base {
    PriceFeed public priceFeed;
    
    // pools
    StakingPool public stakingPool;
    GasPool public gasPool;
    StabilityPool public stabilityPool;
    ActivePool public activePool;
    
    // lusdtoken 
    LUSDToken public lusdToken;
    VaultManager public vaultManager;
    
    constructor() {
        priceFeed = new PriceFeed();
        priceFeed.setPrice(1000 * DECIMAL_PRECISION);
        
        stabilityPool = new StabilityPool();
        activePool = new ActivePool();
        
        vaultManager = new VaultManager();
        
        stakingPool = new StakingPool(address(vaultManager));
        
        lusdToken = new LUSDToken();
        lusdToken.setAddresses(address(vaultManager), address(stabilityPool));
        
        gasPool = new GasPool(lusdToken, address(vaultManager));

        // initialize active pool
        activePool.setAddresses(address(vaultManager), address(stabilityPool));
        
        //initialize stability pool        
        stabilityPool.setAddresses(address(lusdToken), address(vaultManager), address(activePool));
        vaultManager.setAddresses(address(priceFeed), address(stabilityPool), activePool, lusdToken, gasPool);

    }
    
    function borrow(uint256 _lusdAmount) external payable {
        // get price of ETH from oracle (or in our case price feed)
        uint256 price = priceFeed.getPrice();
        console.log("Price %s", price);
        
        // verify collateral ratio
        uint256 debt = _lusdAmount * DECIMAL_PRECISION;
        
        console.log("DEBT %s ", debt);
        
        uint256 collateralRatio = (msg.value * price / debt);
        
        console.log("COLLATERAL RATIO %s ", collateralRatio);
        
        require(collateralRatio >= MINIMUM_COLLATERAL_RATIO, "Borrowing: Invalid collateral ratio");
        
        // calculate borrowing fee
        uint256 borrowingFee = vaultManager.getBorrowingFee(debt);
        console.log("BORROWING FEE FLOOR %s ", BORROWING_FEE_FLOOR);
        console.log("BORROWING FEE %s", borrowingFee);
        
        // send borrowing fees to staking pool contract
        stakingPool.increaseLUSDFees(borrowingFee);
        lusdToken.mint(address(stakingPool), borrowingFee);
        
        // mint LUSD stablecoin tokens and give to the user
        lusdToken.mint(msg.sender, debt);
        
        // calculate composite debt (borrowing fee + gas compensation + amount requested)
        uint256 compositeDebt = borrowingFee + LUSD_GAS_COMPENSATION + debt;
        
        // create a vault using the info of the loan
        vaultManager.createVault(msg.sender, msg.value, compositeDebt);
        
        // send collateral to active pool
        (bool success, ) = address(activePool).call{value: msg.value}("");
        
        require(success, "active pool not success");
        
        // increase LUSD debt of active pool
        activePool.increaseLUSDDebt(compositeDebt);
        console.log("ACTIVEPOOL LUSDDEBT %s ", activePool.getLUSDDebt());
        
        // send gas compensation
        lusdToken.mint(address(gasPool), LUSD_GAS_COMPENSATION);
        console.log("GasPool Tokens Balance ", lusdToken.balanceOf(address(gasPool)));
    }
    
    function repay() external {
        // get collateral and the debt
        uint256 collateral = vaultManager.getVaultCollateral(msg.sender);
        uint256 debt = vaultManager.getVaultDebt(msg.sender);
        
        //  calculate the debt to repay
        uint256 debtToRepay = debt - LUSD_GAS_COMPENSATION; // subtract the LUSD_GAS_COMPENSATION from the debt since this is just a deposit
        
        //  validate that the user has enough funds (LUSD)
        require(lusdToken.balanceOf(msg.sender) >= debtToRepay, "Borrowing: Insufficients funds to repay");
        
        // burn the repaid LUSD from the user's balance
        lusdToken.burn(msg.sender, debtToRepay);
        
        // decrease the LUSD debt from the active pool
        activePool.decreaseLUSDDebt(debtToRepay);
        
        // close the vault
        vaultManager.closeVault(msg.sender);
        
        // burn the gas compensation from the gas pool
        lusdToken.burn(address(gasPool), LUSD_GAS_COMPENSATION);
        
        // deccrease gas compensation from the LUSD debt
        activePool.decreaseLUSDDebt(LUSD_GAS_COMPENSATION);
        
        // send collateral back to the user
        activePool.sendETH(msg.sender, collateral);
    }
}