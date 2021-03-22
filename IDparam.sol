// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

interface IDparam {
    event StakeRateEvent(uint256 stakeRate);
    event FeeRateEvent(uint256 feeRate);
    event LiquidationLineEvent(uint256 liquidationRate);
    event MinMintEvent(uint256 minMint);
    event CostEvent(uint256 cost,uint256 price);
    event CoinUpperLimitEvent(uint256 coinUpperLimit);
    event CoinLowLimitEvent(uint256 coinLowLimit);

    function stakeRate() external view returns (uint256);
    
    function coinUpperLimit() external view returns (uint256);
    
    function coinLowLimit() external view returns (uint256);
    
    function cost() external view returns (uint256);

    function liquidationLine() external view returns (uint256);

    function feeRate() external view returns (uint256);

    function minMint() external view returns (uint256);

    function setFeeRate(uint256 _feeRate) external;
    
    function setStakeRate(uint256 _stakeRate) external;

    function setLiquidationLine(uint256 _liquidationLine) external;

    function setMinMint(uint256 _minMint) external;

    function isLiquidation(uint256 price) external view returns (bool);

    function isNormal(uint256 price) external view returns (bool);
    
    function isUpperLimit(uint256 totalCoin) external view returns (bool) ;
    
    function isLowestLimit(uint256 totalCoin) external view returns (bool) ;
     
    function setCoinUpperLimit(uint256 _coinUpperLimit) external;
    
    function setCoinLowLimit(uint256 _coinLowLimit) external;
    
    function setCost(uint256 _cost,uint256 price) external;
}
