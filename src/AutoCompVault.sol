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

    // receipt token - RCRVstETH (shares)
    // receipt (pool) token is ERC20 inherited here.

    // mapping of user address to deposit token amount
    mapping(address => uint256) public vaults;

    // total amount of deposit token deposited in the vault
    uint256 public totalDeposited;

    uint256 public lastDepositedTimestamp;

    // in percentage i.e. 0.5% = 0.005 => represented as 1e5 (scaling_factor) => 500
    // NOTE: We can put this scaling factor as high as possible i.e. 1e18,
    // but then during division it would lose the precision. Hence, choose as small as possible.
    // Hence, keep the scaling_factor as low as possible.
    // make sure during arithmetic, you divide by 1e5
    uint32 public immutable yieldPercentage;

    uint32 public immutable yieldDuration; // in seconds

    uint32 public constant scalingFactor = 1e5;

    // bool public isFirstDepositDone; // FIXME: instead checked with `totalDeposited`

    // ======Events======
    event Deposited(address indexed user, uint256 depositAmount, uint256 receiptAmount);
    event Withdrawn(address indexed user, uint256 receiptAmount, uint256 redeemableAmount);

    // ======Errors======
    error ZeroAddress();
    error ZeroAmount();
    error ZeroYieldPercentage();
    error ZeroYieldDuration();
    error InvalidToken();
    error InsufficientDepositAllowance();
    error InsufficientReceiptBalance();
    error ZeroPPFS();

    constructor(address _token, uint32 _yieldPercentage, uint32 _yieldDuration) ERC20("Receipt Token", "RCRVstETH") {
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
    function depositedOf(address _account) public view returns (uint256) {
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

    // ======private======

    /// @dev get the PPFS (price per full share) i.e.
    // (total_deposited_amount with accrued interest over time) is divided by (total_shares)
    // Get the PPFS in wei so as to avoid precision loss
    function getPPFS() public view returns (uint256) {
        uint256 ppfs = 1e18; // initially 1e18 (scaled for precision. ideally 1 as ratio) when totalDeposited == 0

        uint256 _totalDeposited = totalDeposited;

        if (_totalDeposited != 0) {
            // 1. current accrued interest percentage
            // in decimal
            uint256 currentAccruedInterestPercentage =
                (block.timestamp - lastDepositedTimestamp) * yieldPercentage / yieldDuration;
            // console.log("getPPFS::currentAccruedInterestPercentage: ", currentAccruedInterestPercentage);

            // 2. total deposited amount with interest
            // NOTE: divide by 1e18 is done in step-2 here as because in the previous step, it was becoming
            // (2.1) prefer this as it gives more precision. E.g. 1060000000000000000
            uint256 totalDepositedWithInterest =
                _totalDeposited + (_totalDeposited * currentAccruedInterestPercentage / scalingFactor);
            // (2.2) prefer this as it gives more precision. E.g. 1000000000000000000
            // uint256 totalDepositedWithInterest = _totalDeposited * (1 + currentAccruedInterestPercentage / scalingFactor);
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

        uint256 _totalDeposited = totalDeposited;
        uint256 _lastDepositedTimestamp = lastDepositedTimestamp;

        // update the caller's vault i.e. deposited amount with accrued interest
        uint256 previousDepositedAmt = depositedOf(msg.sender);

        // calculate receipt token amount
        // NOTE: Need to divide by 1e18
        uint256 receiptAmt = _amount * 1e18 / getPPFS(); // more precision
        // uint256 receiptAmt = _amount / (ppfs / 1e18); // less precision

        // if total deposited is zero, then mint receipt token = deposit token as PPFS = 1, else calculated based on PPFS
        if (_totalDeposited == 0) {
            // update the caller's & total vault i.e. deposited amount
            vaults[msg.sender] = _amount;
            totalDeposited = _amount;
        } else {
            // update the caller's vault i.e. deposited amount with accrued interest
            uint256 accruedInterestOfprevDepositedAmt =
                previousDepositedAmt * (block.timestamp - _lastDepositedTimestamp) * yieldPercentage / yieldDuration;
            console.log("accruedInterestOfprevDepositedAmt: ", accruedInterestOfprevDepositedAmt);

            vaults[msg.sender] = previousDepositedAmt + _amount + accruedInterestOfprevDepositedAmt / scalingFactor;

            // update the total deposited amount with accrued interest on last total deposited amount
            uint256 accruedInterestOfTotDepositedAmt =
                _totalDeposited * (block.timestamp - _lastDepositedTimestamp) * yieldPercentage / yieldDuration;

            totalDeposited = _totalDeposited + _amount + accruedInterestOfTotDepositedAmt / scalingFactor;
        }

        // update the last_deposit_timestamp
        lastDepositedTimestamp = block.timestamp;

        // mint receipt token to msg.sender
        _mint(msg.sender, receiptAmt);

        // transferFrom deposit token to vault
        _depositToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposited(msg.sender, _amount, receiptAmt);
    }

    /// @dev Redeem deposited tokens from the vault
    function withdraw(uint256 _receiptAmount) external nonReentrant whenNotPaused {
        // check for available balance
        if (_receiptAmount > this.balanceOf(msg.sender)) {
            revert InsufficientReceiptBalance();
        }

        // calculate redeemable amount
        uint256 redeemableAmount = _receiptAmount * getPPFS();

        // update the caller's & Total vault  i.e. deposited amount
        vaults[msg.sender] -= redeemableAmount; // TODO: add accrued interest
        totalDeposited -= redeemableAmount; // TODO: add accrued interest

        // if (totalDeposited == 0) {
        //     isFirstDepositDone = false;
        // }

        // burn receipt token from msg.sender
        _burn(msg.sender, _receiptAmount);

        // transferFrom deposit token to vault
        depositToken.safeTransfer(msg.sender, redeemableAmount);

        emit Withdrawn(msg.sender, _receiptAmount, redeemableAmount);
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
