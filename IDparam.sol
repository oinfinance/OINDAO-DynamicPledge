// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

interface IDparam {
    event StakeRateEvent(uint256 stakeRate);
    event FundsRateEvent(uint256 fundsRate);
    event LiquidationLineEvent(uint256 liquidationRate);
    event CostEvent(uint256 cost, uint256 price);
    event CoinUpperLimitEvent(uint256 coinUpperLimit);
    event SetTotalTokenEvent(uint256 totalToken);
    event SetTotalCoinEvent(uint256 totalCoin);
    event ClaimRequirmentEvent(uint256 claimRequirment);

    function stakeRate() external view returns (uint256);
    
    function setTotalToken(uint256 _totalToken) external;
 
    function setTotalCoin(uint256 _totalCoin) external;
    
    function coinUpperLimit() external view returns (uint256);

    function cost() external view returns (uint256);
    
    function claimRequirment()external view returns (uint256);

    function liquidationLine() external view returns (uint256);

    function fundsRate() external view returns (uint256);

    function setFundsRate(uint256 _fundsRate) external;

    function setStakeRate(uint256 _stakeRate) external;

    function setLiquidationLine(uint256 _liquidationLine) external;

    function isLiquidation(uint256 price) external view returns (bool);

    function isUpperLimit(uint256 totalCoin) external view returns (bool);

    function setCoinUpperLimit(uint256 _coinUpperLimit) external;

    function setCost(uint256 _cost, uint256 price) external;
    
    function setClaimRequirment(uint256 _claimRequirment) external;
}
