// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <=0.7.0;

import "./SafeMath.sol";
import "./Owned.sol";
import "./IDparam.sol";
import "./WhiteList.sol";

contract Dparam is Owned, WhiteList, IDparam {
    using SafeMath for uint256;

    /// @notice Subscription ratio token -> coin
    uint256 public stakeRate = 35;
    /// @notice The collateral rate of liquidation
    uint256 public liquidationLine = 200;
    ///@notice Funds rate 0.5%
    uint256 public fundsRate = 5;

    uint256 constant ONE = 1e8;
    ///@notice UpperLimit for COINS for the System.
    uint256 public coinUpperLimit = 5000 * 1e8;
    ///@notice Set the cost of the Stake
    uint256 public cost = 7;
    uint256 public claimRequirment = 5;
    uint256 public totalToken;
    uint256 public totalCoin;
    event StakeRateEvent(uint256 stakeRate);
    ////@notice Reset funds Rate event
    event FundsRateEvent(uint256 fundsRate);
    /// @notice Reset liquidationLine event
    event LiquidationLineEvent(uint256 liquidationRate);
    /// @notice Reset cost event
    event CostEvent(uint256 cost, uint256 price);
    /// @notice Reset coinUpperLimit event
    event CoinUpperLimitEvent(uint256 coinUpperLimit);
    /// @notice Reset totalToken event
    event SetTotalTokenEvent(uint256 totalToken);
    /// @notice Reset totalCoin event
    event SetTotalCoinEvent(uint256 totalCoin);
    /// @notice Reset claimRequirment event
    event ClaimRequirmentEvent(uint256 claimRequirment);

    /**
     * @notice Construct a new Dparam, owner by msg.sender
     */
    constructor() public Owned(msg.sender) {}

    /**
     * @notice Reset fundsRate
     * @param _fundsRate New number of fundsRate
     */
    function setFundsRate(uint256 _fundsRate) external onlyWhiter {
        fundsRate = _fundsRate;
        emit FundsRateEvent(fundsRate);
    }

    /**
     * @notice Reset liquidationLine
     * @param _liquidationLine New number of liquidationLine
     */
    function setLiquidationLine(uint256 _liquidationLine) external onlyWhiter {
        liquidationLine = _liquidationLine;
        emit LiquidationLineEvent(liquidationLine);
    }

    /**
     * @notice Reset stakeRate
     * @param _stakeRate New number of stakeRate
     */
    function setStakeRate(uint256 _stakeRate) external onlyWhiter {
        stakeRate = _stakeRate;
        emit StakeRateEvent(stakeRate);
    }

     /**
     * @notice Reset totalToken
     * @param _totalToken New number of totalToken
     */
    function setTotalToken(uint256 _totalToken) external onlyWhiter {
        totalToken = _totalToken;
        emit SetTotalTokenEvent(totalToken);
    }
    
     /**
     * @notice Reset totalCoin
     * @param _totalCoin New number of totalCoin
     */
    function setTotalCoin(uint256 _totalCoin) external onlyWhiter {
        totalCoin = _totalCoin;
        emit SetTotalCoinEvent(totalCoin);
    }

    /**
     * @notice Reset coinUpperLimit
     * @param _coinUpperLimit New number of coinUpperLimit
     */
    function setCoinUpperLimit(uint256 _coinUpperLimit) external onlyWhiter {
        coinUpperLimit = _coinUpperLimit;
        emit CoinUpperLimitEvent(coinUpperLimit);
    }

    /**
     * @notice Reset claimRequirment
     * @param _claimRequirment New number of _claimRequirment
     */
    function setClaimRequirment(uint256 _claimRequirment) external onlyWhiter {
        claimRequirment = _claimRequirment;
        emit ClaimRequirmentEvent(claimRequirment);
    }
    
        /**
     * @notice Reset cost
     * @param _cost New number of _cost
     * @param price New number of price
     */
    function setCost(uint256 _cost, uint256 price) external onlyWhiter {
        cost = _cost;
        stakeRate = cost.mul(1e16).div(price);
        emit CostEvent(cost, price);
    }


    /**
     * @notice Verify that the amount of Staking in the current system has reached the upper limit
     * @param totalCoin The number of the Staking COINS
     * @return The value of Checking
     */
    function isUpperLimit(uint256 totalCoin) external view returns (bool) {
        return totalCoin <= coinUpperLimit;
    }
    
       /**
     * @notice Check Is it below the clearing line
     * @param price The token/usdt price
     * @return Whether the clearing line has been no exceeded
     */
    function isLiquidation(uint256 price) external view returns (bool) {
        if(totalCoin == 0){
            return false;
        }else{
            return totalToken.mul(price).div(totalCoin).mul(100) <= liquidationLine.mul(ONE);
        }
      
    }
}
