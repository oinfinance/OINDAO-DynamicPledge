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
    uint256 public liquidationLine = 110;
    /// @notice Redemption rate 0.3%
    uint256 public feeRate = 3;

    /// @notice Minimum number of COINS for the first time
    uint256 public minMint = 100 * ONE;
    uint256 constant ONE = 1e8;
    ///@notice UpperLimit for COINS for the System.
    uint256 public coinUpperLimit = 5000 * 1e8;
    ///@notice LowLimit for COINS for the System.
    uint256 public coinLowLimit = 200 * 1e8;
    ///@notice Set the cost of the Stake
    uint256 public cost = 7;

    event StakeRateEvent(uint256 stakeRate);
    /// @notice Reset fee event
    event FeeRateEvent(uint256 feeRate);
    /// @notice Reset liquidationLine event
    event LiquidationLineEvent(uint256 liquidationRate);
    /// @notice Reset minMint event
    event MinMintEvent(uint256 minMint);
    event CostEvent(uint256 cost, uint256 price);
    event CoinUpperLimitEvent(uint256 coinUpperLimit);
    event CoinLowLimitEvent(uint256 coinLowLimit);

    /**
     * @notice Construct a new Dparam, owner by msg.sender
     */
    constructor() public Owned(msg.sender) {}

    /**
     * @notice Reset feeRate
     * @param _feeRate New number of feeRate
     */
    function setFeeRate(uint256 _feeRate) external onlyWhiter {
        feeRate = _feeRate;
        emit FeeRateEvent(feeRate);
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
     * @notice Reset minMint
     * @param _minMint New number of minMint
     */
    function setMinMint(uint256 _minMint) external onlyWhiter {
        minMint = _minMint;
        emit MinMintEvent(minMint);
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
     * @notice Reset coinUpperLimit
     * @param _coinUpperLimit New number of coinUpperLimit
     */
    function setCoinUpperLimit(uint256 _coinUpperLimit) external onlyWhiter {
        coinUpperLimit = _coinUpperLimit;
        emit CoinUpperLimitEvent(coinUpperLimit);
    }

    /**
     * @notice Reset coinLowLimit
     * @param _coinLowLimit New number of coinLowLimit
     */
    function setCoinLowLimit(uint256 _coinLowLimit) external onlyWhiter {
        coinLowLimit = _coinLowLimit;
        emit CoinLowLimitEvent(coinLowLimit);
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
     * @notice Check Is it below the clearing line
     * @param price The token/usdt price
     * @return Whether the clearing line has been no exceeded
     */
    function isLiquidation(uint256 price) external view returns (bool) {
        return price.mul(stakeRate).mul(100) <= liquidationLine.mul(ONE);
    }

    /**
     * @notice Determine if the exchange value at the current rate is less than cost
     * @param price The token/usdt price
     * @return The value of Checking
     */
    function isNormal(uint256 price) external view returns (bool) {
        return price.mul(stakeRate) >= ONE.mul(cost);
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
     * @notice Verify that the amount of Staking in the current system has reached the lowest limit
     * @param totalCoin The number of the Staking COINS
     * @return The value of Checking
     */
    function isLowestLimit(uint256 totalCoin) external view returns (bool) {
        return totalCoin >= coinLowLimit;
    }
}
