// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AutoCompVault is Ownable, Pausable, ReentrancyGuard, ERC20 {
    using SafeERC20 for IERC20;

    // CRVstETH token (deposit/invest token)
    // IDepositToken vs IERC20: mint, burn functions (external)
    IERC20 public immutable depositToken;

    // receipt token - RCRVstETH (shares)
    // receipt (pool) token is ERC20 inherited here.

    // struct Vault {
    //     uint256 depositedAmt;
    // }

    mapping(address => uint256) public vaults;

    // total amount of deposit token deposited in the vault
    uint256 public totalDeposited;

    uint256 public lastDepositedTimestamp;

    uint256 public immutable yieldPercentage; // in percentage i.e. 0.5% = 0.005 => represented as 1e18

    uint256 public immutable yieldDuration; // in seconds

    bool public isFirstDepositDone;

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

    constructor(address _token, uint256 _yieldPercentage, uint32 _yieldDuration) ERC20("Receipt Token", "RCRVstETH") {
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

    /// @dev get the PPFS (price per full share)
    function getPPFS() private view returns (uint256) {
        // current accrued interest percentage
        uint256 currentAccruedInterestPercentage =
            ((block.timestamp - lastDepositedTimestamp) * yieldPercentage) / yieldDuration;

        // total deposited amount with interest
        uint256 totalDepositedWithInterest = totalDeposited + (totalDeposited * currentAccruedInterestPercentage) / 1e18;

        // price per full share
        uint256 ppfs = totalDepositedWithInterest / totalShares();

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

        // update the caller's vault i.e. deposited amount
        vaults[msg.sender] += _amount;

        // calculate receipt token amount
        uint256 receiptAmt = 0;

        // if first deposit, then mint receipt token = deposit token as PPFS = 1, else calculated based on PPFS
        if (isFirstDepositDone) {
            receiptAmt = _amount;
        } else {
            receiptAmt = _amount / getPPFS();
        }

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

        // update the caller's vault  i.e. deposited amount
        vaults[msg.sender] -= redeemableAmount;

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
