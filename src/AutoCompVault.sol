// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "forge-std/console.sol";

contract AutoCompVault is Ownable, Pausable, ReentrancyGuard, ERC20 {
    using SafeERC20 for IERC20;

    // CRVstETH token (deposit/invest token)
    // IDepositToken vs IERC20: mint, burn functions (external)
    IERC20 public immutable depositToken;

    // share token - SCRVstETH (shares)
    // share (pool) token is ERC20 inherited here.

    // mapping of user address to deposit token amount
    mapping(address => uint256) public vaults;

    // total amount of deposit token deposited in the vault
    uint256 public totalDepositBalance;

    uint32 public lastDepositTimestamp;

    // in percentage i.e. 0.5% = 0.005 => represented as 1e5 (scaling_factor) => 500
    // NOTE: We can put this scaling factor as high as possible i.e. 1e18,
    // but then during division it would lose the precision. Hence, choose as small as possible.
    // Hence, keep the scaling_factor as low as possible.
    // make sure during arithmetic, you divide by 1e5
    uint32 public immutable yieldPercentage;

    uint32 public immutable yieldDuration; // in seconds

    uint32 public constant scalingFactor = 1e5;

    // ======Events======
    event Deposited(address indexed user, uint256 depositAmount, uint256 shareAmount);
    event Redeemed(address indexed user, uint256 shareAmount, uint256 redeemableAmount);

    // ======Errors======
    error ZeroAddress();
    error ZeroAmount();
    error ZeroYieldPercentage();
    error ZeroYieldDuration();
    error InvalidToken();
    error InsufficientDepositAllowance();
    error InsufficientDepositBalance();
    error InsufficientShareBalance();
    error ZeroPPFS();
    error ZeroRedeemableAmount();
    // error InsufficientTotVaultBalance();
    error RedeemAmtExceedDepositedAmt();
    error ImpossibleTotDepExceedUserDep();

    constructor(address _token, uint32 _yieldPercentage, uint32 _yieldDuration) ERC20("Share Token", "SCRVstETH") {
        if (_token == address(0)) {
            revert ZeroAddress();
        }

        if (_yieldPercentage == 0) {
            revert ZeroYieldPercentage();
        }

        if (_yieldDuration == 0) {
            revert ZeroYieldDuration();
        }

        yieldPercentage = _yieldPercentage;
        yieldDuration = _yieldDuration;

        depositToken = IERC20(_token);
    }

    // ======Getters======

    /// @dev Returns the amount of deposit token for a given user address
    function depositOf(address _account) public view returns (uint256) {
        return vaults[_account];
    }

    /// @dev Returns the total amount of shares for all users
    function totalShares() public view returns (uint256) {
        return this.totalSupply();
    }

    /// @dev Returns the amount of shares for a given user address
    function sharesOf(address _account) public view returns (uint256) {
        return this.balanceOf(_account);
    }

    /// @dev get the PPFS (price per full share) i.e.
    // (total_deposited_amount with accrued interest over time) is divided by (total_shares)
    // Get the PPFS in wei so as to avoid precision loss
    function getPPFS() public view returns (uint256) {
        uint256 ppfs = 1e18; // initially (1 * 1e18) (scaled for precision. ideally 1 as ratio) when totalDepositBalance == 0

        uint256 _lastTotalDepositBalance = totalDepositBalance;

        if (_lastTotalDepositBalance != 0) {
            // 1. current accrued interest percentage
            // in decimal
            uint256 currentAccruedInterestPercentage =
                (block.timestamp - lastDepositTimestamp) * yieldPercentage / yieldDuration;
            // console.log("getPPFS::currentAccruedInterestPercentage: ", currentAccruedInterestPercentage);

            // 2. total deposited amount with interest
            // NOTE: divide by 1e18 is done in step-2 here as because in the previous step, it was becoming
            // (2.1) prefer this as it gives more precision. E.g. 1060000000000000000
            uint256 totalDepositedWithInterest =
                _lastTotalDepositBalance + (_lastTotalDepositBalance * currentAccruedInterestPercentage / scalingFactor);
            // (2.2) prefer this as it gives more precision. E.g. 1000000000000000000
            // uint256 totalDepositedWithInterest = _lastTotalDepositBalance * (1 + currentAccruedInterestPercentage / scalingFactor);
            // console.log("getPPFS::totalDepositedWithInterest: ", totalDepositedWithInterest);
            // console.log("getPPFS::totalShares: ", totalShares());

            // 3. price per full share
            // NOTE: 1e18 is multiplied to get the precision
            // Actual value can be computed offchain by dividing by 1e18 as float type.
            ppfs = (totalDepositedWithInterest * 1e18) / totalShares();
            console.log("getPPFS::ppfs: ", ppfs);
        }

        return ppfs;
    }

    // TODO: add this function
    /// @dev Get redeemable amount for a given user address for a given share amount
    function getRedeemableAmount() public view returns (uint256) {}

    // ======private======
    function _updateVaultIndivAndTotOnDeposit(
        uint256 _amount,
        uint256 _lastTotalDepositBalance,
        uint256 _lastDepositBalanceOf,
        uint32 _lastDepositTimestamp
    ) private {
        // if total deposited is zero, then mint share token = deposit token as PPFS = 1, else calculated based on PPFS
        if (_lastTotalDepositBalance == 0) {
            // update the caller's & total vault i.e. deposited amount
            vaults[msg.sender] = _amount;
            totalDepositBalance = _amount;
        } else {
            // update the caller's vault i.e. deposited amount with accrued interest
            uint256 accruedInterestOfprevDepositedAmt =
                _lastDepositBalanceOf * (block.timestamp - _lastDepositTimestamp) * yieldPercentage / yieldDuration;
            console.log("accruedInterestOfprevDepositedAmt: ", accruedInterestOfprevDepositedAmt);

            vaults[msg.sender] = _lastDepositBalanceOf + (accruedInterestOfprevDepositedAmt / scalingFactor) + _amount;

            // update the total deposited amount with accrued interest on last total deposited amount
            uint256 accruedInterestOfTotDepositedAmt =
                _lastTotalDepositBalance * (block.timestamp - _lastDepositTimestamp) * yieldPercentage / yieldDuration;

            totalDepositBalance =
                _lastTotalDepositBalance + (accruedInterestOfTotDepositedAmt / scalingFactor) + _amount;
        }
    }

    function _updateVaultIndivAndTotOnRedeem(
        uint256 _redeemableAmount,
        uint256 _lastTotalDepositBalance,
        uint256 _lastDepositBalanceOf,
        uint32 _lastDepositTimestamp
    ) private {
        // update the caller's vault i.e. deposited amount with accrued interest
        uint256 accruedInterestOfprevDepositedAmt =
            _lastDepositBalanceOf * (block.timestamp - _lastDepositTimestamp) * yieldPercentage / yieldDuration;
        console.log("accruedInterestOfprevDepositedAmt: ", accruedInterestOfprevDepositedAmt);

        // bracketing `accruedInterestOfprevDepositedAmt / scalingFactor` is optional
        vaults[msg.sender] =
            _lastDepositBalanceOf + (accruedInterestOfprevDepositedAmt / scalingFactor) - _redeemableAmount;

        // update the total deposited amount with accrued interest on last total deposited amount
        uint256 accruedInterestOfTotDepositedAmt =
            _lastTotalDepositBalance * (block.timestamp - _lastDepositTimestamp) * yieldPercentage / yieldDuration;

        totalDepositBalance =
            _lastTotalDepositBalance + (accruedInterestOfTotDepositedAmt / scalingFactor) - _redeemableAmount;
    }

    // ======Setters======

    /// @dev Deposit tokens to the vault
    function deposit(IERC20 _depositToken, uint256 _amount) external nonReentrant whenNotPaused {
        if (_depositToken != depositToken) {
            revert InvalidToken();
        }

        if (_amount == 0) {
            revert ZeroAmount();
        }

        // check the allowance, whether approved or not
        if (_amount > _depositToken.allowance(msg.sender, address(this))) {
            revert InsufficientDepositAllowance();
        }

        uint256 _lastDepositBalanceOf = depositOf(msg.sender);
        uint256 _lastTotalDepositBalance = totalDepositBalance;
        uint32 _lastDepositTimestamp = lastDepositTimestamp;

        if (_lastTotalDepositBalance < _lastDepositBalanceOf) {
            revert ImpossibleTotDepExceedUserDep();
        }

        // calculate share token amount
        // NOTE: PPFS (calculated) need to be divided by 1e18 i.e. multiplied in numerator.
        // PPFS = 1e18, if totalDepositBalance == 0, else PPFS > 1e18
        uint256 shareAmount = _amount * 1e18 / getPPFS(); // more precision
        // uint256 shareAmount = _amount / (ppfs / 1e18); // less precision

        _updateVaultIndivAndTotOnDeposit(
            _amount, _lastTotalDepositBalance, _lastDepositBalanceOf, _lastDepositTimestamp
        );

        // update the last_deposit_timestamp
        lastDepositTimestamp = uint32(block.timestamp);

        // mint share token to msg.sender
        _mint(msg.sender, shareAmount);

        // transferFrom deposit token to vault
        _depositToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposited(msg.sender, _amount, shareAmount);
    }

    /// @dev Redeem tokens (including autocompound) from the vault
    /// NOTE: Here, the deposited amount can't be withdrawn unlike
    /// in a simple vault (without auto-compounding yield).
    /// Here, the deposited amount can only be redeemed by giving back the share tokens.
    function redeem(uint256 _shareAmount) external nonReentrant whenNotPaused {
        if (_shareAmount == 0) {
            revert ZeroAmount();
        }

        // check for available balance
        if (_shareAmount > this.balanceOf(msg.sender)) {
            revert InsufficientShareBalance();
        }

        uint256 _lastDepositBalanceOf = depositOf(msg.sender);
        uint256 _lastTotalDepositBalance = totalDepositBalance;

        if (_lastDepositBalanceOf == 0) {
            revert InsufficientDepositBalance();
        }

        if (_lastTotalDepositBalance < _lastDepositBalanceOf) {
            revert ImpossibleTotDepExceedUserDep();
        }

        // calculate redeemable amount i.e. CRVstETH tokens
        // NOTE: PPFS (calculated) based on totalDepositBalance value (== 0 or != 0)
        uint256 _redeemableAmount = _shareAmount * getPPFS() / 1e18;

        // Output sanitization | check if redeemable amount is greater than user's deposited balance in vault
        if (_redeemableAmount > _lastDepositBalanceOf) {
            revert RedeemAmtExceedDepositedAmt();
        }

        _updateVaultIndivAndTotOnRedeem(
            _redeemableAmount, _lastTotalDepositBalance, _lastDepositBalanceOf, lastDepositTimestamp
        );

        // burn share token from msg.sender
        _burn(msg.sender, _shareAmount);

        // transferFrom deposit token to vault
        depositToken.safeTransfer(msg.sender, _redeemableAmount);

        emit Redeemed(msg.sender, _shareAmount, _redeemableAmount);
    }

    // ------------------------------------------------------------------------------------------
    /// @notice Pause contract
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
