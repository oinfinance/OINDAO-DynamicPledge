// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <=0.7.0;

import "./Owned.sol";
import "./WhiteList.sol";

interface ITokenStake {
    function updateIndex() external;
}

contract Esm is Owned, WhiteList {
    /// @notice Access deposit pause
    uint256 public depositLive = 1;
    /// @notice Access withdraw pause
    uint256 public withdrawLive = 1;
    /// @notice Access stake pause
    uint256 public generateLive = 1;
    /// @notice Access withdraw pause
    uint256 public paybackLive = 1;
    /// @notice System closed time
    uint256 public time;
    /// @notice TokenStake for updating on closed
    ITokenStake public tokenStake;

    /// @notice System closed yet event
    event ShutDown(uint256 blocknumber, uint256 time);

    /**
     * @notice Construct a new Esm
     */
    constructor() public Owned(msg.sender) {}

    /**
     * @notice Set with tokenStake
     * @param _tokenStake Address of tokenStake
     */
    function setupTokenStake(address _tokenStake) public onlyWhiter {
        tokenStake = ITokenStake(_tokenStake);
    }

    /**
     * @notice Open deposit, if deposit pasued
     */
    function openDeposit() external onlyWhiter {
        depositLive = 1;
    }

    /**
     * @notice Paused deposit, if deposit opened
     */
    function pauseDeposit() external onlyWhiter {
        depositLive = 0;
    }

      /**
     * @notice Open withdraw, if withdraw paused
     */
    function openWithdraw() external onlyWhiter {
        withdrawLive = 1;
    }

    /**
     * @notice Pause withdraw, if withdraw opened
     */
    function pauseWithdraw() external onlyWhiter {
        withdrawLive = 0;
    }

    /**
     * @notice Open generate, if generate pasued
     */
    function openGenerate() external onlyWhiter {
        generateLive = 1;
    }

    /**
     * @notice Paused generate, if generate opened
     */
    function pauseGenerate() external onlyWhiter {
        generateLive = 0;
    }

     /**
     * @notice Open payback, if payback pasued
     */
    function openPayback() external onlyWhiter {
        paybackLive = 1;
    }

    /**
     * @notice Paused payback, if payback opened
     */
    function pausePayback() external onlyWhiter {
        paybackLive = 0;
    }

  

    /**
     * @notice Status of deposit
     */
    function isDepositPaused() external view returns (bool) {
        return depositLive == 0;
    }

    /**
     * @notice Status of withdraw
     */
    function isWithdrawPaused() external view returns (bool) {
        return withdrawLive == 0;
    }

    /**
     * @notice Status of generate
     */
    function isGeneratePaused() external view returns (bool) {
        return generateLive == 0;
    }

    /**
     * @notice Status of payback
     */
    function isPaybackPaused() external view returns (bool) {
        return paybackLive == 0;
    }

    /**
     * @notice Status of closing-sys
     */
    function isClosed() external view returns (bool) {
        return time > 0;
    }

    /**
     * @notice If anything error, project manager can shutdown it
     *         anybody cant stake, but can withdraw
     */
    function shutdown() external onlyWhiter {
        require(time == 0, "System closed yet.");
        tokenStake.updateIndex();
        time = block.timestamp;
        emit ShutDown(block.number, time);
    }
}
