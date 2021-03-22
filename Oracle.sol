// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

import "./SafeMath.sol";
import "./Owned.sol";
import "./WhiteList.sol";

interface IParams {
    function isLiquidation(uint256 price) external view returns (bool);
    function cost() external view returns (uint256);
    function setStakeRate(uint256 _stakerRate) external;
}

interface IEsm {
    function shutdown() external;

    function isClosed() external view returns (bool);
}

contract Oracle is Owned, WhiteList {
    using SafeMath for uint256;

    /// @notice Token-usdt price
    uint256 public val;
    /// @notice Price update date(s)
    uint256 public time;

    /// @notice Oracle Name
    bytes32 name;

    /// @notice Oracle update success event
    event OracleUpdate(uint256 val, uint256 time);

    /// @notice Dparam address
    IParams params;

    /// @notice Esm address
    IEsm esm;

    /**
     * @notice Construct a new Oracle
     * @param _params Dynamic parameter contract address
     * @param _esm Esm parameter contract address
     */
    constructor(address _esm,address _params) public Owned(msg.sender) {
        esm = IEsm(_esm);
        params = IParams(_params);
        name = "OIN-USDO3";
    }

    /**
     * @notice Chain-off push price to chain-on 喂价方法 喂价时传入参数为 价格*位数
     * @param price Token-usdt price decimals is same as token
     */
    function poke(uint256 price) public onlyWhiter {
        require(!esm.isClosed(), "System closed yet.");

        val = price;
        time = block.timestamp;
        
        uint256 stakerRate = params.cost().mul(1e16).div(val);
        params.setStakeRate(stakerRate);

        if (params.isLiquidation(price)) {
            esm.shutdown();
        } else {
            emit OracleUpdate(val, time);
        }
    }

    /**
     * @notice Anybody can read the oracle price 查询当前的喂价值
     */
    function peek() public view returns (uint256) {
        return val;
    }
}
