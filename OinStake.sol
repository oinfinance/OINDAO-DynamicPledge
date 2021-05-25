// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./Math.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Owned.sol";
import "./IDparam.sol";
import "./WhiteList.sol";

interface IOracle {
    function val() external returns (uint256);

    function poke(uint256 price) external;

    function peek() external;
}

interface FeeOracle {
    function val() external returns (uint256);
}

interface IESM {
    function isDepositPaused() external view returns (bool);

    function isWithdrawPaused() external view returns (bool);

    function isGeneratePaused() external view returns (bool);

    function isPaybackPaused() external view returns (bool);

    function isClosed() external view returns (bool);

    function time() external view returns (uint256);
}

interface ICoin {
    function burn(address account, uint256 amount) external;

    function mint(address account, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}

contract OinStake is Owned, WhiteList {
    using Math for uint256;
    using SafeMath for uint256;

    /**
     * @notice reward pools state
     * @param index Accumulated earnings index by staker
     * @param reward Accumulative reward
     */
    struct StakerState {
        uint256 index;
        uint256 reward;
    }

    /**
     * @notice fundsFee array
     * @param staker fundsFee
     * @param block update blockNumber
     */

    struct FundsFeeState {
        uint256 block;
    }

    /**
     * @notice reward array
     * @param coinAddress The address of reward coin
     * @param rewardTotal The total number or reward
     * @param rewardSpeed The speed of reward delivery
     * @param initialIndex Inital index
     * @param blockNumber The block number
     * @param doubleScale Amplification factor
     * @param coin Inject reward coin
     */
    struct RewardCoin {
        address coinAddress;
        uint256 rewardTotal;
        uint256 rewardSpeed;
        uint256 initialIndex;
        uint256 index;
        uint256 blockNumber;
        uint256 doubleScale;
        IERC20 coin;
    }
    ///@notice All rewards token arrays
    RewardCoin[] public rewardCoins;
    /// @notice All staker-instances state
    mapping(address => StakerState[]) public stakerStateArray;
    /// @notice All fundsFee state
    mapping(address => FundsFeeState) public fundsFeeStates;
    ///The index of reward token
    mapping(address => uint256) public rewardCoinIndex;
    /// @notice The amount by staker with token
    mapping(address => uint256) public tokens;
    ///  The amount by staker with coin
    mapping(address => uint256) public coins;
    ///  The amount by staker with cToken
    mapping(address => uint256) public cTokens;
    ///  The amount by staker with feeTokens
    mapping(address => uint256) public feeTokens;
    ///@notice determines whether the user initializes the currency
    mapping(address => bool) private isOrNot;
    /// @notice The total amount of out-coin in sys
    uint256 public totalCoin;
    /// @notice The total amount of stake-token in sys
    uint256 public totalToken;
    /// @notice The total amount of totalCToken in sys
    uint256 public totalCToken;

    uint256 constant ONE = 10**8;
    address constant pmFeeHolder = 0x1111111111111111111111111111111111111111;

    /// @notice Dparam address
    IDparam params;
    /// @notice Oracle address
    IOracle orcl;
    /// @notice FundsFee Oracle address
    FeeOracle feeOrcl;
    /// @notice Esm address
    IESM esm;
    /// @notice Coin address
    ICoin coin;
    /// @notice cToken address
    ICoin cToken;
    /// @notice Token address
    IERC20 token;
    /// @notice feeToken address
    IERC20 feeToken;

    ///各种事件Events
    ///@notice Setup params address success
    event SetupParamsAddress(
        address esm,
        address params,
        address orcl,
        address feeOrcl
    );
    /// @notice Setup Token&Coin address success
    event SetupCoin(
        address token,
        address coin,
        address cToken,
        address feeToken
    );
    /// @notice Update index success
    event IndexUpdate(uint256 delt, uint256 block, uint256 index);
    /// @notice Stake success
    event DepositEvent(uint256 tokenAmount);
    /// @notice Stake success
    event WithdrawEvent(uint256 tokenAmount, address receiver);
    /// @notice Stake success
    event GenerateEvent(uint256 coinAmount);
    /// @notice Stake success
    event PaybackEvent(uint256 coinAmount);
    /// @notice ClaimToken success
    event ClaimToken(address holder, uint256 value, address coinAddress);
    /// @notice InjectReward success
    event InjectReward(uint256 amount, address coinAddress);
    /// @notice ExtractReward success
    event ExtractReward(address reciver, uint256 amount, address coinAddress);
    /// @notice ORedeem success
    event oRedeemEvent(uint256 tokenAmount, uint256 coinAmount);

    /**
     * @notice Construct a new OinStake, owner by msg.sender
     */
    constructor(
        address _esm,
        address _param,
        address _orcl,
        address _feeOrcl
    ) public Owned(msg.sender) {
        esm = IESM(_esm);
        params = IDparam(_param);
        orcl = IOracle(_orcl);
        feeOrcl = FeeOracle(_feeOrcl);
        InitRewardCoin();
    }

    ///@notice Check whether the current system is down
    modifier notClosed() {
        require(!esm.isClosed(), "System closed");
        _;
    }

    /**
     * @notice reset Esm,Dapram,Oracle,FundsFeeOracle address.
     * @param _esm Configuration Esm contract address
     * @param _param Configuration Dapram contract address
     * @param _orcl Configuration Oracle contract address
     * @param _feeOrcl Configuration FunsFeeOracle contract address
     */
    function setupParamsAddress(
        address _esm,
        address _param,
        address _orcl,
        address _feeOrcl
    ) public onlyWhiter {
        esm = IESM(_esm);
        params = IDparam(_param);
        orcl = IOracle(_orcl);
        feeOrcl = FeeOracle(_feeOrcl);
        emit SetupParamsAddress(_esm, _param, _orcl, _feeOrcl);
    }

    /**
     * @notice get Dparam address.
     * @return Esm contract address
     * @return Dparam contract address
     * @return Oracle contract address
     * @return FundsFeeOracle contract address
     */
    function getParamsAddr()
        public
        view
        returns (
            address esm,
            address param,
            address orcl,
            address feeOrcl
        )
    {
        return (address(esm), address(param), address(orcl), address(feeOrcl));
    }

    /**
     * @notice Get block number now
     */
    function getBlockNumber() public view returns (uint256) {
        return block.number;
    }

    /**
     * @notice inject token address & coin & cToken & feeToken address only once.
     * @param _token token address
     * @param _coin coin address
     * @param _cToken cToken address
     * @param _feeToken feeToken address
     */
    function setup(
        address _token,
        address _coin,
        address _cToken,
        address _feeToken
    ) public onlyWhiter {
        require(
            address(token) == address(0) &&
                address(coin) == address(0) &&
                address(cToken) == address(0) &&
                address(feeToken) == address(0),
            "setuped yet."
        );
        token = IERC20(_token);
        coin = ICoin(_coin);
        cToken = ICoin(_cToken);
        feeToken = IERC20(_feeToken);
        emit SetupCoin(_token, _coin, _cToken, _feeToken);
    }

    /**
     * @notice Init RewardCoin array
     */
    function InitRewardCoin() public onlyWhiter {
        //Fist reward coin information
        addRewardCoin(
            0xD78B0A147EE7879F14a7CEF25761CB58ED978681,
            0,
            2.5e8,
            1e16,
            0,
            1e16
        );
        //Second reward coin information
        addRewardCoin(
            0x836ae4569F4c740A295Fc7a8438C928b7097d446,
            0,
            5e18,
            1e36,
            0,
            1e24
        );
    }

    /**
     * @notice Get rewardCoins
     */
    function getRewardCoins() public view returns (RewardCoin[] memory) {
        return rewardCoins;
    }

    /**
     * @notice Add a new RewardCoin
     */
    function addRewardCoin(
        address coinAddress,
        uint256 rewardTotal,
        uint256 rewardSpeed,
        uint256 initialIndex,
        uint256 index,
        uint256 doubleScale
    ) public onlyWhiter {
        require(
            rewardCoins.length <= 20,
            "The currency slot has been used up, please modify other currency information as appropriate"
        );
        for (uint256 i = 0; i < rewardCoins.length; i++) {
            require(
                coinAddress != rewardCoins[i].coinAddress,
                "The current currency has been added, please add a new currency."
            );
        }
        uint256 blockNumber = getBlockNumber();
        rewardCoins.push(
            RewardCoin(
                coinAddress,
                rewardTotal,
                rewardSpeed,
                initialIndex,
                index,
                blockNumber,
                doubleScale,
                IERC20(coinAddress)
            )
        );
        rewardCoinIndex[coinAddress] = rewardCoins.length - 1;
    }

    /**
     * @notice Reset reward speed.
     */
    function setRewardSpeed(uint256 speed, address coinAddress)
        public
        onlyWhiter
    {
        uint256 rewardCoinSub = rewardCoinIndex[coinAddress];
        updateIndex();
        rewardCoins[rewardCoinSub].rewardSpeed = speed;
    }

    /**
     * @notice Get the number of debt by the `account`
     * @param account token address
     * @return (tokenAmount,coinAmount)
     */
    function debtOf(address account) public view returns (uint256, uint256) {
        return (tokens[account], coins[account]);
    }

    /**
     * @notice Get the number of debt by the `account`
     * @param coinAmount The amount that staker want to get stableToken
     * @return The amount that staker want to transfer token.
     */
    function getInputToken(uint256 coinAmount)
        public
        view
        returns (uint256 tokenAmount)
    {
        tokenAmount = coinAmount.mul(params.stakeRate()).div(1e8);
    }

    /**
     * @notice Calculate fundsfee
     * @param  staker token address
     * @return The amount of fundsfee that staker need to pay.
     */

    function _getFundsFee(address staker)
        internal
        view
        returns (uint256 value)
    {
        FundsFeeState storage FundsFeeState = fundsFeeStates[staker];
        uint256 fundsRate = params.fundsRate();
        uint256 blockNumber = getBlockNumber();
        uint256 deltBlock = blockNumber.sub(fundsFeeStates[staker].block);
        uint256 fundsTokenAmount =
            (coins[staker].mul(params.fundsRate().mul(deltBlock))).div(
                1000 * 2102400
            );
        return fundsTokenAmount;
    }

    /**
     * @notice Get User fundsfee
     * @param  staker token address
     * @return The amount of fundsfee that staker need to pay.
     */
    function getFundsFee(address staker) public view returns (uint256 value) {
        return _getFundsFee(staker);
    }

    /**
     * @notice Determine whether the current pledge rate reaches the pledge rate
     * @param staker token address
     */
    function _judgePledgeRate(address staker) internal returns (bool) {
        if (coins[staker] > 0) {
            return
                tokens[staker].mul(orcl.val()).div(coins[staker]) >=
                params.cost().mul(1e8);
        }
    }

    /**
     * @notice Used to correct the effect of one's actions on one's own earnings
     *         System shutdown will no longer count
     */
    function updateIndex() public {
        if (esm.isClosed()) {
            return;
        }
        uint256 blockNumber = getBlockNumber();
        for (uint256 i = 0; i < rewardCoins.length; i++) {
            uint256 deltBlock = blockNumber.sub(rewardCoins[i].blockNumber);
            if (deltBlock > 0) {
                uint256 accruedReward =
                    rewardCoins[i].rewardSpeed.mul(deltBlock);
                uint256 ratio =
                    totalToken == 0
                        ? 0
                        : accruedReward.mul(rewardCoins[i].doubleScale).div(
                            totalToken
                        );
                rewardCoins[i].index = rewardCoins[i].index.add(ratio);
                rewardCoins[i].blockNumber = blockNumber;
            } else {
                rewardCoins[i].index = rewardCoins[i].index;
                rewardCoins[i].blockNumber = blockNumber;
            }
            emit IndexUpdate(deltBlock, blockNumber, rewardCoins[i].index);
        }
    }

    /**
     * @notice Used to correct the effect of one's actions on one's own earnings
     *         System shutdown will no longer count
     * @param account staker address
     */
    function accuredToken(address account) internal returns (uint256) {
        updateIndex();

        if (!isOrNot[account]) {
            // init
            for (uint256 i = 0; i < 20; i++) {
                stakerStateArray[account].push(StakerState(0, 0));
            }
            isOrNot[account] = true;
        }

        // update
        for (uint256 i = 0; i < rewardCoins.length; i++) {
            stakerStateArray[account][i].reward = _getReward(
                account,
                rewardCoins[i].coinAddress
            );
            stakerStateArray[account][i].index = rewardCoins[i].index;
        }
    }

    /**
     * @notice select holder's StateArray
     */
    function getStakerStateArray() public view returns (StakerState[] memory) {
        return stakerStateArray[msg.sender];
    }

    /**
     * @notice Normally tokenAmount anyAmount internal
     * @param tokenAmount The number of coin will be staking
     */
    function deposit(uint256 tokenAmount) external notClosed {
        require(!esm.isDepositPaused(), "Deposit paused");
        require(tokenAmount > 0, "The quantity is less than the minimum");
        require(orcl.val() > 0, "Oracle price not initialized.");

        address from = msg.sender;
        accuredToken(from);
        token.transferFrom(from, address(this), tokenAmount);
        cToken.mint(from, tokenAmount);
        totalToken = totalToken.add(tokenAmount);
        totalCToken = totalCToken.add(tokenAmount);
        tokens[from] = tokens[from].add(tokenAmount);
        cTokens[from] = cTokens[from].add(tokenAmount);
        params.setTotalToken(totalToken);
        emit DepositEvent(tokenAmount);
    }

    /**
     * @notice Normally withdraw anyAmount internal
     * @param tokenAmount The number of coin will be withdrawed
     * @param receiver The user who will receive these tokens
     */
    function withdraw(uint256 tokenAmount, address receiver)
        external
        notClosed
    {
        require(!esm.isWithdrawPaused(), "Withdraw paused");
        address staker = msg.sender;
        require(tokens[staker] > 0, "No collateral");
        require(tokenAmount > 0, "The quantity is less than zero");
        require(tokenAmount <= tokens[staker], "input amount overflow");

        //当用户生成稳定币后，在计算超过质押率部分的Token时需要先扣除稳定费
        if (coins[staker] > 0) {
            require(
                _judgePledgeRate(staker),
                "The current pledge rate does not meet the system pledge rate requirements"
            );
            uint256 fundsTokenAmount = _getFundsFee(staker);
            // Calculate the token that can be extracted
            uint256 redundantOin;
            if(orcl.val().mul(tokens[staker]).div(1e8) <= coins[staker].add(fundsTokenAmount).mul(params.cost())){
                redundantOin = 0;
            }else{
                redundantOin =
                orcl
                    .val()
                    .mul(tokens[staker])
                    .div(1e8)
                    .sub(coins[staker].add(fundsTokenAmount).mul(params.cost()))
                    .mul(1e8)
                    .div(orcl.val());
            }

            require(
                redundantOin > 0,
                "There are currently no OIN tokens available to collect"
            );
            if(tokenAmount >= redundantOin){
                 tokenAmount = redundantOin;
            }
           
        }
        //当用户cOIN余额不足时，最大可提取出等同cOIN数量的OIN
        if (tokenAmount > cToken.balanceOf(staker)) {
            tokenAmount = cToken.balanceOf(staker);
        }

        accuredToken(staker);
        token.transfer(receiver, tokenAmount);
        cToken.burn(staker, tokenAmount);

        totalToken = totalToken.sub(tokenAmount);
        totalCToken = totalCToken.sub(tokenAmount);
        tokens[staker] = tokens[staker].sub(tokenAmount);
        cTokens[staker] = cTokens[staker].sub(tokenAmount);
        params.setTotalToken(totalToken);
        emit WithdrawEvent(tokenAmount, receiver);
    }

    /**
     * @notice Normally generate anyAmount internal
     * @param coinAmount The number of coin will be generated
     */
    function generate(uint256 coinAmount) external notClosed {
        require(!esm.isGeneratePaused(), "Generate paused");
        address from = msg.sender;
        require(tokens[from] > 0, "No collateral");
        require(coinAmount > 0, "The quantity is less than zero");

        ///当用户生成数量超过最大数量时，设定为最大数量
        if (
            tokens[from].mul(1e8).div(params.stakeRate()).sub(coins[from]) < coinAmount
        ) {
            coinAmount = tokens[from].mul(1e8).div(params.stakeRate()).sub(coins[from]);
        }

        //判断用户是否首次生成 1.首次生成 初始化用户稳定费结构体 2.非首次生成 直接收取用户相应稳定费
        uint256 blockNumber = getBlockNumber();
        if (coins[from] == 0) {
            fundsFeeStates[from].block = blockNumber;
        } else {
            //Calculation of funds amount 计算用户稳定费用
            uint256 fundsTokenAmount = _getFundsFee(from);
            //Calculation of feeToken Amount 计算应付手续费的数量
            uint256 feeTokenAmount =
                fundsTokenAmount.mul(orcl.val()).div(feeOrcl.val());
            require(
                feeToken.balanceOf(from) >= feeTokenAmount,
                "Insufficient balance of stability token in current account"
            );
            feeToken.transferFrom(from, pmFeeHolder, feeTokenAmount);
            fundsFeeStates[from].block = blockNumber;
        }
        if (totalCoin.add(coinAmount) >= params.coinUpperLimit()) {
            coinAmount = params.coinUpperLimit().sub(totalCoin);
        }
        coin.mint(from, coinAmount);
        coins[from] = coins[from].add(coinAmount);
        totalCoin = totalCoin.add(coinAmount);
        params.setTotalCoin(totalCoin);
        emit GenerateEvent(coinAmount);
    }

    /**
     * @notice Normally payback anyAmount internal
     * @param coinAmount The number of coin will be paybacked
     */
    function payback(uint256 coinAmount) external notClosed {
        require(!esm.isPaybackPaused(), "Payback paused");
        address from = msg.sender;
        require(coinAmount > 0, "The quantity is less than the minimum");
        require(coinAmount <= coins[from], "input amount overflow");

        accuredToken(from);
        uint256 blockNumber = getBlockNumber();
        //Calculation of funds amount 计算用户稳定费用
        uint256 fundsTokenAmount = _getFundsFee(from);
        //Calculation of feeToken Amount 计算应付手续费的数量
        uint256 feeTokenAmount =
            fundsTokenAmount.mul(orcl.val()).div(feeOrcl.val());
        require(
            feeToken.balanceOf(from) >= feeTokenAmount,
            "Insufficient balance of stability token in current account"
        );
        feeToken.transferFrom(from, pmFeeHolder, feeTokenAmount);
        fundsFeeStates[from].block = blockNumber;
        coin.burn(from, coinAmount);
        coins[from] = coins[from].sub(coinAmount);
        totalCoin = totalCoin.sub(coinAmount);
        params.setTotalCoin(totalCoin);
        emit PaybackEvent(coinAmount);
    }

    /**
     * @notice Abnormally payback anyAmount internal
     * @param coinAmount The number of coin will be paybacked
     * @param receiver Address of receiving
     */
    function _abnormalPayback(uint256 coinAmount, address receiver) internal {
        require(esm.isClosed(), "System not Closed yet.");
        address from = msg.sender;
        require(coinAmount > 0, "The quantity is less than zero");
        require(coin.balanceOf(from) > 0, "The coin no balance.");
        require(coinAmount <= coin.balanceOf(from), "Coin balance exceed");
        uint256 tokenAmount = coinAmount.mul(totalToken).div(totalCoin);
        

        if (tokens[from] >= tokenAmount) {
            tokens[from] = tokens[from].sub(tokenAmount);
        } else {
            tokens[from] = 0;
        }

        if (coins[from] > coinAmount) {
            coins[from] = coins[from].sub(coinAmount);
        } else {
            coins[from] = 0;
        }

        if (cToken.balanceOf(from) <= tokenAmount) {
            cTokens[from] = 0;
            cToken.burn(from, cToken.balanceOf(from));
            totalCToken = totalCToken.sub(cToken.balanceOf(from));
        } else {
            cTokens[from] = cTokens[from].sub(tokenAmount);
            cToken.burn(from, tokenAmount);
            totalCToken = totalCToken.sub(tokenAmount);
        }

        coin.burn(from, coinAmount);
        token.transfer(receiver, tokenAmount);

        totalCoin = totalCoin.sub(coinAmount);
        totalToken = totalToken.sub(tokenAmount);

        emit oRedeemEvent(tokenAmount, coinAmount);
    }

    /**
     * @notice System shutdown under the redemption rule
     * @param coinAmount The number coin
     * @param receiver Address of receiving
     */
    function oRedeem(uint256 coinAmount, address receiver) public {
        _abnormalPayback(coinAmount, receiver);
    }
       /**
     * @notice System shutdown under the redemption rule
     * @param coinAmount The number coin
     */
    function oRedeem(uint256 coinAmount) public {
        oRedeem(coinAmount, msg.sender);
    }

    /**
     * @notice Calculate the current holder's mining income
     * @param staker Address of holder
     */
    function _getReward(address staker, address coinAddress)
        internal
        view
        returns (uint256 value)
    {
        uint256 rewardCoinSub = rewardCoinIndex[coinAddress];

        value = stakerStateArray[staker][rewardCoinSub].reward.add(
            rewardCoins[rewardCoinSub]
                .index
                .sub(stakerStateArray[staker][rewardCoinSub].index)
                .mul(tokens[staker])
                .div(rewardCoins[rewardCoinSub].doubleScale)
        );
    }

    /**
     * @notice Estimate the mortgagor's reward
     * @param account Address of staker
     * @param coinAddress Address of reward's token
     */
    function getHolderReward(address account, address coinAddress)
        public
        view
        returns (uint256 value)
    {
        uint256 rewardCoinSub = rewardCoinIndex[coinAddress];
        uint256 blockReward2 =
            (totalToken == 0 || esm.isClosed())
                ? 0
                : getBlockNumber()
                    .sub(rewardCoins[rewardCoinSub].blockNumber)
                    .mul(rewardCoins[rewardCoinSub].rewardSpeed)
                    .mul(tokens[account])
                    .div(totalToken);
        value = _getReward(account, coinAddress) + blockReward2;
    }

    /**
     * @notice Extract the current reward in one go
     * @param holder Address of receiver
     * @param coinAddress Address of reward's token
     */
    function claimToken(address holder, address coinAddress) public {
      if (coins[holder] > 0) {
            require(
                tokens[holder].mul(orcl.val()).div(coins[holder]) >= params.claimRequirment().mul(1e8),
                "The current pledge rate does not meet the system pledge rate requirements"
            );
          
      }
        accuredToken(holder);
        uint256 rewardCoinSub = rewardCoinIndex[coinAddress];
        uint256 value =
            stakerStateArray[holder][rewardCoinSub].reward.min(
                rewardCoins[rewardCoinSub].rewardTotal
            );
        require(value > 0, "The reward of address is zero.");

        rewardCoins[rewardCoinSub].coin.transfer(holder, value);
        rewardCoins[rewardCoinSub].rewardTotal = rewardCoins[rewardCoinSub]
            .rewardTotal
            .sub(value);

        stakerStateArray[holder][rewardCoinSub].index = rewardCoins[
            rewardCoinSub
        ]
            .index;
        stakerStateArray[holder][rewardCoinSub].reward = stakerStateArray[
            holder
        ][rewardCoinSub]
            .reward
            .sub(value);

        emit ClaimToken(holder, value, coinAddress);
    }

    /**
     * @notice Inject token to reward
     * @param amount The number of injecting
     * @param coinAddress Address of reward's token
     */
    function injectReward(uint256 amount, address coinAddress)
        external
        onlyOwner
    {
        uint256 rewardCoinSub = rewardCoinIndex[coinAddress];
        rewardCoins[rewardCoinSub].coin.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        rewardCoins[rewardCoinSub].rewardTotal = rewardCoins[rewardCoinSub]
            .rewardTotal
            .add(amount);

        emit InjectReward(amount, coinAddress);
    }

    /**
     * @notice Extract token from reward
     * @param account Address of receiver
     * @param amount The number of extracting
     * @param coinAddress Address of reward's token
     */
    function extractReward(
        address account,
        uint256 amount,
        address coinAddress
    ) external onlyOwner {
        uint256 rewardCoinSub = rewardCoinIndex[coinAddress];

        require(
            amount <= rewardCoins[rewardCoinSub].rewardTotal,
            "withdraw overflow."
        );
        rewardCoins[rewardCoinSub].coin.transfer(account, amount);
        rewardCoins[rewardCoinSub].rewardTotal = rewardCoins[rewardCoinSub]
            .rewardTotal
            .sub(amount);

        emit ExtractReward(account, amount, coinAddress);
    }
}
